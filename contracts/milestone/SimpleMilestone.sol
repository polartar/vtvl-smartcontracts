//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./BaseMilestone.sol";

contract SimpleMilestone is BaseMilestone {
     using SafeERC20 for IERC20;
     
    /**
    @notice Construct the contract.
    @param _tokenAddress - the address of the claim token.
    @param _totalAllocation - the allocation amount for this milestone.
    @param _allcationPercents - the allocation percents
    @param _recipient - the address for which we fetch the claim.
    @param _owner - the owner of this contract.
    @dev Factory contract will deposit the token when creating this contract.
    // This is created by Factory contract and Safe wallet can be used, 
    // so factory contract should pass address which will be the owner of this contract.
     */
    constructor(
        IERC20 _tokenAddress,
        uint256 _totalAllocation,
        uint256[] memory _allcationPercents,
        address _recipient,
        address _owner
    ) {
        recipient = _recipient;
        tokenAddress = _tokenAddress;
        _transferOwnership(_owner);
        totalAllocation = _totalAllocation;

        super.initializeMilestones(_allcationPercents);
    }

    /**
    @notice Calculates how much recipient can claim.
    */
    function claimableAmount(
        uint256 _milestoneIndex
    ) public view returns (uint256) {
        if (milestones[_milestoneIndex].isWithdrawn) {
            return 0;
        } else {
            return milestones[_milestoneIndex].allocation;
        }
    }

    /**
    @notice Only recipient can claim when it's completed.
    @dev Withdraw all tokens.
     */
    function widthdraw(
        uint256 _milestoneIndex
    ) public onlyRecipient onlyCompleted(_milestoneIndex) {
        Milestone storage milestone = milestones[_milestoneIndex];
        require(!milestone.isWithdrawn, "ALREADY_WITHDRAWED");

        milestone.isWithdrawn = true;
        tokenAddress.safeTransfer(recipient, milestone.allocation);
    }
}
