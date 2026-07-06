// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {TokenVesting} from "../src/TokenVesting.sol";
import {MyToken} from "../src/MyToken.sol";

contract TokenVestingTest is Test {
    MyToken public token;
    TokenVesting public vesting;
    address public beneficiary = address(0x1234);
    address public deployer = address(0x5678);

    uint64 public constant SECONDS_PER_MONTH = 30 days;
    uint256 public constant TOTAL_TOKENS = 1_000_000 ether;

    function setUp() public {
        vm.startPrank(deployer);
        token = new MyToken();
        vesting = new TokenVesting(beneficiary, address(token));
        token.transfer(address(vesting), TOTAL_TOKENS);
        vm.stopPrank();
    }

    function test_Constructor() public view {
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.owner(), beneficiary);
        assertEq(vesting.cliff(), uint64(block.timestamp) + 12 * SECONDS_PER_MONTH);
        assertEq(vesting.duration(), 36 * SECONDS_PER_MONTH);
        assertEq(vesting.end(), uint64(block.timestamp) + 36 * SECONDS_PER_MONTH);
    }

    function test_CliffPeriod_NoRelease() public {
        uint256 initialBeneficiaryBalance = token.balanceOf(beneficiary);
        uint256 initialVestingBalance = token.balanceOf(address(vesting));

        vm.warp(block.timestamp + 6 * SECONDS_PER_MONTH);

        vm.prank(beneficiary);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), initialBeneficiaryBalance);
        assertEq(token.balanceOf(address(vesting)), initialVestingBalance);
        assertEq(vesting.released(address(token)), 0);
    }

    function test_AfterCliff_FirstRelease() public {
        uint256 expectedRelease = TOTAL_TOKENS / 24;

        vm.warp(block.timestamp + 13 * SECONDS_PER_MONTH);

        vm.prank(beneficiary);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), expectedRelease);
        assertEq(token.balanceOf(address(vesting)), TOTAL_TOKENS - expectedRelease);
        assertEq(vesting.released(address(token)), expectedRelease);
    }

    function test_AfterMultipleMonths_AccumulatedRelease() public {
        vm.warp(block.timestamp + 15 * SECONDS_PER_MONTH);

        vm.prank(beneficiary);
        vesting.release();

        uint256 expectedRelease = (TOTAL_TOKENS * 3) / 24;
        assertEq(token.balanceOf(beneficiary), expectedRelease);
        assertEq(token.balanceOf(address(vesting)), TOTAL_TOKENS - expectedRelease);
        assertEq(vesting.released(address(token)), expectedRelease);
    }

    function test_MonthlyReleases() public {
        uint256 startTimestamp = block.timestamp;
        
        for (uint256 i = 13; i <= 36; i++) {
            vm.warp(startTimestamp + i * SECONDS_PER_MONTH);

            vm.prank(beneficiary);
            vesting.release();

            uint256 monthsSinceCliff = i - 12;
            uint256 expectedTotalReleased = (TOTAL_TOKENS * monthsSinceCliff) / 24;
            
            if (i == 36) {
                expectedTotalReleased = TOTAL_TOKENS;
            }

            assertEq(token.balanceOf(beneficiary), expectedTotalReleased, "Month release mismatch");
        }

        assertEq(token.balanceOf(address(vesting)), 0);
        assertEq(vesting.released(address(token)), TOTAL_TOKENS);
    }

    function test_FullVesting() public {
        vm.warp(block.timestamp + 36 * SECONDS_PER_MONTH);

        vm.prank(beneficiary);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), TOTAL_TOKENS);
        assertEq(token.balanceOf(address(vesting)), 0);
        assertEq(vesting.released(address(token)), TOTAL_TOKENS);
    }

    function test_PartialMonth_NoExtraRelease() public {
        vm.warp(block.timestamp + 13 * SECONDS_PER_MONTH + 15 days);

        vm.prank(beneficiary);
        vesting.release();

        uint256 expectedRelease = TOTAL_TOKENS / 24;
        assertEq(token.balanceOf(beneficiary), expectedRelease);
    }

    function test_MultipleReleaseCalls_SameMonth() public {
        vm.warp(block.timestamp + 13 * SECONDS_PER_MONTH);

        vm.prank(beneficiary);
        vesting.release();

        uint256 firstRelease = token.balanceOf(beneficiary);

        vm.prank(beneficiary);
        vesting.release();

        assertEq(token.balanceOf(beneficiary), firstRelease);
    }

    function test_Releasable_ViewFunction() public {
        uint256 startTimestamp = block.timestamp;
        
        assertEq(vesting.releasable(address(token)), 0);
        
        vm.warp(startTimestamp + 6 * SECONDS_PER_MONTH);
        assertEq(vesting.releasable(address(token)), 0);
        
        vm.warp(startTimestamp + 13 * SECONDS_PER_MONTH);
        assertEq(vesting.releasable(address(token)), TOTAL_TOKENS / 24);
        
        vm.warp(startTimestamp + 15 * SECONDS_PER_MONTH);
        assertEq(vesting.releasable(address(token)), (TOTAL_TOKENS * 3) / 24);
        
        vm.warp(startTimestamp + 36 * SECONDS_PER_MONTH);
        assertEq(vesting.releasable(address(token)), TOTAL_TOKENS);
    }

    function test_AtCliffTimestamp_NoRelease() public {
        uint256 initialBeneficiaryBalance = token.balanceOf(beneficiary);
        
        vm.warp(block.timestamp + 12 * SECONDS_PER_MONTH);
        
        vm.prank(beneficiary);
        vesting.release();
        
        assertEq(token.balanceOf(beneficiary), initialBeneficiaryBalance);
        assertEq(vesting.released(address(token)), 0);
    }

    function test_NonBeneficiary_CallRelease() public {
        address nonBeneficiary = address(0x9999);
        
        vm.warp(block.timestamp + 13 * SECONDS_PER_MONTH);
        
        vm.prank(nonBeneficiary);
        vesting.release();
        
        uint256 expectedRelease = TOTAL_TOKENS / 24;
        assertEq(token.balanceOf(beneficiary), expectedRelease);
        assertEq(token.balanceOf(nonBeneficiary), 0);
    }
}