//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleMilestone is Ownable {
    bool public isCompleted;
    address public recipient;
    IERC20 public tokenAddress;
    bool public isDeposited;
    uint256 public allocation;

    /**
    @notice Construct the contract.
    @param _tokenAddress - the address of the claim token.
    @param _allocation - the allocation amount for this milestone.
    @param _recipient - the address for which we fetch the claim.
    @param _owner - the owner of this contract.
    @param _isDeposited - the deposite state.
    @dev Factory contract will deposit the token when creating this contract.
    // This is created by Factory contract and Safe wallet can be used, 
    // so factory contract should pass address which will be the owner of this contract.
     */
    constructor(
        IERC20 _tokenAddress,
        uint256 _allocation,
        address _recipient,
        address _owner,
        bool _isDeposited
    ) {
        recipient = _recipient;
        tokenAddress = _tokenAddress;
        _transferOwnership(_owner);
        isDeposited = _isDeposited;
        allocation = _allocation;
    }

    modifier onlyRecipient() {
        require(msg.sender == recipient, "NO_RECIPIENT");

        _;
    }

    modifier onlyCompleted() {
        require(isCompleted, "NOT_COMPLETED");

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
    }

    /**
    @notice Only recipient can claim when it's completed.
    @dev Withdraw all tokens.
     */
    function claim() public onlyRecipient onlyCompleted {
        IERC20(tokenAddress).transfer(recipient, allocation);
    }

    /**
    @notice Only admin can withdraw the remaining balance.
    @dev Withdraw the token amount that excludes allocation.
     */
    function withdraw() public onlyOwner {
        uint256 balance = tokenAddress.balanceOf(address(this));
        if (balance > allocation) {
            IERC20(tokenAddress).transfer(msg.sender, balance - allocation);
        }
    }

    function deposit(uint256 amount) public {
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
    }
}
