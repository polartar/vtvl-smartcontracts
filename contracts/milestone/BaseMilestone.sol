//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

struct Milestone {
    uint256 startTime;
    uint256 withdrawnAmount;
    uint128 period;
    uint120 releaseIntervalSecs;
    bool isWithdrawn;
    uint248 allocation;
    uint8 percent;
}

struct InputMilestone {
    uint8 percent;
    uint128 period;
    uint120 releaseIntervalSecs;
}

contract BaseMilestone is Ownable {
    using SafeERC20 for IERC20;

    address public recipient;
    IERC20 public tokenAddress;
    uint256 public totalAllocation;
    uint256 public numTokensReservedForVesting;

    mapping(uint256 => Milestone) milestones;

    /** 
    @notice Emitted when admin withdraws.
    */
    event AdminWithdrawn(address indexed _recipient, uint256 _amountRequested);

    function initializeMilestones(
        InputMilestone[] memory _milestones
    ) internal {
        uint256 length = _milestones.length;

        for (uint256 i = 0; i < length; ) {
            Milestone memory milestone;

            milestone.period = _milestones[i].period;
            milestone.releaseIntervalSecs = _milestones[i].releaseIntervalSecs;
            milestone.allocation = uint248(
                (_milestones[i].percent * totalAllocation) / 100
            );

            milestones[i] = milestone;
            unchecked {
                ++i;
            }
        }
    }

    function initializeAllocations(
        uint256[] memory _allocationPercents
    ) internal {
        uint256 length = _allocationPercents.length;
        for (uint256 i = 0; i < length; ) {
            milestones[i].allocation = uint248(
                (_allocationPercents[i] * totalAllocation) / 100
            );
            unchecked {
                ++i;
            }
        }
    }

    modifier onlyRecipient() {
        require(msg.sender == recipient, "NO_RECIPIENT");

        _;
    }

    modifier onlyCompleted(uint256 _milestoneIndex) {
        require(milestones[_milestoneIndex].startTime != 0, "NOT_COMPLETED");

        _;
    }

    modifier onlyDeposited() {
        uint256 balance = tokenAddress.balanceOf(address(this));
        require(balance >= totalAllocation, "NOT_DEPOSITED");

        _;
    }

    function isCompleted(uint256 _milestoneIndex) public view returns (bool) {
        return milestones[_milestoneIndex].startTime == 0 ? false : true;
    }

    /**
    @notice Only can mark as completed when it's deposited.
    @dev Only onwer can mark as completed.
     */
    function setComplete(
        uint256 _milestoneIndex
    ) public onlyOwner onlyDeposited {
        Milestone storage milestone = milestones[_milestoneIndex];

        require(milestone.startTime == 0, "ALREADY_COMPLETED");

        milestone.startTime = block.timestamp;
        numTokensReservedForVesting += milestone.allocation;
    }

    /**
    @notice Only admin can withdraw the amount before it's completed.
     */
    function withdrawAdmin() public onlyOwner {
        uint256 availableAmount = totalAllocation - numTokensReservedForVesting;

        tokenAddress.safeTransfer(msg.sender, availableAmount);

        emit AdminWithdrawn(_msgSender(), availableAmount);
    }

    function deposit(uint256 amount) public {
        tokenAddress.safeTransferFrom(msg.sender, address(this), amount);
    }
}
