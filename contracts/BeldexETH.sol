// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./Utils.sol";
import "./BeldexBase.sol";

contract BeldexETH is BeldexBase {
    using Utils for uint256;
    using Utils for Utils.G1Point;

    constructor(address _transfer, address _redeem, uint256 _unit) BeldexBase(_transfer, _redeem, _unit) {
    }

    function mint(Utils.G1Point memory y, uint256 unitAmount, bytes memory encGuess) public payable {
        uint256 mUnitAmount = toUnitAmount(msg.value);
        require(unitAmount == mUnitAmount, "[Beldex mint] Specified mint amount is differnet from the paid amount.");

        mintBase(y, unitAmount, encGuess);
    }

    function redeem(Utils.G1Point memory y, uint256 unitAmount, Utils.G1Point memory u, bytes memory proof, bytes memory encGuess) public {
        uint256 nativeAmount = toNativeAmount(unitAmount);
        redeemBase(y, unitAmount, u, proof, encGuess);
        msg.sender.transfer(nativeAmount);
    }

    function transfer(Utils.G1Point[] memory C, Utils.G1Point memory D, 
                      Utils.G1Point[] memory y, Utils.G1Point memory u, 
                      bytes memory proof) public payable {

        // TODO: check that sender and receiver should NOT be equal.
        uint256 size = y.length;
        Utils.G1Point[] memory CLn = new Utils.G1Point[](size);
        Utils.G1Point[] memory CRn = new Utils.G1Point[](size);
        require(C.length == size, "[Beldex transfer] Input array length mismatch!");


        for (uint256 i = 0; i < size; i++) {
            bytes32 yHash = keccak256(abi.encode(y[i]));
            require(registered(yHash), "[Beldex transfer] Account not yet registered.");
            rollOver(yHash);
            Utils.G1Point[2] memory scratch = pending[yHash];
            pending[yHash][0] = scratch[0].pAdd(C[i]);
            pending[yHash][1] = scratch[1].pAdd(D);

            scratch = acc[yHash];
            CLn[i] = scratch[0].pAdd(C[i]);
            CRn[i] = scratch[1].pAdd(D);
        }

        bytes32 uHash = keccak256(abi.encode(u));
        for (uint256 i = 0; i < nonce_set.length; i++) {
            require(nonce_set[i] != uHash, "[Beldex transfer] Nonce already seen!");
        }
        nonce_set.push(uHash);

        BeldexTransfer.Statement memory beldex_stm = beldex_transfer.wrapStatement(CLn, CRn, C, D, y, last_global_update, u);
        BeldexTransfer.Proof memory beldex_proof = beldex_transfer.unserialize(proof);

        require(beldex_transfer.verify(beldex_stm, beldex_proof), "[Beldex transfer] Failed: verification");

        emit TransferOccurred(y);
    }

}