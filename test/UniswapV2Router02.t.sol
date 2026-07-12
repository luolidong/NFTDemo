// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {UniswapV2Factory} from "../uniswapv2/UniswapV2Factory.sol";
import {UniswapV2Router02} from "../uniswapv2/UniswapV2Router02.sol";
import {UniswapV2Pair} from "../uniswapv2/UniswapV2Pair.sol";
import {WETH9} from "../uniswapv2/test/WETH9.sol";
import {ERC20} from "../uniswapv2/test/ERC20.sol";

contract UniswapV2Router02Test is Test {
    UniswapV2Factory public factory;
    UniswapV2Router02 public router;
    WETH9 public weth;
    ERC20 public tokenA;
    ERC20 public tokenB;

    address public constant ALICE = address(0x1234);
    address public constant BOB = address(0x5678);

    uint256 public constant INITIAL_AMOUNT = 1000 ether;
    uint256 public constant LIQUIDITY_AMOUNT = 100 ether;

    function setUp() public {
        weth = new WETH9();
        factory = new UniswapV2Factory(address(this));
        router = new UniswapV2Router02(address(factory), address(weth));

        tokenA = new ERC20(INITIAL_AMOUNT);
        tokenB = new ERC20(INITIAL_AMOUNT);

        tokenA.transfer(ALICE, INITIAL_AMOUNT);
        tokenB.transfer(ALICE, INITIAL_AMOUNT);

        vm.deal(ALICE, 1000 ether);
        vm.deal(BOB, 1000 ether);

        vm.prank(ALICE);
        tokenA.transfer(BOB, 500 ether);
        vm.prank(ALICE);
        tokenB.transfer(BOB, 500 ether);
    }

    function test_AddLiquidity() public {
        vm.prank(ALICE);
        tokenA.approve(address(router), LIQUIDITY_AMOUNT);
        vm.prank(ALICE);
        tokenB.approve(address(router), LIQUIDITY_AMOUNT);

        vm.prank(ALICE);
        (uint amountA, uint amountB, uint liquidity) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            0,
            0,
            ALICE,
            block.timestamp + 1 hours
        );

        assertEq(amountA, LIQUIDITY_AMOUNT);
        assertEq(amountB, LIQUIDITY_AMOUNT);
        assertGt(liquidity, 0);

        address pair = factory.getPair(address(tokenA), address(tokenB));
        assertNotEq(pair, address(0));
        assertEq(IERC20(pair).balanceOf(ALICE), liquidity);
    }

    function test_AddLiquidityETH() public {
        vm.prank(ALICE);
        tokenA.approve(address(router), LIQUIDITY_AMOUNT);

        vm.prank(ALICE);
        (uint amountA, uint amountETH, uint liquidity) = router.addLiquidityETH{value: LIQUIDITY_AMOUNT}(
            address(tokenA),
            LIQUIDITY_AMOUNT,
            0,
            0,
            ALICE,
            block.timestamp + 1 hours
        );

        assertEq(amountA, LIQUIDITY_AMOUNT);
        assertEq(amountETH, LIQUIDITY_AMOUNT);
        assertGt(liquidity, 0);

        address pair = factory.getPair(address(tokenA), address(weth));
        assertNotEq(pair, address(0));
        assertEq(IERC20(pair).balanceOf(ALICE), liquidity);
    }

    function test_RemoveLiquidity() public {
        test_AddLiquidity();

        address pair = factory.getPair(address(tokenA), address(tokenB));
        uint liquidity = IERC20(pair).balanceOf(ALICE);

        vm.prank(ALICE);
        IERC20(pair).approve(address(router), liquidity);

        vm.prank(ALICE);
        (uint amountA, uint amountB) = router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            liquidity,
            0,
            0,
            ALICE,
            block.timestamp + 1 hours
        );

        assertGt(amountA, 0);
        assertGt(amountB, 0);
        assertEq(IERC20(pair).balanceOf(ALICE), 0);
    }

    function test_SwapExactTokensForTokens() public {
        test_AddLiquidity();

        uint swapAmount = 10 ether;
        vm.prank(BOB);
        tokenA.approve(address(router), swapAmount);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint balanceBBefore = tokenB.balanceOf(BOB);

        vm.prank(BOB);
        uint[] memory amounts = router.swapExactTokensForTokens(
            swapAmount,
            0,
            path,
            BOB,
            block.timestamp + 1 hours
        );

        assertEq(amounts[0], swapAmount);
        assertGt(amounts[1], 0);
        assertEq(tokenB.balanceOf(BOB) - balanceBBefore, amounts[1]);
    }

    function test_SwapExactETHForTokens() public {
        test_AddLiquidityETH();

        uint swapAmount = 10 ether;
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tokenA);

        uint balanceABefore = tokenA.balanceOf(BOB);

        vm.prank(BOB);
        uint[] memory amounts = router.swapExactETHForTokens{value: swapAmount}(
            0,
            path,
            BOB,
            block.timestamp + 1 hours
        );

        assertEq(amounts[0], swapAmount);
        assertGt(amounts[1], 0);
        assertEq(tokenA.balanceOf(BOB) - balanceABefore, amounts[1]);
    }

    function test_SwapExactTokensForETH() public {
        test_AddLiquidityETH();

        uint swapAmount = 10 ether;
        vm.prank(BOB);
        tokenA.approve(address(router), swapAmount);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(weth);

        uint balanceETHBefore = BOB.balance;

        vm.prank(BOB);
        uint[] memory amounts = router.swapExactTokensForETH(
            swapAmount,
            0,
            path,
            BOB,
            block.timestamp + 1 hours
        );

        assertEq(amounts[0], swapAmount);
        assertGt(amounts[1], 0);
        assertEq(BOB.balance - balanceETHBefore, amounts[1]);
    }

    function test_GetAmountsOut() public {
        test_AddLiquidity();

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint[] memory amounts = router.getAmountsOut(10 ether, path);

        assertEq(amounts.length, 2);
        assertEq(amounts[0], 10 ether);
        assertGt(amounts[1], 0);
    }

    function test_GetAmountsIn() public {
        test_AddLiquidity();

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint[] memory amounts = router.getAmountsIn(10 ether, path);

        assertEq(amounts.length, 2);
        assertGt(amounts[0], 0);
        assertEq(amounts[1], 10 ether);
    }

    function test_FactoryAndWETH() public {
        assertEq(router.factory(), address(factory));
        assertEq(router.WETH(), address(weth));
    }

    function test_PairAddressCalculation() public {
        vm.prank(ALICE);
        tokenA.approve(address(router), LIQUIDITY_AMOUNT);
        vm.prank(ALICE);
        tokenB.approve(address(router), LIQUIDITY_AMOUNT);

        address expectedPair = factory.createPair(address(tokenA), address(tokenB));
        
        bytes32 actualInitCodeHash = keccak256(type(UniswapV2Pair).creationCode);
        address computedPair = computePairAddress(address(factory), address(tokenA), address(tokenB), actualInitCodeHash);

        emit log_named_address("expectedPair", expectedPair);
        emit log_named_address("computedPair", computedPair);
        emit log_named_bytes32("actualInitCodeHash", actualInitCodeHash);

        assertEq(expectedPair, computedPair, "Pair addresses should match");
    }

    function computePairAddress(address factory, address tokenA, address tokenB, bytes32 initCodeHash) public pure returns (address) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        return address(uint160(uint(keccak256(abi.encodePacked(hex'ff', factory, salt, initCodeHash)))));
    }
}

interface IERC20 {
    function balanceOf(address owner) external view returns (uint);
    function approve(address spender, uint value) external returns (bool);
}