// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/RebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken public token;
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    
    uint256 public constant INITIAL_SUPPLY = 10000000 * 10**18;
    uint256 public constant YEAR = 365 days;
    
    function setUp() public {
        vm.startPrank(owner);
        token = new RebaseToken();
        vm.stopPrank();
    }
    
    function testInitialSupply() public {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.scalingFactor(), 1e18);
    }
    
    function testTransferBeforeRebase() public {
        uint256 transferAmount = 1000 * 10**18;
        
        vm.prank(owner);
        token.transfer(user1, transferAmount);
        
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
        assertEq(token.balanceOf(user1), transferAmount);
    }
    
    function testRebaseAfterOneYear() public {
        uint256 transferAmount = 1000 * 10**18;
        
        vm.prank(owner);
        token.transfer(user1, transferAmount);
        
        vm.warp(block.timestamp + YEAR);
        
        vm.prank(owner);
        token.rebase();
        
        uint256 expectedTotalSupply = INITIAL_SUPPLY * 99 / 100;
        uint256 expectedOwnerBalance = (INITIAL_SUPPLY - transferAmount) * 99 / 100;
        uint256 expectedUser1Balance = transferAmount * 99 / 100;
        
        assertEq(token.totalSupply(), expectedTotalSupply);
        assertEq(token.balanceOf(owner), expectedOwnerBalance);
        assertEq(token.balanceOf(user1), expectedUser1Balance);
        assertEq(token.scalingFactor(), 1e18 * 99 / 100);
    }
    
    function testRebaseIntervalNotElapsed() public {
        vm.expectRevert("Rebase interval not elapsed");
        vm.prank(owner);
        token.rebase();
    }
    
    function testRebaseMultipleYears() public {
        vm.warp(block.timestamp + YEAR);
        vm.prank(owner);
        token.rebase();
        assertEq(token.scalingFactor(), 1e18 * 99 / 100);
        
        vm.warp(block.timestamp + YEAR);
        vm.prank(owner);
        token.rebase();
        assertEq(token.scalingFactor(), 1e18 * 99 / 100 * 99 / 100);
        
        uint256 expectedTotalSupply = INITIAL_SUPPLY * 99 / 100 * 99 / 100;
        assertEq(token.totalSupply(), expectedTotalSupply);
    }
    
    function testTransferAfterRebase() public {
        uint256 transferAmount = 1000 * 10**18;
        
        vm.prank(owner);
        token.transfer(user1, transferAmount);
        
        vm.warp(block.timestamp + YEAR);
        vm.prank(owner);
        token.rebase();
        
        uint256 user1BalanceAfterRebase = token.balanceOf(user1);
        uint256 transferAfterRebase = user1BalanceAfterRebase / 2;
        
        vm.prank(user1);
        token.transfer(user2, transferAfterRebase);
        
        assertEq(token.balanceOf(user1), user1BalanceAfterRebase - transferAfterRebase);
        assertEq(token.balanceOf(user2), transferAfterRebase);
    }
    
    function testApproveAndTransferFrom() public {
        uint256 transferAmount = 500 * 10**18;
        
        vm.prank(owner);
        token.approve(user1, transferAmount);
        
        vm.prank(user1);
        token.transferFrom(owner, user2, transferAmount);
        
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
        assertEq(token.balanceOf(user2), transferAmount);
        assertEq(token.allowance(owner, user1), 0);
    }
    
    function testApproveAndTransferFromAfterRebase() public {
        uint256 transferAmount = 500 * 10**18;
        
        vm.prank(owner);
        token.approve(user1, transferAmount);
        
        vm.warp(block.timestamp + YEAR);
        vm.prank(owner);
        token.rebase();
        
        uint256 scaledTransferAmount = transferAmount * 99 / 100;
        
        vm.prank(user1);
        token.transferFrom(owner, user2, scaledTransferAmount);
        
        assertEq(token.balanceOf(user2), scaledTransferAmount);
    }
}