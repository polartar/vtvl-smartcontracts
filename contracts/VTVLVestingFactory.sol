// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.14;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./VTVLVesting.sol";

/// @title Vesting Factory contract
/// @notice Create Vesting contract

contract VTVLVestingFactory is Ownable {
    using SafeERC20 for IERC20;

    event CreateVestingContract(
        address indexed vestingAddress,
        address deployer
    );

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

    function _calculateAmount(
        ClaimInput[] calldata _cliamInputs
    ) private pure returns (uint256) {
        uint256 len = _cliamInputs.length;
        uint256 amount;
        for (uint256 i = 0; i < len; ) {
            unchecked {
                amount +=
                    _cliamInputs[i].linearVestAmount +
                    _cliamInputs[i].cliffAmount;
                ++i;
            }
        }

        return amount;
    }

    /**
     * @notice Create Vesting contract without funding.
     * @dev This will only create the vesting contract.
     * @param _tokenAddress Vesting Fund token address.
     */
    function createVestingContract(IERC20 _tokenAddress) public {
        VTVLVesting vestingContract = new VTVLVesting(
            _tokenAddress,
            msg.sender
        );

        emit CreateVestingContract(address(vestingContract), msg.sender);
    }

    /**
     * @notice Create Vesting contract with funding and schedules.
     * @dev This will deposit funds and create the vesting schedules as well.
     * @param _tokenAddress Vesting Fund token address.
     */
    function createVestingContractWithShcedules(
        IERC20 _tokenAddress,
        ClaimInput[] calldata claimInputs
    ) public {
        require(claimInputs.length != 0, "Invalid Claims");

        VTVLVesting vestingContract = new VTVLVesting(
            _tokenAddress,
            msg.sender
        );

        uint256 _depositAmount = _calculateAmount(claimInputs);

        _deposit(_tokenAddress, _depositAmount, address(vestingContract));

        vestingContract.createClaimsBatch(claimInputs);

        emit CreateVestingContract(address(vestingContract), msg.sender);
    }
}
