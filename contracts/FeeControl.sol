//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";

contract FeeControl is Ownable {
    uint256 public feePercent; // Fee percent.  500 means 5%, 1 means 0.01 %
    address public feeReceiver; // The receier address that will get the fee.

    constructor(address _feeReceiver) {
        feeReceiver = _feeReceiver;
    }

    function setFee(uint256 _feePercent) public onlyOwner {
        if (_feePercent > 0 && _feePercent < 10000) {
            feePercent = _feePercent;
        } else {
            revert("INVALID_FEE_PERCENT");
        }
    }

    function updateFeeReceiver(address _newReceiver) public onlyOwner {
        feeReceiver = _newReceiver;
    }
}
