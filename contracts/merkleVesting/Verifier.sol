pragma solidity ^0.8.14;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Verifier {
    bytes32 private root;

    // constructor(bytes32 _root) {
    //     root = _root;
    // }

    function setMerleRoot(bytes32 _root) public {
        root = _root;
    }

    function verify(bytes32[] memory proof, bytes32 leaf) public view {
        require(MerkleProof.verify(proof, root, leaf), "Invalid proof");
    }
}
