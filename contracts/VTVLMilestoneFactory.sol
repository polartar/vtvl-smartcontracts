// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.14;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./milestone/SimpleMilestone.sol";
import "./milestone/VestingMilestone.sol";

/// @title Milestone Vesting Factory contract
/// @notice Create Milestone contracts

contract VTVLMilestoneFactory is Ownable {
    using SafeERC20 for IERC20;

    event CreateMilestoneContract(
        address indexed milestoneAddress,
        address creator
    );

    /**
    Check if sum of allocation percents is 100%
     */
    function milestoneValidate(
        InputMilestone[] calldata _milestones
    ) private pure {
        uint256 sum;
        uint256 length = _milestones.length;

        require(length > 0, "INVALID_MILESTONE_LENGTH");

        for (uint256 i = 0; i < length; ) {
            unchecked {
                sum += _milestones[i].percent;
                ++i;
            }
        }

        if (sum != 100) {
            revert("INVALID_ALLOCATION_PERCENTS");
        }
    }

    /**
    Check if sum of allocation percents is 100%
     */
    function allocationValidate(
        uint256[] calldata _allocationPercents
    ) private pure {
        uint256 sum;
        uint256 length = _allocationPercents.length;

        require(length > 0, "INVALID_MILESTONE_LENGTH");

        for (uint256 i = 0; i < length; ) {
            unchecked {
                sum += _allocationPercents[i];
                ++i;
            }
        }

        if (sum != 100) {
            revert("INVALID_ALLOCATION_PERCENTS");
        }
    }

    function _deposit(
        IERC20 _tokenAddress,
        uint256 _amount,
        address _contractAddress
    ) private {
        uint256 userBalance = _tokenAddress.balanceOf(msg.sender);

        if (userBalance >= _amount) {
            _tokenAddress.safeTransferFrom(
                msg.sender,
                address(_contractAddress),
                _amount
            );
        }
    }

    /**
     * @notice Create milestone based Vesting contract
     * @param _tokenAddress Vesting Fund token address
     */
    function createVestingMilestone(
        IERC20 _tokenAddress,
        uint256 _totalAllocation,
        InputMilestone[] calldata _milestones,
        address _recipient
    ) public {
        milestoneValidate(_milestones);

        VestingMilestone milestoneContract = new VestingMilestone(
            _tokenAddress,
            _totalAllocation,
            _milestones,
            _recipient,
            msg.sender
        );

        _deposit(_tokenAddress, _totalAllocation, address(milestoneContract));

        emit CreateMilestoneContract(address(milestoneContract), msg.sender);
    }

    /**
     * @notice Create simple milestones
     * @param _tokenAddress Vesting Fund token address
     */
    function createSimpleMilestones(
        IERC20 _tokenAddress,
        uint256 _totalAllocation,
        uint256[] calldata _allocationPercents,
        address _recipient
    ) public {
        allocationValidate(_allocationPercents);

        SimpleMilestone milestoneContract = new SimpleMilestone(
            _tokenAddress,
            _totalAllocation,
            _allocationPercents,
            _recipient,
            msg.sender
        );

        _deposit(_tokenAddress, _totalAllocation, address(milestoneContract));

        emit CreateMilestoneContract(address(milestoneContract), msg.sender);
    }
}
