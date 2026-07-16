pragma solidity ^0.8.24;

import 'forge-std/Test.sol';
import '../examples/StakingPool.sol';
import '../examples/KKToken.sol';
import './ERC20.sol';
import '../../lib/chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol';

contract StakingPoolTest is Test {
    ERC20 public usdt;
    ERC20 public usdc;
    StakingPool public stakingPool;
    KKToken public rewardToken;
    MockV3Aggregator public ethPriceFeed;
    MockV3Aggregator public usdtPriceFeed;
    MockV3Aggregator public usdcPriceFeed;

    address public alice = address(0x1111);
    address public bob = address(0x2222);
    address public charlie = address(0x3333);

    uint256 constant REWARD_PER_BLOCK = 10 ether;
    uint256 constant INITIAL_TOKEN_SUPPLY = 1000000 ether;

    uint256 constant ETH_PRICE = 3000e8;
    uint256 constant USDT_PRICE = 1e8;
    uint256 constant USDC_PRICE = 1e8;

    function setUp() public {
        ethPriceFeed = new MockV3Aggregator(8, int256(ETH_PRICE));
        usdtPriceFeed = new MockV3Aggregator(8, int256(USDT_PRICE));
        usdcPriceFeed = new MockV3Aggregator(8, int256(USDC_PRICE));

        usdt = new ERC20(INITIAL_TOKEN_SUPPLY);
        usdc = new ERC20(INITIAL_TOKEN_SUPPLY);

        stakingPool = new StakingPool(REWARD_PER_BLOCK, ethPriceFeed);

        stakingPool.registerToken(address(usdt), usdtPriceFeed);
        stakingPool.registerToken(address(usdc), usdcPriceFeed);

        rewardToken = stakingPool.rewardToken();

        usdt.transfer(alice, 1000000 ether);
        usdt.transfer(bob, 1000000 ether);
        usdc.transfer(alice, 1000000 ether);
        usdc.transfer(bob, 1000000 ether);
    }

    // ============ ETH 质押测试 ============

    function testStakeETH() public {
        uint256 stakeAmount = 1 ether;

        vm.startPrank(alice);
        stakingPool.depositETH{value: stakeAmount}();
        vm.stopPrank();

        (uint256 ethAmount, , ) = stakingPool.userInfo(alice);
        assertEq(ethAmount, stakeAmount, 'Alice staked ETH should be 1 ether');
        assertEq(stakingPool.totalStakedValue(), 3000 ether, 'Total staked value should be 3000 USD (1 ETH * $3000)');
    }

    function testMiningRewardETH() public {
        uint256 stakeAmount = 1 ether;

        vm.startPrank(alice);
        stakingPool.depositETH{value: stakeAmount}();
        vm.stopPrank();

        vm.roll(block.number + 10);

        uint256 pendingReward = stakingPool.getPendingReward(alice);
        assertEq(pendingReward, 100 ether, 'Pending reward should be 100 KK (10 blocks * 10 KK)');
    }

    function testClaimRewardETH() public {
        uint256 stakeAmount = 1 ether;

        vm.startPrank(alice);
        stakingPool.depositETH{value: stakeAmount}();
        vm.stopPrank();

        vm.roll(block.number + 10);

        uint256 initialRewardBalance = rewardToken.balanceOf(alice);

        vm.startPrank(alice);
        stakingPool.claimReward();
        vm.stopPrank();

        uint256 finalRewardBalance = rewardToken.balanceOf(alice);
        assertEq(finalRewardBalance - initialRewardBalance, 100 ether, 'Alice should receive 100 KK reward');
    }

    // ============ ERC20 质押测试 ============

    function testStakeUSDT() public {
        uint256 stakeAmount = 3000 ether;

        vm.startPrank(alice);
        usdt.approve(address(stakingPool), stakeAmount);
        stakingPool.depositERC20(address(usdt), stakeAmount);
        vm.stopPrank();

        uint256 balance = stakingPool.getUserTokenBalance(alice, address(usdt));
        assertEq(balance, stakeAmount, 'Alice staked USDT should be 3000');
        assertEq(stakingPool.totalStakedValue(), 3000 ether, 'Total staked value should be 3000 USD');
    }

    function testStakeUSDC() public {
        uint256 stakeAmount = 3000 ether;

        vm.startPrank(alice);
        usdc.approve(address(stakingPool), stakeAmount);
        stakingPool.depositERC20(address(usdc), stakeAmount);
        vm.stopPrank();

        uint256 balance = stakingPool.getUserTokenBalance(alice, address(usdc));
        assertEq(balance, stakeAmount, 'Alice staked USDC should be 3000');
    }

    // ============ 价值对等测试 ============

    function testEqualValueEqualReward() public {
        vm.startPrank(alice);
        stakingPool.depositETH{value: 1 ether}();
        vm.stopPrank();

        vm.startPrank(bob);
        usdt.approve(address(stakingPool), 3000 ether);
        stakingPool.depositERC20(address(usdt), 3000 ether);
        vm.stopPrank();

        assertEq(stakingPool.totalStakedValue(), 6000 ether, 'Total staked value should be 6000 USD');

        vm.roll(block.number + 10);

        uint256 aliceReward = stakingPool.getPendingReward(alice);
        uint256 bobReward = stakingPool.getPendingReward(bob);

        assertEq(aliceReward, 50 ether, 'Alice should get 50 KK reward');
        assertEq(bobReward, 50 ether, 'Bob should get 50 KK reward');
    }

    function testDifferentValueDifferentReward() public {
        vm.startPrank(alice);
        stakingPool.depositETH{value: 2 ether}();
        vm.stopPrank();

        vm.startPrank(bob);
        usdt.approve(address(stakingPool), 3000 ether);
        stakingPool.depositERC20(address(usdt), 3000 ether);
        vm.stopPrank();

        assertEq(stakingPool.totalStakedValue(), 9000 ether, 'Total staked value should be 9000 USD');

        vm.roll(block.number + 10);

        uint256 aliceReward = stakingPool.getPendingReward(alice);
        uint256 bobReward = stakingPool.getPendingReward(bob);

        assertEq(aliceReward, 66.666666666666666666 ether, 'Alice should get 2/3 of rewards');
        assertEq(bobReward, 33.333333333333333334 ether, 'Bob should get 1/3 of rewards');
    }

    // ============ 混合质押测试 ============

    function testMixedStaking() public {
        vm.startPrank(alice);
        stakingPool.depositETH{value: 1 ether}();
        usdt.approve(address(stakingPool), 1500 ether);
        stakingPool.depositERC20(address(usdt), 1500 ether);
        vm.stopPrank();

        uint256 aliceValue = stakingPool.getUserTotalValue(alice);
        assertEq(aliceValue, 4500 ether, 'Alice total value should be 4500 USD');
    }

    // ============ 提取测试 ============

    function testWithdrawETH() public {
        uint256 stakeAmount = 1 ether;

        vm.startPrank(alice);
        stakingPool.depositETH{value: stakeAmount}();
        vm.stopPrank();

        vm.roll(block.number + 10);

        uint256 initialETHBalance = alice.balance;

        vm.startPrank(alice);
        stakingPool.withdrawETH(stakeAmount);
        vm.stopPrank();

        uint256 finalETHBalance = alice.balance;
        assertEq(finalETHBalance - initialETHBalance, stakeAmount, 'Alice should get back 1 ETH');
        assertEq(rewardToken.balanceOf(alice), 100 ether, 'Alice should receive 100 KK reward');
    }

    function testWithdrawUSDT() public {
        uint256 stakeAmount = 3000 ether;

        vm.startPrank(alice);
        usdt.approve(address(stakingPool), stakeAmount);
        stakingPool.depositERC20(address(usdt), stakeAmount);
        vm.stopPrank();

        vm.roll(block.number + 10);

        uint256 initialUSDTBalance = usdt.balanceOf(alice);

        vm.startPrank(alice);
        stakingPool.withdrawERC20(address(usdt), stakeAmount);
        vm.stopPrank();

        uint256 finalUSDTBalance = usdt.balanceOf(alice);
        assertEq(finalUSDTBalance - initialUSDTBalance, stakeAmount, 'Alice should get back 3000 USDT');
        assertEq(rewardToken.balanceOf(alice), 100 ether, 'Alice should receive 100 KK reward');
    }

    // ============ 紧急提取测试 ============

    function testEmergencyWithdrawETH() public {
        uint256 stakeAmount = 1 ether;

        vm.startPrank(alice);
        stakingPool.depositETH{value: stakeAmount}();
        vm.stopPrank();

        vm.roll(block.number + 10);

        uint256 initialETHBalance = alice.balance;

        vm.startPrank(alice);
        stakingPool.emergencyWithdrawETH();
        vm.stopPrank();

        uint256 finalETHBalance = alice.balance;
        assertEq(finalETHBalance - initialETHBalance, stakeAmount, 'Alice should get back 1 ETH');
        assertEq(rewardToken.balanceOf(alice), 0, 'Alice should not receive any reward');
    }

    // ============ 价格预言机测试 ============

    function testGetETHPrice() public {
        uint256 price = stakingPool.getETHPrice();
        assertEq(price, ETH_PRICE, 'ETH price should be 3000');
    }

    function testGetTokenPrice() public {
        uint256 usdtPrice = stakingPool.getTokenPrice(address(usdt));
        assertEq(usdtPrice, USDT_PRICE, 'USDT price should be 1');
    }

    function testCalculateETHValue() public {
        uint256 value = stakingPool.calculateETHValue(1 ether);
        assertEq(value, 3000 ether, '1 ETH should be worth 3000 USD');
    }

    function testCalculateTokenValue() public {
        uint256 value = stakingPool.calculateTokenValue(address(usdt), 3000 ether);
        assertEq(value, 3000 ether, '3000 USDT should be worth 3000 USD');
    }

    // ============ 管理函数测试 ============

    function testRegisterToken() public {
        ERC20 newToken = new ERC20(INITIAL_TOKEN_SUPPLY);
        MockV3Aggregator newPriceFeed = new MockV3Aggregator(8, int256(2e8));

        vm.prank(address(this));
        stakingPool.registerToken(address(newToken), newPriceFeed);

        assertEq(stakingPool.isTokenRegistered(address(newToken)), true, 'New token should be registered');
    }

    function testSetRewardPerBlock() public {
        uint256 newRewardPerBlock = 20 ether;

        vm.prank(address(this));
        stakingPool.setRewardPerBlock(newRewardPerBlock);

        assertEq(stakingPool.rewardPerBlock(), newRewardPerBlock, 'Reward per block should be updated');
    }

    // ============ 边界情况测试 ============

    function testUnregisteredToken() public {
        ERC20 unregisteredToken = new ERC20(INITIAL_TOKEN_SUPPLY);

        vm.startPrank(alice);
        unregisteredToken.approve(address(stakingPool), 100 ether);
        vm.expectRevert('Token not registered');
        stakingPool.depositERC20(address(unregisteredToken), 100 ether);
        vm.stopPrank();
    }

    function testZeroDepositETH() public {
        vm.startPrank(alice);
        vm.expectRevert();
        stakingPool.depositETH{value: 0}();
        vm.stopPrank();
    }

    function testZeroDepositERC20() public {
        vm.startPrank(alice);
        vm.expectRevert();
        stakingPool.depositERC20(address(usdt), 0);
        vm.stopPrank();
    }

    // ============ KK Token 铸造测试 ============

    function testKKTokenMinting() public {
        uint256 stakeAmount = 1 ether;

        vm.startPrank(alice);
        stakingPool.depositETH{value: stakeAmount}();
        vm.stopPrank();

        assertEq(rewardToken.totalSupply(), 0, 'KK Token total supply should be 0');

        vm.roll(block.number + 10);

        vm.startPrank(alice);
        stakingPool.claimReward();
        vm.stopPrank();

        assertEq(rewardToken.totalSupply(), 100 ether, 'KK Token total supply should be 100');
        assertEq(rewardToken.balanceOf(alice), 100 ether, 'Alice should have 100 KK Token');
    }
}