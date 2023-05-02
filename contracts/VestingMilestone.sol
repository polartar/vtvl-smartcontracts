//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract VestingMilestone is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /**
    @notice Address of the token that we're vesting
     */
    IERC20 public immutable tokenAddress;

    uint256 public startTime;
    uint256 public period;
    uint256 public releaseIntervalSecs;
    bool public isDeposited;
    bool public isCompleted;
    address public recipient;
    uint256 public amountPerInterval;
    uint256 public allocation;
    uint256 public withdrawnAmount;

    /**
    @notice Emitted when someone withdraws a vested amount
    */
    event Claimed(address indexed _recipient, uint256 _withdrawalAmount);

    /** 
    @notice Emitted when admin withdraws.
    */
    event AdminWithdrawn(address indexed _recipient, uint256 _amountRequested);

    //
    /**
    @notice Construct the contract, taking the ERC20 token to be vested as the parameter.
    @dev The owner can set the contract in question when creating the contract.
     */
    constructor(
        IERC20 _tokenAddress,
        uint256 _allocation,
        address _recipient,
        address _owner,
        uint256 _intervalSecs,
        uint256 _period,
        bool _isDeposited
    ) {
        require(address(_tokenAddress) != address(0), "INVALID_ADDRESS");
        tokenAddress = _tokenAddress;
        _transferOwnership(_owner);
        isDeposited = _isDeposited;
        period = _period;
        releaseIntervalSecs = _intervalSecs;
        recipient = _recipient;
        allocation = _allocation;
        amountPerInterval = (_intervalSecs * allocation) / period;
    }

    modifier onlyRecipient() {
        require(msg.sender == recipient, "NO_RECIPIENT");

        _;
    }

    modifier onlyCompleted() {
        require(startTime != 0, "NOT_COMPLETED");

        _;
    }

    modifier onlyDeposited() {
        uint256 balance = tokenAddress.balanceOf(address(this));
        require(isDeposited || balance >= allocation, "NOT_DEPOSITED");

        _;
    }

    /**
    @notice Only recipient can withdraw when it's completed.
    @dev Only onwer can mark as completed.
     */
    function setComplete() public onlyOwner onlyDeposited {
        isCompleted = true;
        startTime = block.timestamp;
    }

    /**
    @notice Calculate the amount vested for a given _recipient at a reference timestamp.
    @param _referenceTs - The timestamp at which we want to calculate the vested amount.
    @dev Simply call the _baseVestedAmount for the claim in question
    */
    function vestedAmount(uint256 _referenceTs) public view returns (uint256) {
        if (startTime == 0) {
            return 0;
        }

        uint256 vestAmt = 0;

        // Check if this time is over vesting end time
        if (_referenceTs > startTime + period) {
            _referenceTs = startTime + period;
        }

        if (_referenceTs > startTime) {
            uint256 currentVestingDurationSecs = _referenceTs - startTime; // How long since the start

            uint256 intervals = currentVestingDurationSecs /
                releaseIntervalSecs;

            vestAmt += amountPerInterval * intervals;
        }

        return 0;
    }

    /**
    @notice Calculate the total vested at the end of the schedule, by simply feeding in the end timestamp to the function above.
    @dev This fn is somewhat superfluous, should probably be removed.
     */
    function finalVestedAmount() public view returns (uint256) {
        return allocation;
    }

    /**
    @notice Calculates how much can we claim, by subtracting the already withdrawn amount from the vestedAmount at this moment.
    */
    function claimableAmount() public view returns (uint256) {
        return vestedAmount(block.timestamp) - withdrawnAmount;
    }

    function deposit(uint256 amount) public {
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
    }

    function numTokensReservedForVesting() public view returns (uint256) {
        return allocation - withdrawnAmount;
    }

    /**
    @notice Withdraw the full claimable balance.
    @dev hasActiveClaim throws off anyone without a claim.
     */
    function withdraw() external onlyOwner {
        // we can use block.timestamp directly here as reference TS, as the function itself will make sure to cap it to endTimestamp
        // Conversion of timestamp to uint40 should be safe since 48 bit allows for a lot of years.
        uint256 allowance = vestedAmount(block.timestamp);

        // Make sure we didn't already withdraw more that we're allowed.
        require(allowance > withdrawnAmount, "NOTHING_TO_WITHDRAW");

        // Calculate how much can we withdraw (equivalent to the above inequality)
        uint256 amountRemaining = allowance - withdrawnAmount;

        // "Double-entry bookkeeping"
        // Carry out the withdrawal by noting the withdrawn amount, and by transferring the tokens.
        withdrawnAmount = allowance;

        tokenAddress.safeTransfer(_msgSender(), amountRemaining);

        // Let withdrawal known to everyone.
        emit Claimed(_msgSender(), amountRemaining);
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
     * @notice Get amount that is not vested in contract
     * @dev Whenever vesting is revoked, this amount will be increased.
     */
    function amountAvailableToWithdrawByAdmin() public view returns (uint256) {
        return tokenAddress.balanceOf(address(this)) - allocation;
    }
}
