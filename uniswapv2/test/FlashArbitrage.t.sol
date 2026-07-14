pragma solidity ^0.8.24;

import 'forge-std/Test.sol';
import '../UniswapV2Factory.sol';
import '../UniswapV2Pair.sol';
import '../interfaces/IUniswapV2Pair.sol';
import '../interfaces/IERC20.sol';
import '../libraries/UniswapV2Library.sol';
import '../examples/FlashArbitrage.sol';
import './MyToken1.sol';
import './MyToken2.sol';

contract FlashArbitrageTest is Test {
    MyToken1 public token1;
    MyToken2 public token2;
    UniswapV2Factory public factoryA;
    UniswapV2Factory public factoryB;
    IUniswapV2Pair public poolA;
    IUniswapV2Pair public poolB;
    FlashArbitrage public arbitrage;

    uint constant TOKEN1_SUPPLY = 1000000 ether;
    uint constant TOKEN2_SUPPLY = 1000000 ether;

    function setUp() public {
        token1 = new MyToken1(TOKEN1_SUPPLY);
        token2 = new MyToken2(TOKEN2_SUPPLY);

        factoryA = new UniswapV2Factory(address(this));
        factoryB = new UniswapV2Factory(address(this));

        factoryA.createPair(address(token1), address(token2));
        factoryB.createPair(address(token1), address(token2));

        poolA = IUniswapV2Pair(factoryA.getPair(address(token1), address(token2)));
        poolB = IUniswapV2Pair(factoryB.getPair(address(token1), address(token2)));

        arbitrage = new FlashArbitrage();

        // Pool A: 1 MyToken1 = 2 MyToken2 (MT1 is more expensive)
        uint amountA1 = 1000 ether;
        uint amountA2 = 2000 ether;
        token1.transfer(address(poolA), amountA1);
        token2.transfer(address(poolA), amountA2);
        poolA.mint(address(this));

        // Pool B: 1 MyToken1 = 1 MyToken2 (MT1 is cheaper)
        uint amountB1 = 1000 ether;
        uint amountB2 = 1000 ether;
        token1.transfer(address(poolB), amountB1);
        token2.transfer(address(poolB), amountB2);
        poolB.mint(address(this));
    }

    function testPoolPrices() public view {
        (uint reserve0A, uint reserve1A,) = poolA.getReserves();
        (uint reserve0B, uint reserve1B,) = poolB.getReserves();

        address token0 = poolA.token0();

        console2.log("Pool A token0:", token0);
        console2.log("Pool A token1:", poolA.token1());
        console2.log("Token1 address:", address(token1));
        console2.log("Token2 address:", address(token2));

        console2.log("\nPool A reserves (token0/token1):", reserve0A, reserve1A);
        console2.log("Pool B reserves (token0/token1):", reserve0B, reserve1B);

        uint priceMT1InMT2_PoolA;
        uint priceMT1InMT2_PoolB;

        if (token0 == address(token2)) {
            priceMT1InMT2_PoolA = reserve0A * 1 ether / reserve1A;
            priceMT1InMT2_PoolB = reserve0B * 1 ether / reserve1B;
        } else {
            priceMT1InMT2_PoolA = reserve1A * 1 ether / reserve0A;
            priceMT1InMT2_PoolB = reserve1B * 1 ether / reserve0B;
        }

        console2.log("\nPool A: 1 MT1 =", priceMT1InMT2_PoolA / 1 ether, "MT2");
        console2.log("Pool B: 1 MT1 =", priceMT1InMT2_PoolB / 1 ether, "MT2");
    }

    function testArbitrage() public {
        uint initialBalance1 = token1.balanceOf(address(this));
        uint initialBalance2 = token2.balanceOf(address(this));

        console2.log("\nBefore arbitrage:");
        console2.log("MyToken1 balance:", initialBalance1);
        console2.log("MyToken2 balance:", initialBalance2);

        // Borrow MT1 from Pool B (lower price) and sell in Pool A (higher price)
        // Since MT1 is token1, use executeArbitrageAlt to borrow token1
        uint amountBorrow = 100 ether;
        arbitrage.executeArbitrageAlt(address(poolB), address(poolA), amountBorrow);

        uint finalBalance1 = token1.balanceOf(address(this));
        uint finalBalance2 = token2.balanceOf(address(this));

        console2.log("\nAfter arbitrage:");
        console2.log("MyToken1 balance:", finalBalance1);
        console2.log("MyToken2 balance:", finalBalance2);

        uint profit1 = finalBalance1 > initialBalance1 ? finalBalance1 - initialBalance1 : 0;
        uint profit2 = finalBalance2 > initialBalance2 ? finalBalance2 - initialBalance2 : 0;

        console2.log("\nProfit:");
        console2.log("MyToken1 profit:", profit1);
        console2.log("MyToken2 profit:", profit2);

        assertTrue(profit1 > 0 || profit2 > 0, "Arbitrage should generate profit");
    }

    function testArbitrageFullFlow() public {
        uint amountBorrow = 100 ether;
        
        (uint r0A, uint r1A,) = poolA.getReserves();
        (uint r0B, uint r1B,) = poolB.getReserves();
        
        console2.log("Initial Pool A reserves:", r0A, r1A);
        console2.log("Initial Pool B reserves:", r0B, r1B);

        arbitrage.executeArbitrageAlt(address(poolB), address(poolA), amountBorrow);

        (uint finalR0A, uint finalR1A,) = poolA.getReserves();
        (uint finalR0B, uint finalR1B,) = poolB.getReserves();

        console2.log("Final Pool A reserves:", finalR0A, finalR1A);
        console2.log("Final Pool B reserves:", finalR0B, finalR1B);
    }
}