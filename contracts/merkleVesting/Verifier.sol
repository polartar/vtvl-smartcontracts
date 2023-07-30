pragma solidity ^0.8.14;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Verifier {
    bytes32 private root;

    // constructor(bytes32 _root) {
    //     root = _root;
    // }

    function setMerleRoot(bytes32 _root) external {
        root = _root;
    }

    function verify(
        bytes32[] memory proof,
        address addr,
        uint256 amount
    ) public view {
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(addr, amount)))
        );
        require(MerkleProof.verify(proof, root, leaf), "Invalid proof");
    }
}
