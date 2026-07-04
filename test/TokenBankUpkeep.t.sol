// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/TokenBank.sol";
import "../src/TokenBankUpkeep.sol";
import "../src/MyPermitToken.sol";

contract TokenBankUpkeepTest is Test {
    MyPermitToken public token;
    TokenBank public bank;
    TokenBankUpkeep public upkeep;
    address public owner;
    address public user1;
    uint256 public user1PrivateKey;

    function setUp() public {
        owner = address(this);
        user1PrivateKey = 1;
        user1 = vm.addr(user1PrivateKey);

        token = new MyPermitToken();

        address permit2Address = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
        bank = new TokenBank(address(token), permit2Address);

        upkeep = new TokenBankUpkeep(address(bank));
        bank.setCollector(address(upkeep));

        token.transfer(user1, 10000 * 10 ** 18);
    }

    function test_CheckUpkeep_BelowThreshold() public {
        uint256 depositAmount = 50 * 10 ** 18;
        vm.prank(user1);
        token.approve(address(bank), depositAmount);
        vm.prank(user1);
        bank.deposit(depositAmount);

        (bool upkeepNeeded, ) = upkeep.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    function test_CheckUpkeep_AboveThreshold() public {
        uint256 depositAmount = 200 * 10 ** 18;
        vm.prank(user1);
        token.approve(address(bank), depositAmount);
        vm.prank(user1);
        bank.deposit(depositAmount);

        (bool upkeepNeeded, bytes memory performData) = upkeep.checkUpkeep("");
        assertTrue(upkeepNeeded);
        uint256 balance = abi.decode(performData, (uint256));
        assertEq(balance, depositAmount);
    }

    function test_PerformUpkeep() public {
        uint256 depositAmount = 200 * 10 ** 18;
        vm.prank(user1);
        token.approve(address(bank), depositAmount);
        vm.prank(user1);
        bank.deposit(depositAmount);

        uint256 bankBalanceBefore = token.balanceOf(address(bank));
        uint256 ownerBalanceBefore = token.balanceOf(owner);

        upkeep.performUpkeep("");

        uint256 expectedCollectAmount = bankBalanceBefore / 2;
        assertEq(token.balanceOf(address(bank)), bankBalanceBefore - expectedCollectAmount);
        assertEq(token.balanceOf(owner), ownerBalanceBefore + expectedCollectAmount);
    }

    function test_PerformUpkeep_RevertIf_BelowThreshold() public {
        uint256 depositAmount = 50 * 10 ** 18;
        vm.prank(user1);
        token.approve(address(bank), depositAmount);
        vm.prank(user1);
        bank.deposit(depositAmount);

        vm.expectRevert("Balance below threshold");
        upkeep.performUpkeep("");
    }
}