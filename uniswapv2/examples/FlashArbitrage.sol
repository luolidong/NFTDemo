pragma solidity ^0.8.24;

import '../interfaces/IUniswapV2Callee.sol';
import '../interfaces/IUniswapV2Pair.sol';
import '../interfaces/IERC20.sol';
import '../libraries/UniswapV2Library.sol';

contract FlashArbitrage is IUniswapV2Callee {
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external override {
        (address exchangePool, address token0, address token1, address profitReceiver) = abi.decode(data, (address, address, address, address));
        address borrowPool = msg.sender;

        uint amountBorrowed = amount0 > 0 ? amount0 : amount1;
        address tokenBorrowed = amount0 > 0 ? token0 : token1;
        address tokenToRepay = tokenBorrowed == token0 ? token1 : token0;

        IERC20(tokenBorrowed).transfer(exchangePool, amountBorrowed);

        (uint reserve0Exchange, uint reserve1Exchange,) = IUniswapV2Pair(exchangePool).getReserves();
        
        uint amountOut;
        if (tokenBorrowed == token0) {
            amountOut = UniswapV2Library.getAmountOut(amountBorrowed, reserve0Exchange, reserve1Exchange);
            IUniswapV2Pair(exchangePool).swap(0, amountOut, address(this), '');
        } else {
            amountOut = UniswapV2Library.getAmountOut(amountBorrowed, reserve1Exchange, reserve0Exchange);
            IUniswapV2Pair(exchangePool).swap(amountOut, 0, address(this), '');
        }

        (uint reserve0Borrow, uint reserve1Borrow,) = IUniswapV2Pair(borrowPool).getReserves();
        
        uint amountToRepay;
        if (tokenBorrowed == token0) {
            amountToRepay = UniswapV2Library.getAmountIn(amountBorrowed, reserve1Borrow, reserve0Borrow);
            IERC20(tokenToRepay).transfer(borrowPool, amountToRepay);
        } else {
            amountToRepay = UniswapV2Library.getAmountIn(amountBorrowed, reserve0Borrow, reserve1Borrow);
            IERC20(tokenToRepay).transfer(borrowPool, amountToRepay);
        }

        uint finalBalance0 = IERC20(token0).balanceOf(address(this));
        uint finalBalance1 = IERC20(token1).balanceOf(address(this));
        
        if (finalBalance0 > 0) IERC20(token0).transfer(profitReceiver, finalBalance0);
        if (finalBalance1 > 0) IERC20(token1).transfer(profitReceiver, finalBalance1);
    }

    function executeArbitrage(address borrowPool, address exchangePool, uint amountBorrow) external {
        address token0 = IUniswapV2Pair(borrowPool).token0();
        address token1 = IUniswapV2Pair(borrowPool).token1();

        bytes memory data = abi.encode(exchangePool, token0, token1, msg.sender);
        IUniswapV2Pair(borrowPool).swap(amountBorrow, 0, address(this), data);
    }

    function executeArbitrageAlt(address borrowPool, address exchangePool, uint amountBorrow) external {
        address token0 = IUniswapV2Pair(borrowPool).token0();
        address token1 = IUniswapV2Pair(borrowPool).token1();

        bytes memory data = abi.encode(exchangePool, token0, token1, msg.sender);
        IUniswapV2Pair(borrowPool).swap(0, amountBorrow, address(this), data);
    }
}