// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./SimpleMilestone.sol";
import "./VestingMilestone.sol";

/// @title Vesting Factory contract
/// @notice Create Vesting contract

contract VTVLVestingFactory is Ownable {
    event CreateMilestoneContract(
        address indexed milestoneAddress,
        uint256 milestoneIndex,
        address creator
    );

    /**
    Check if sum of allocation percents is 100%
     */
    function allocationValidate(uint256[] _allocationPercents) private {
        uint256 sum;
        uint256 length = _allocationPercents.length;

        for (uint256 i = 0; i < length; ) {
            unchecked {
                sum += _allocationPercents[i];
                ++i;
            }
        }

        if (sum != 10000) {
            revert("INVALID_ALLOCATION_PERCENTS");
        }
    }

    /**
     * @notice Create milestone based Vesting contract
     * @param _tokenAddress Vesting Fund token address
     */
    function createVestingContract(
        IERC20 _tokenAddress,
        uint256 _totalAllocation,
        uint256 _allocationPercents,
        address _recipient,
        uint256 _intervalSecs,
        uint256 _period
    ) public {
        allocationValidate(_allocationPercents);

        uint256 _userBalance = _tokenAddress.balanceOf(msg.sender);
        bool isDeposited;
        if (_userBalance >= _tokenAddress) {
            isDeposited = true;
        }

        _createVestingMilestones(
            _tokenAddress,
            _totalAllocation,
            _allocationPercents,
            _recipient,
            _intervalSecs,
            _period,
            _isDeposited
        );
    }

    function _createVestingMilestones(
        IERC20 _tokenAddress,
        uint256 _totalAllocation,
        uint256[] _allocationPercents,
        address _recipient,
        uint256 _intervalSecs,
        uint256 _period,
        bool _isDeposited
    ) private {
        uint256 length = _allocationPercents.length;

        for (uint256 i = 0; i < length; ) {
            uint256 _allocation = (_totalAllocation * 10000) /
                _allocationPercents[i];

            VestingMilestone milestoneContract = new VestingMilestone(
                _tokenAddress,
                _allocation,
                _recipient,
                msg.sender,
                _intervalSecs,
                _period,
                _isDeposited
            );
            if (_isDeposited) {
                _tokenAddress.transferFrom(from, to, _allocation);
            }

            unchecked {
                ++i;
            }
            emit CreateMilestoneContract(
                address(milestoneContract),
                i,
                msg.sender
            );
        }
    }

    /**
     * @notice Create simple milestones
     * @param _tokenAddress Vesting Fund token address
     */
    function createSimpleMilestones(
        IERC20 _tokenAddress,
        uint256 _totalAllocation,
        uint256 _allocationPercents,
        address _recipient
    ) public {
        allocationValidate(_allocationPercents);

        uint256 _userBalance = _tokenAddress.balanceOf(msg.sender);
        bool isDeposited;
        if (_userBalance >= _tokenAddress) {
            isDeposited = true;
        }

        _createSimpleMilestones(
            _tokenAddress,
            _totalAllocation,
            _allocationPercents,
            _recipient,
            _isDeposited
        );
    }

    function _createSimpleMilestones(
        IERC20 _tokenAddress,
        uint256 _totalAllocation,
        uint256[] _allocationPercents,
        address _recipient,
        bool _isDeposited
    ) private {
        uint256 length = _allocationPercents.length;

        for (uint256 i = 0; i < length; ) {
            uint256 _allocation = (_totalAllocation * 10000) /
                _allocationPercents[i];

            SimpleMilestone milestoneContract = new SimpleMilestone(
                _tokenAddress,
                _allocation,
                _recipient,
                msg.sender,
                _isDeposited
            );
            if (_isDeposited) {
                _tokenAddress.transferFrom(from, to, _allocation);
            }

            unchecked {
                ++i;
            }
            emit CreateMilestoneContract(
                address(milestoneContract),
                i,
                msg.sender
            );
        }
    }
}
