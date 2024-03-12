// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import { DrawManager } from "pt-v5-draw-manager/DrawManager.sol";

import { RngBlockhash } from "../src/RngBlockhash.sol";

contract RngBlockhashTest is Test {

    RngBlockhash rng;
    DrawManager drawManager;

    function setUp() public {
        rng = new RngBlockhash();
        drawManager = DrawManager(makeAddr("drawManager"));
        vm.etch(address(drawManager), "drawManager"); // to ensure calls fail if not mocked
    }

    function test_startDraw() public {
        address recipient = makeAddr("recipient");
        vm.mockCall(address(drawManager), abi.encodeWithSelector(drawManager.startDraw.selector, recipient, 1), abi.encode(22));
        assertEq(rng.startDraw(drawManager, recipient), 22);
    }

}