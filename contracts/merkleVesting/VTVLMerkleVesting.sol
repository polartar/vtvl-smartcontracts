//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../IVestingFee.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

struct ClaimInput {
    uint40 startTimestamp; // When does the vesting start (40 bits is enough for TS)
    uint40 endTimestamp; // When does the vesting end - the vesting goes linearly between the start and end timestamps
    uint40 cliffReleaseTimestamp; // At which timestamp is the cliffAmount released. This must be <= startTimestamp
    uint40 releaseIntervalSecs; // Every how many seconds does the vested amount increase.
    uint40 scheduleIndex;
    // uint112 range: range 0 –     5,192,296,858,534,827,628,530,496,329,220,095.
    // uint112 range: range 0 –                             5,192,296,858,534,827.
    uint256 linearVestAmount; // total entitlement
    uint256 cliffAmount; // how much is released at the cliff
    address recipient; // the recipient address
}

contract VTVLMerkleVesting is Ownable, ReentrancyGuard, IVestingFee {
    using SafeERC20 for IERC20;

    IERC20 public immutable tokenAddress;

    /**
    @notice A structure representing a single claim - supporting linear and cliff vesting.
     */
    struct Claim {
        uint256 amountWithdrawn;
        uint256 deactivationTimestamp;
    }

    mapping(address => mapping(uint256 => Claim)) internal claims;

    address private immutable factoryAddress;
    uint256 public feePercent; // Fee percent.  500 means 5%, 1 means 0.01 %
    address public feeReceiver; // The receier address that will get the fee.

    uint256 public totalWithdrawnAmount;
    bytes32 private root;

    /**
    @notice Emitted when someone withdraws a vested amount
    */
    event Claimed(
        address indexed _recipient,
        uint256 _withdrawalAmount,
        uint256 _scheduleIndex
    );

    /**
    @notice Emitted when receiving the fee.
    @dev _tokenAddress may be vesting token address or USDC address depending on the token price.
    */
    event FeeReceived(
        address indexed _recipient,
        uint256 _feeAmount,
        uint256 _scheduleIndex,
        address _tokenAddress
    );

    /** 
    @notice Emitted when a claim is revoked
    */
    event ClaimRevoked(
        address indexed _recipient,
        uint256 _numTokensWithheld,
        uint256 revocationTimestamp,
        ClaimInput _claimInput,
        uint256 _scheduleIndex
    );

    /** 
    @notice Emitted when admin withdraws.
    */
    event AdminWithdrawn(address indexed _recipient, uint256 _amountRequested);

    //
    /**
    @notice Construct the contract, taking the ERC20 token to be vested as the parameter.
    @dev The owner can set the contract in question when creating the contract.
     */
    constructor(IERC20 _tokenAddress, uint256 _feePercent) {
        require(address(_tokenAddress) != address(0), "INVALID_ADDRESS");
        tokenAddress = _tokenAddress;
        _transferOwnership(tx.origin);
        factoryAddress = msg.sender;
        feeReceiver = msg.sender;
        feePercent = _feePercent;
    }

    function isRevoked(
        address _recipient,
        uint256 _scheduleIndex
    ) external view returns (bool) {
        return claims[_recipient][_scheduleIndex].deactivationTimestamp != 0;
    }

    /**
    @notice This modifier requires that owner or factory contract.
    */
    modifier onlyFactory() {
        require(msg.sender == factoryAddress, "Not Factory");
        _;
    }

    /**
    @notice Pure function to calculate the vested amount from a given _claim, at a reference timestamp
    @param _claimInput The claim in question
    @param _referenceTs Timestamp for which we're calculating
     */
    function _baseVestedAmount(
        ClaimInput memory _claimInput,
        uint40 _referenceTs
    ) internal pure returns (uint256) {
        uint256 vestAmt = 0;

        // Check if this time is over vesting end time
        if (_referenceTs > _claimInput.endTimestamp) {
            return _claimInput.cliffAmount + _claimInput.linearVestAmount;
        }

        // If we're past the cliffReleaseTimestamp, we release the cliffAmount
        // We don't check here that cliffReleaseTimestamp is after the startTimestamp
        if (_referenceTs >= _claimInput.cliffReleaseTimestamp) {
            vestAmt += _claimInput.cliffAmount;
        }

        // Calculate the linearly vested amount - this is relevant only if we're past the schedule start
        // at _referenceTs == _claimInput.startTimestamp, the period proportion will be 0 so we don't need to start the calc
        if (_referenceTs > _claimInput.startTimestamp) {
            uint40 currentVestingDurationSecs = _referenceTs -
                _claimInput.startTimestamp; // How long since the start

            // Next, we need to calculated the duration truncated to nearest releaseIntervalSecs
            uint40 truncatedCurrentVestingDurationSecs = (currentVestingDurationSecs /
                    _claimInput.releaseIntervalSecs) *
                    _claimInput.releaseIntervalSecs;

            uint40 finalVestingDurationSecs = _claimInput.endTimestamp -
                _claimInput.startTimestamp; // length of the interval

            // Calculate the linear vested amount - fraction_of_interval_completed * linearVestedAmount
            // Since fraction_of_interval_completed is truncatedCurrentVestingDurationSecs / finalVestingDurationSecs, the formula becomes
            // truncatedCurrentVestingDurationSecs / finalVestingDurationSecs * linearVestAmount, so we can rewrite as below to avoid
            // rounding errors
            uint256 linearVestAmount = (_claimInput.linearVestAmount *
                truncatedCurrentVestingDurationSecs) / finalVestingDurationSecs;

            // Having calculated the linearVestAmount, simply add it to the vested amount
            vestAmt += linearVestAmount;
        }

        return vestAmt;
    }

    /**
    @notice Calculate the amount vested for a given _recipient at a reference timestamp.
    @param _claimInput - The claim information
    @param _referenceTs - The timestamp at which we want to calculate the vested amount.
    @dev Simply call the _baseVestedAmount for the claim in question
    */
    function vestedAmount(
        ClaimInput memory _claimInput,
        uint40 _referenceTs
    ) public view returns (uint256) {
        Claim memory claim = getClaim(
            _claimInput.recipient,
            _claimInput.scheduleIndex
        );
        uint256 deactivationTimestamp = claim.deactivationTimestamp;
        uint40 vestEndTimestamp = deactivationTimestamp != 0
            ? uint40(deactivationTimestamp)
            : _referenceTs;

        return _baseVestedAmount(_claimInput, vestEndTimestamp);
    }

    /**
    @notice Basic getter for a claim. 
    @dev Could be using public claims var, but this is cleaner in terms of naming. (getClaim(address) as opposed to claims(address)). 
    @param _recipient - the address for which we fetch the claim.
    @param _scheduleIndex - the index of the schedules.
     */
    function getClaim(
        address _recipient,
        uint256 _scheduleIndex
    ) public view returns (Claim memory) {
        return claims[_recipient][_scheduleIndex];
    }

    /**
    @notice Calculate the total vested at the end of the schedule, by simply feeding in the end timestamp to the function above.
    @dev This fn is somewhat superfluous, should probably be removed.
    @param _claimInput - The claim information
     */
    function finalVestedAmount(
        ClaimInput memory _claimInput
    ) public pure returns (uint256) {
        return _baseVestedAmount(_claimInput, _claimInput.endTimestamp);
    }

    /**
    @notice Calculates how much can we claim, by subtracting the already withdrawn amount from the vestedAmount at this moment.
    @param _claimInput - The claim information
    */
    function claimableAmount(
        ClaimInput memory _claimInput
    ) public view returns (uint256) {
        Claim memory claim = getClaim(
            _claimInput.recipient,
            _claimInput.scheduleIndex
        );

        return
            vestedAmount(_claimInput, uint40(block.timestamp)) -
            claim.amountWithdrawn;
    }

    /**
    @notice Calculates how much wil be possible to claim at the end of vesting date, by subtracting the already withdrawn
            amount from the vestedAmount at this moment. Vesting date is either the end timestamp or the deactivation timestamp.
    @param _claimInput - The claim information

    */
    function finalClaimableAmount(
        ClaimInput memory _claimInput
    ) external view returns (uint256) {
        Claim memory claim = getClaim(
            _claimInput.recipient,
            _claimInput.scheduleIndex
        );

        uint40 vestEndTimestamp = claim.deactivationTimestamp != 0
            ? uint40(claim.deactivationTimestamp)
            : _claimInput.endTimestamp;
        return
            _baseVestedAmount(_claimInput, vestEndTimestamp) -
            claim.amountWithdrawn;
    }

    function getLeaf(
        ClaimInput memory _claimInput
    ) public pure returns (bytes32) {
        return
            keccak256(
                bytes.concat(
                    keccak256(
                        abi.encode(
                            _claimInput.startTimestamp,
                            _claimInput.endTimestamp,
                            _claimInput.cliffReleaseTimestamp,
                            _claimInput.releaseIntervalSecs,
                            _claimInput.scheduleIndex,
                            _claimInput.linearVestAmount,
                            _claimInput.cliffAmount,
                            _claimInput.recipient
                        )
                    )
                )
            );
    }

    /**
    @notice Withdraw the full claimable balance.
    @dev _claimInput The claim information
     */
    function withdraw(
        ClaimInput memory _claimInput,
        bytes32[] memory proof
    ) external nonReentrant {
        bytes32 leaf = getLeaf(_claimInput);
        verify(proof, leaf);
        // Get the message sender claim - if any
        uint40 _scheduleIndex = _claimInput.scheduleIndex;

        Claim storage usrClaim = claims[_claimInput.recipient][_scheduleIndex];

        // we can use block.timestamp directly here as reference TS, as the function itself will make sure to cap it to endTimestamp
        // Conversion of timestamp to uint40 should be safe since 48 bit allows for a lot of years.
        uint256 allowance = vestedAmount(_claimInput, uint40(block.timestamp));

        // Make sure we didn't already withdraw more that we're allowed.
        require(
            allowance > usrClaim.amountWithdrawn && allowance > 0,
            "NOTHING_TO_WITHDRAW"
        );

        // Calculate how much can we withdraw (equivalent to the above inequality)
        uint256 amountRemaining = allowance - usrClaim.amountWithdrawn;
        require(amountRemaining > 0, "NOTHING_TO_WITHDRAW");

        // "Double-entry bookkeeping"
        // Carry out the withdrawal by noting the withdrawn amount, and by transferring the tokens.
        usrClaim.amountWithdrawn = allowance;
        // Reduce the allocated amount since the following transaction pays out so the "debt" gets reduced
        // numTokensReservedForVesting -= amountRemaining;

        _transferToken(_claimInput.recipient, amountRemaining, _scheduleIndex);

        totalWithdrawnAmount += amountRemaining;
        // After the "books" are set, transfer the tokens
        // Reentrancy note - internal vars have been changed by now
        // Also following Checks-effects-interactions pattern

        // Let withdrawal known to everyone.
        emit Claimed(_claimInput.recipient, amountRemaining, _scheduleIndex);
    }

    /**
     * @notice transfer the token to the user and fee receiver.
     * // if the token price is samller than the conversionThreshold, then it will transfer USDC to the recipient.
     * @param _amount The total amount that will be transfered.
     * @param _scheduleIndex The index of the schedule.
     */
    function _transferToken(
        address _to,
        uint256 _amount,
        uint256 _scheduleIndex
    ) private {
        uint256 _feeAmount = calculateFee(_amount);

        tokenAddress.safeTransfer(_to, _amount - _feeAmount);
        tokenAddress.safeTransfer(feeReceiver, _feeAmount);
        emit FeeReceived(
            feeReceiver,
            _feeAmount,
            _scheduleIndex,
            address(tokenAddress)
        );
    }

    function calculateFee(uint256 _amount) private view returns (uint256) {
        return (_amount * feePercent + 9999) / 10000;
    }

    /**
    @notice Admin withdrawal of the unallocated tokens.
    @param _amountRequested - the amount that we want to withdraw
     */
    function withdrawAdmin(
        uint256 _amountRequested
    ) public onlyOwner nonReentrant {
        // Allow the owner to withdraw any balance not currently tied up in contracts.
        uint256 amountRemaining = amountAvailableToWithdrawByAdmin();

        require(amountRemaining >= _amountRequested, "INSUFFICIENT_BALANCE");

        // Actually withdraw the tokens
        // Reentrancy note - this operation doesn't touch any of the internal vars, simply transfers
        // Also following Checks-effects-interactions pattern
        tokenAddress.safeTransfer(_msgSender(), _amountRequested);

        // Let the withdrawal known to everyone
        emit AdminWithdrawn(_msgSender(), _amountRequested);
    }

    /** 
    @notice Allow an Owner to revoke a claim that is already active.
    @dev The requirement is that a claim exists and that it's active.
    @param _claimInput - The claim information
    */
    function revokeClaim(
        ClaimInput memory _claimInput,
        bytes32[] memory proof
    ) external onlyOwner {
        // Fetch the claim
        address _recipient = _claimInput.recipient;
        uint40 _scheduleIndex = _claimInput.scheduleIndex;
        bytes32 leaf = getLeaf(_claimInput);
        verify(proof, leaf);

        Claim storage _claim = claims[_claimInput.recipient][_scheduleIndex];
        // if (claims[_claimInput.recipient][_scheduleIndex])
        // if (claims[_claimInput.recipient].length != 0) {
        _claim = claims[_claimInput.recipient][_scheduleIndex];
        _claim.deactivationTimestamp = uint40(block.timestamp);
        // } else {
        //     Claim memory claim = Claim(0, block.timestamp);
        //     claims[_claimInput.recipient].push(claim);
        //     _claim = claims[_claimInput.recipient][0];
        // }

        // // Calculate what the claim should finally vest to
        uint256 finalVestAmt = finalVestedAmount(_claimInput);

        // // No point in revoking something that has been fully consumed
        // // so require that there be unconsumed amount
        require(_claim.amountWithdrawn < finalVestAmt, "NO_UNVESTED_AMOUNT");

        // // Deactivate the claim, and release the appropriate amount of tokens

        // // The amount that is "reclaimed" is equal to the total allocation less what was already withdrawn
        uint256 vestedSoFarAmt = vestedAmount(
            _claimInput,
            uint40(block.timestamp)
        );
        uint256 amountRemaining = finalVestAmt - vestedSoFarAmt;
        // numTokensReservedForVesting -= amountRemaining; // Reduces the allocation

        // Tell everyone a claim has been revoked.
        emit ClaimRevoked(
            _recipient,
            amountRemaining,
            uint40(block.timestamp),
            _claimInput,
            _scheduleIndex
        );
    }

    /**
    @notice Withdraw a token which isn't controlled by the vesting contract.
    @dev This contract controls/vests token at "tokenAddress". However, someone might send a different token. 
    To make sure these don't get accidentally trapped, give admin the ability to withdraw them (to their own address).
    Note that the token to be withdrawn can't be the one at "tokenAddress".
    @param _otherTokenAddress - the token which we want to withdraw
     */
    function withdrawOtherToken(
        IERC20 _otherTokenAddress
    ) external onlyOwner nonReentrant {
        require(_otherTokenAddress != tokenAddress, "INVALID_TOKEN"); // tokenAddress address is already sure to be nonzero due to constructor
        uint256 bal = _otherTokenAddress.balanceOf(address(this));
        require(bal > 0, "INSUFFICIENT_BALANCE");
        _otherTokenAddress.transfer(_msgSender(), bal);
    }

    /**
     * @notice Get amount that is not vested in contract
     * @dev Whenever vesting is revoked, this amount will be increased.
     */
    function amountAvailableToWithdrawByAdmin() public view returns (uint256) {
        return tokenAddress.balanceOf(address(this));
    }

    // function getNumberOfVestings(
    //     address _recipient
    // ) public view returns (uint256) {
    //     return claims[_recipient].length;
    // }

    function setFee(uint256 _feePercent) external onlyFactory {
        feePercent = _feePercent;
    }

    function updateFeeReceiver(address _newReceiver) external onlyFactory {
        feeReceiver = _newReceiver;
    }

    function updateconversionThreshold(
        uint256 _threshold
    ) external onlyFactory {}

    function setMerkleRoot(bytes32 _root) public onlyFactory {
        root = _root;
    }

    function verify(bytes32[] memory proof, bytes32 leaf) public view {
        require(MerkleProof.verify(proof, root, leaf), "Invalid proof");
    }
}
