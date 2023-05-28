// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.14;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./VTVLVesting.sol";
import "./IVestingFee.sol";

/// @title Vesting Factory contract
/// @notice Create Vesting contract

contract VTVLVestingFactory is Ownable {
    using SafeERC20 for IERC20;

    event CreateVestingContract(
        address indexed vestingAddress,
        address deployer
    );

    mapping(address => bool) isVestingContracts;

    /**
    @notice This modifier requires the vesting contract.
    */
    modifier onlyVestingContract(address _vestingContract) {
        require(
            isVestingContracts[_vestingContract],
            "Not our vesting contract"
        );
        _;
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

        isVestingContracts[address(vestingContract)] = true;

        emit CreateVestingContract(address(vestingContract), msg.sender);
    }

    /**
     * @notice Set the fee percent of Vesting contract.
     * @dev 100% will be 10000.
     */
    function setFee(
        address _vestingContract,
        uint256 _feePercent
    ) external onlyOwner onlyVestingContract(_vestingContract) {
        if (_feePercent > 0 && _feePercent < 10000) {
            IVestingFee(_vestingContract).setFee(_feePercent);
        } else {
            revert("INVALID_FEE_PERCENT");
        }
    }

    /**
     * @notice Set the fee recipient of Vesting contract.
     */
    function updateFeeReceiver(
        address _vestingContract,
        address _newReceiver
    ) external onlyOwner onlyVestingContract(_vestingContract) {
        IVestingFee(_vestingContract).updateFeeReceiver(_newReceiver);
    }

    /**
     * @notice Set the fee recipient of Vesting contract.
     */
    function withdraw(
        address _tokenAddress,
        address _receiver
    ) external onlyOwner {
        uint256 amount = IERC20(_tokenAddress).balanceOf(address(this));
        IERC20(_tokenAddress).transfer(_receiver, amount);
    }

    // We will need the below functions later.

    // /**
    //  * @notice Create Vesting contract with funding and schedules.
    //  * @dev This will deposit funds and create the vesting schedules as well.
    //  * @param _tokenAddress Vesting Fund token address.
    //  */
    // function createVestingContractWithSchedules(
    //     IERC20 _tokenAddress,
    //     ClaimInput[] calldata claimInputs
    // ) public {
    //     require(claimInputs.length != 0, "Invalid Claims");

    //     VTVLVesting vestingContract = new VTVLVesting(
    //         _tokenAddress,
    //         msg.sender
    //     );

    //     uint256 _depositAmount = _calculateAmount(claimInputs);

    //     _deposit(_tokenAddress, _depositAmount, address(vestingContract));

    //     vestingContract.createClaimsBatch(claimInputs);

    //     emit CreateVestingContract(address(vestingContract), msg.sender);
    // }

    // function _deposit(
    //     IERC20 _tokenAddress,
    //     uint256 _amount,
    //     address _contractAddress
    // ) private {
    //     uint256 userBalance = _tokenAddress.balanceOf(msg.sender);

    //     if (userBalance >= _amount) {
    //         _tokenAddress.safeTransferFrom(
    //             msg.sender,
    //             address(_contractAddress),
    //             _amount
    //         );
    //     }
    // }

    // function _calculateAmount(
    //     ClaimInput[] calldata _cliamInputs
    // ) private pure returns (uint256) {
    //     uint256 len = _cliamInputs.length;
    //     uint256 amount;
    //     for (uint256 i = 0; i < len; ) {
    //         unchecked {
    //             amount +=
    //                 _cliamInputs[i].linearVestAmount +
    //                 _cliamInputs[i].cliffAmount;
    //             ++i;
    //         }
    //     }

    //     return amount;
    // }
}
