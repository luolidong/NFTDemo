// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {TokenVesting} from "../src/TokenVesting.sol";
import {MyToken} from "../src/MyToken.sol";

contract DeployTokenVestingScript is Script {
    MyToken public token;
    TokenVesting public vesting;

    address public BENEFICIARY = vm.envAddress("BENEFICIARY");
    uint256 public constant TOTAL_TOKENS = 1_000_000 ether;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        token = new MyToken();
        
        vesting = new TokenVesting(BENEFICIARY, address(token));
        
        token.transfer(address(vesting), TOTAL_TOKENS);

        vm.stopBroadcast();
    }
}