//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./BaseMilestone.sol";

contract VestingMilestone is BaseMilestone, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public period;
    uint256 public releaseIntervalSecs;

    /**
    @notice Emitted when someone withdraws a vested amount
    */
    event Claimed(address indexed _recipient, uint256 _withdrawalAmount);

    //
    /**
    @notice Construct the contract, taking the ERC20 token to be vested as the parameter.
    @dev The owner can set the contract in question when creating the contract.
     */
    constructor(
        IERC20 _tokenAddress,
        uint256 _totalAllocation,
        uint256[] memory _allocationPercents,
        address _recipient,
        uint256 _intervalSecs,
        uint256 _period,
        address _owner
    ) {
        require(address(_tokenAddress) != address(0), "INVALID_ADDRESS");
        tokenAddress = _tokenAddress;
        _transferOwnership(_owner);
        period = _period;
        releaseIntervalSecs = _intervalSecs;
        recipient = _recipient;
        totalAllocation = _totalAllocation;

        super.initializeMilestones(_allocationPercents);
    }

    /**
    @notice Calculate the amount vested for a given _recipient at a reference timestamp.
    @param _milestoneIndex - The index of Milestone
    @param _referenceTs - The timestamp at which we want to calculate the vested amount.
    @dev Simply call the _baseVestedAmount for the claim in question
    */
    function vestedAmount(
        uint256 _milestoneIndex,
        uint256 _referenceTs
    ) public view returns (uint256) {
        Milestone memory milestone = milestones[_milestoneIndex];
        if (milestone.startTime == 0) {
            return 0;
        }

        // Check if this time is over vesting end time
        if (_referenceTs > milestone.startTime + period) {
            _referenceTs = milestone.startTime + period;
        }

        if (_referenceTs > milestone.startTime) {
            uint256 currentVestingDurationSecs = _referenceTs -
                milestone.startTime; // How long since the start

            uint256 intervals = currentVestingDurationSecs /
                releaseIntervalSecs;
            uint256 amountPerInterval = (releaseIntervalSecs *
                milestone.allocation) / period;

            return amountPerInterval * intervals;
        }

        return 0;
    }

    /**
    @notice Calculate the total vested at the end of the schedule, by simply feeding in the end timestamp to the function above.
    @dev This fn is somewhat superfluous, should probably be removed.
     */
    function finalVestedAmount(
        uint256 _milestoneIndex
    ) public view returns (uint256) {
        return milestones[_milestoneIndex].allocation;
    }

    /**
    @notice Calculates how much can we claim, by subtracting the already withdrawn amount from the vestedAmount at this moment.
    @param _milestoneIndex the index of milestones.
    */
    function claimableAmount(
        uint256 _milestoneIndex
    ) public view returns (uint256) {
        return
            vestedAmount(_milestoneIndex, block.timestamp) -
            milestones[_milestoneIndex].withdrawnAmount;
    }

    /**
    @notice Withdraw the full claimable balance.
    @param _milestoneIndex the index of milestones.
    @dev hasActiveClaim throws off anyone without a claim.
     */
    function withdraw(uint256 _milestoneIndex) external onlyRecipient {
        Milestone storage milestone = milestones[_milestoneIndex];
        // we can use block.timestamp directly here as reference TS, as the function itself will make sure to cap it to endTimestamp
        // Conversion of timestamp to uint40 should be safe since 48 bit allows for a lot of years.
        uint256 allowance = vestedAmount(_milestoneIndex, block.timestamp);

        // Make sure we didn't already withdraw more that we're allowed.
        require(allowance > milestone.withdrawnAmount, "NOTHING_TO_WITHDRAW");

        // Calculate how much can we withdraw (equivalent to the above inequality)
        uint256 amountRemaining = allowance - milestone.withdrawnAmount;

        milestone.withdrawnAmount = allowance;

        tokenAddress.safeTransfer(_msgSender(), amountRemaining);

        // Let withdrawal known to everyone.
        emit Claimed(_msgSender(), amountRemaining);
    }
}
