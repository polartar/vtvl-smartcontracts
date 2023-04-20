//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleMilestone is Ownable {
    bool public isCompleted;
    address public recipient;
    address public tokenAddress;

    /**
    @notice Construct the contract.
    @param _tokenAddress - the address of the claim token.
    @param _recipient - the address for which we fetch the claim.
    @param _owner - the owner of this contract.
    @dev Factory contract will deposit the token when creating this contract.
    // This is created by Factory contract and Safe wallet can be used, 
    // so factory contract should pass address which will be the owner of this contract.
     */
    constructor(address _tokenAddress, address _recipient, address _owner) {
        recipient = _recipient;
        tokenAddress = _tokenAddress;
        _transferOwnership(_owner);
    }

    modifier onlyRecipient() {
        require(msg.sender == recipient, "NO_RECIPIENT");

        _;
    }

    modifier onlyCompleted() {
        require(isCompleted, "NOT_COMPLETED");

        _;
    }

    /**
    @notice Only recipient can withdraw when it's completed.
    @dev Only onwer can mark as completed.
     */
    function setComplete() public onlyOwner {
        isCompleted = true;
    }

    /**
    @notice Only recipient can withdraw when it's completed.
    @dev Withdraw all tokens.
     */
    function withdraw() public onlyRecipient onlyCompleted {
        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
        IERC20(tokenAddress).transfer(recipient, balance);
    }
}
