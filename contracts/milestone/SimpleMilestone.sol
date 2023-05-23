//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./BaseMilestone.sol";

contract SimpleMilestone is BaseMilestone {
    using SafeERC20 for IERC20;

    /**
    @notice Construct the contract.
    @param _tokenAddress - the address of the claim token.
    @param _allocation - the allocation amount for this milestone.
    @param _allcationPercents - the allocation percents
    @param _recipients - the addresses for which we fetch the claim.
    @param _owner - the owner of this contract.
    @dev Factory contract will deposit the token when creating this contract.
    // This is created by Factory contract and Safe wallet can be used, 
    // so factory contract should pass address which will be the owner of this contract.
     */
    constructor(
        IERC20 _tokenAddress,
        uint256 _allocation,
        uint256[] memory _allcationPercents,
        address[] memory _recipients,
        address _owner
    ) {
        recipients = _recipients;
        tokenAddress = _tokenAddress;
        _transferOwnership(_owner);
        allocation = _allocation;

        super.initializeAllocations(_allcationPercents);
    }

    /**
    @notice Calculates how much recipient can claim.
    */
    function claimableAmount(
        address _recipient,
        uint256 _milestoneIndex
    ) public view returns (uint256) {
        Milestone memory milestone = milestones[_recipient][_milestoneIndex];
        if (milestone.startTime == 0 || milestone.isWithdrawn) {
            return 0;
        } else {
            return milestone.allocation;
        }
    }

    /**
    @notice Only recipient can claim when it's completed.
    @dev Withdraw all tokens.
     */
    function withdraw(
        uint256 _milestoneIndex
    )
        public
        hasMilestone(_msgSender(), _milestoneIndex)
        onlyCompleted(_msgSender(), _milestoneIndex)
    {
        Milestone storage milestone = milestones[_msgSender()][_milestoneIndex];
        require(!milestone.isWithdrawn, "ALREADY_WITHDRAWED");

        milestone.isWithdrawn = true;
        tokenAddress.safeTransfer(_msgSender(), milestone.allocation);
    }
}
