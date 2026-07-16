pragma solidity ^0.8.24;

import 'forge-std/Test.sol';
import '../UniswapV2Factory.sol';
import '../UniswapV2Pair.sol';
import '../interfaces/IUniswapV2Pair.sol';
import '../interfaces/IERC20.sol';
import '../libraries/UniswapV2Library.sol';
import '../examples/PoolATwapOracle.sol';
import './MyToken1.sol';
import './MyToken2.sol';

contract PoolATwapOracleTest is Test {
    MyToken1 public token1;
    MyToken2 public token2;
    UniswapV2Factory public factoryA;
    IUniswapV2Pair public poolA;
    PoolATwapOracle public oracle;

    uint constant TOKEN1_SUPPLY = 1000000 ether;
    uint constant TOKEN2_SUPPLY = 1000000 ether;
    uint constant PERIOD = 1 hours;

    function setUp() public {
        token1 = new MyToken1(TOKEN1_SUPPLY);
        token2 = new MyToken2(TOKEN2_SUPPLY);

        factoryA = new UniswapV2Factory(address(this));
        factoryA.createPair(address(token1), address(token2));
        poolA = IUniswapV2Pair(factoryA.getPair(address(token1), address(token2)));

        uint amountA1 = 1000 ether;
        uint amountA2 = 2000 ether;
        token1.transfer(address(poolA), amountA1);
        token2.transfer(address(poolA), amountA2);
        poolA.mint(address(this));

        oracle = new PoolATwapOracle(address(factoryA), address(token1), address(token2), PERIOD);
    }

    function testInitialState() public view {
        (uint reserve0, uint reserve1,) = poolA.getReserves();
        console2.log("Initial Pool A reserves:", reserve0, reserve1);
        console2.log("Token0:", poolA.token0());
        console2.log("Token1:", poolA.token1());

        address token0 = poolA.token0();
        uint priceMT1InMT2;
        if (token0 == address(token2)) {
            priceMT1InMT2 = reserve0 * 1 ether / reserve1;
        } else {
            priceMT1InMT2 = reserve1 * 1 ether / reserve0;
        }
        console2.log("Initial price: 1 MT1 =", priceMT1InMT2 / 1 ether, "MT2");
    }

    function testTwapWithMultipleTrades() public {
        console2.log("\n=== TWAP Oracle Test with Multiple Trades ===");

        address token0 = poolA.token0();
        address token1Addr = poolA.token1();
        bool token1IsToken0 = (token0 == address(token1));

        console2.log("\nInitial state:");
        (uint r0, uint r1,) = poolA.getReserves();
        console2.log("Reserves:", r0, r1);

        vm.warp(100);
        (uint price0Cumulative, uint price1Cumulative, uint32 timestamp) = oracle.getCurrentCumulativePrices();
        console2.log("\nTime:", timestamp);
        console2.log("Initial cumulative prices:", price0Cumulative, price1Cumulative);

        console2.log("\n--- Trade 1: Buy MT1 with MT2 (MT1 price increases) ---");
        _executeSwap(100 ether, address(token2), address(token1));
        (uint r0_1, uint r1_1,) = poolA.getReserves();
        console2.log("Reserves after Trade 1:", r0_1, r1_1);

        uint price1 = token1IsToken0 ? r0_1 * 1 ether / r1_1 : r1_1 * 1 ether / r0_1;
        console2.log("Price after Trade 1: 1 MT1 =", price1 / 1 ether, "MT2");

        vm.warp(100 + 1800);
        (price0Cumulative, price1Cumulative, timestamp) = oracle.getCurrentCumulativePrices();
        console2.log("\nTime:", timestamp);
        console2.log("Cumulative prices:", price0Cumulative, price1Cumulative);

        console2.log("\n--- Trade 2: Sell MT1 for MT2 (MT1 price decreases) ---");
        _executeSwap(50 ether, address(token1), address(token2));
        (uint r0_2, uint r1_2,) = poolA.getReserves();
        console2.log("Reserves after Trade 2:", r0_2, r1_2);

        uint price2 = token1IsToken0 ? r0_2 * 1 ether / r1_2 : r1_2 * 1 ether / r0_2;
        console2.log("Price after Trade 2: 1 MT1 =", price2 / 1 ether, "MT2");

        vm.warp(100 + 3600);
        (price0Cumulative, price1Cumulative, timestamp) = oracle.getCurrentCumulativePrices();
        console2.log("\nTime:", timestamp);
        console2.log("Cumulative prices:", price0Cumulative, price1Cumulative);

        console2.log("\n--- Trade 3: Buy MT1 with MT2 (MT1 price increases again) ---");
        _executeSwap(200 ether, address(token2), address(token1));
        (uint r0_3, uint r1_3,) = poolA.getReserves();
        console2.log("Reserves after Trade 3:", r0_3, r1_3);

        uint price3 = token1IsToken0 ? r0_3 * 1 ether / r1_3 : r1_3 * 1 ether / r0_3;
        console2.log("Price after Trade 3: 1 MT1 =", price3 / 1 ether, "MT2");

        vm.warp(100 + 5400);
        (price0Cumulative, price1Cumulative, timestamp) = oracle.getCurrentCumulativePrices();
        console2.log("\nTime:", timestamp);
        console2.log("Cumulative prices:", price0Cumulative, price1Cumulative);

        vm.warp(100 + 7200);

        console2.log("\n--- Update Oracle ---");
        oracle.update();

        uint twapPrice = oracle.consult(address(token1), 1 ether);
        console2.log("TWAP price: 1 MT1 =", twapPrice / 1 ether, "MT2");

        assertGt(twapPrice, 0, "TWAP price should be greater than 0");
    }

    function _executeSwap(uint amountIn, address tokenIn, address tokenOut) private {
        IERC20(tokenIn).transfer(address(poolA), amountIn);

        (uint reserve0, uint reserve1,) = poolA.getReserves();
        address token0 = poolA.token0();

        uint amountOut;
        if (tokenIn == token0) {
            amountOut = UniswapV2Library.getAmountOut(amountIn, reserve0, reserve1);
            poolA.swap(0, amountOut, address(this), "");
        } else {
            amountOut = UniswapV2Library.getAmountOut(amountIn, reserve1, reserve0);
            poolA.swap(amountOut, 0, address(this), "");
        }

        console2.log("Swapped", amountIn / 1 ether, tokenIn == address(token1) ? "MT1" : "MT2", 
            "for", amountOut / 1 ether, tokenOut == address(token1) ? "MT1" : "MT2");
    }

    function testTwapPriceCalculation() public {
        console2.log("\n=== TWAP Price Calculation Test ===");

        (uint initialR0, uint initialR1,) = poolA.getReserves();
        console2.log("Initial reserves:", initialR0, initialR1);

        vm.warp(0);
        poolA.sync();

        vm.warp(100);

        console2.log("\nTrade 1: Buy MT1");
        _executeSwap(100 ether, address(token2), address(token1));

        vm.warp(100 + 1800);

        console2.log("\nTrade 2: Sell MT1");
        _executeSwap(50 ether, address(token1), address(token2));

        vm.warp(100 + 3600);

        console2.log("\nTrade 3: Buy MT1");
        _executeSwap(150 ether, address(token2), address(token1));

        vm.warp(100 + 7200);

        oracle.update();

        uint twapPrice0 = oracle.consult(poolA.token0(), 1 ether);
        uint twapPrice1 = oracle.consult(poolA.token1(), 1 ether);

        console2.log("\nTWAP Results:");
        console2.log("1", poolA.token0() == address(token1) ? "MT1" : "MT2", "=", twapPrice0 / 1 ether, 
            poolA.token1() == address(token1) ? "MT1" : "MT2");
        console2.log("1", poolA.token1() == address(token1) ? "MT1" : "MT2", "=", twapPrice1 / 1 ether, 
            poolA.token0() == address(token1) ? "MT1" : "MT2");

        assertGt(twapPrice0, 0, "TWAP price0 should be > 0");
        assertGt(twapPrice1, 0, "TWAP price1 should be > 0");
    }

    function testUpdateRequiresPeriod() public {
        vm.warp(100);
        vm.expectRevert("PoolATwapOracle: PERIOD_NOT_ELAPSED");
        oracle.update();

        vm.warp(100 + 3600);
        oracle.update();
    }
}