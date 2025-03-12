// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MonWorld} from "../src/MonWorld.sol";

contract MonWorldScript is Script {
    function setUp() public {}

    function run() public returns (MonWorld world) {
        uint256 privateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(privateKey);

        world = new MonWorld();

        vm.stopBroadcast();
    }
}
