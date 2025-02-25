// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Manager, SatoshiDollar, IOracle} from "../src/MicroStable.sol";

contract CounterScript is Script {
    
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address WBTC = vm.envAddress("WBTC");
        address oracle = vm.envAddress("oracle");

        // Predict manager's address
        address predictedManagerAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);

        SatoshiDollar satoshiDollar = new SatoshiDollar(predictedManagerAddress);
        Manager manager = new Manager(address(WBTC), address(satoshiDollar), oracle);

        vm.stopBroadcast();
        require(predictedManagerAddress == address(manager), "deployment address error");
    }
}
