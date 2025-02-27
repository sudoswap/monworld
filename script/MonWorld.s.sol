// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MonWorld} from "../src/MonWorld.sol";

contract MonWorldScript is Script {
    function setUp() public {}

    function run() public returns (MonWorld world) {
        vm.startBroadcast();

        world = new MonWorld();

        vm.stopBroadcast();
    }
}
