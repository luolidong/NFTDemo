pragma solidity ^0.8.24;

// 导入Uniswap V2 Factory接口，用于获取流动性池地址
import '../interfaces/IUniswapV2Factory.sol';
// 导入Uniswap V2 Pair接口，用于调用池的方法（getReserves、price0CumulativeLast等）
import '../interfaces/IUniswapV2Pair.sol';

// 导入Uniswap V2 Oracle库，提供累积价格计算的核心逻辑
import '../libraries/UniswapV2OracleLibrary.sol';
// 导入Uniswap V2核心库，提供pairFor等工具函数
import '../libraries/UniswapV2Library.sol';

// PoolATwapOracle合约：基于Uniswap V2的时间加权平均价格(TWAP)预言机
// TWAP原理：通过累积价格(priceCumulative)除以时间间隔得到平均价格
contract PoolATwapOracle {
    // 使用FixedPoint库进行定点数运算，处理价格计算中的精度问题
    using FixedPoint for *;

    // TWAP计算的时间周期（秒），构造时传入，不可更改
    // 例如：3600表示1小时周期，必须等待至少1小时才能更新TWAP
    uint public immutable period;

    // 目标流动性池的接口引用，不可更改
    IUniswapV2Pair immutable pair;
    // 池中的token0地址（按地址大小排序，小地址为token0），不可更改
    address public immutable token0;
    // 池中的token1地址，不可更改
    address public immutable token1;

    // 上一次记录的token0累积价格（price0Cumulative = price * time）
    // 每次update时更新，用于计算时间间隔内的累积价格变化
    uint    public price0CumulativeLast;
    // 上一次记录的token1累积价格
    uint    public price1CumulativeLast;
    // 上一次记录的区块时间戳（uint32范围足够，约136年）
    uint32  public blockTimestampLast;
    // token0对token1的TWAP平均价格（uq112x112定点数格式）
    // 表示1单位token0能兑换多少token1
    FixedPoint.uq112x112 public price0Average;
    // token1对token0的TWAP平均价格
    // 表示1单位token1能兑换多少token0
    FixedPoint.uq112x112 public price1Average;

    // 构造函数：初始化预言机
    // 参数：
    //   factory - Uniswap V2 Factory合约地址
    //   tokenA/tokenB - 交易对的两个代币地址（顺序无关）
    //   _period - TWAP计算周期（秒）
    constructor(address factory, address tokenA, address tokenB, uint _period) public {
        // 通过UniswapV2Library.pairFor计算流动性池地址
        // pairFor会自动按地址大小排序tokenA和tokenB，确保地址唯一性
        IUniswapV2Pair _pair = IUniswapV2Pair(UniswapV2Library.pairFor(factory, tokenA, tokenB));
        pair = _pair;
        
        // 获取池中的token0和token1地址（已按地址大小排序）
        token0 = _pair.token0();
        token1 = _pair.token1();
        
        // 设置TWAP计算周期
        period = _period;

        // 记录当前池的累积价格，作为TWAP计算的起点
        // price0CumulativeLast表示从池创建到现在，价格*时间的累积值
        price0CumulativeLast = _pair.price0CumulativeLast();
        price1CumulativeLast = _pair.price1CumulativeLast();

        // 获取当前池的储备金和时间戳
        // reserve0/reserve1是池中的token0/token1数量
        // blockTimestampLast记录当前时间，用于后续计算时间间隔
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1, blockTimestampLast) = _pair.getReserves();
        
        // 验证池中有流动性，否则无法计算价格
        require(reserve0 != 0 && reserve1 != 0, 'PoolATwapOracle: NO_RESERVES');
    }

    // update函数：更新TWAP价格
    // 注意：必须等待至少一个period周期后才能调用
    function update() external {
        // 调用Oracle库获取当前的累积价格和时间戳
        // currentCumulativePrices会自动计算自上次更新以来的累积价格增量
        // 即使期间没有交易，也会基于当前储备金计算"假设的"累积价格
        (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) =
            UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
        
        // 计算自上次更新以来经过的时间（秒）
        // 注意：这里允许溢出（unchecked减法），因为时间戳是单调递增的
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;

        // 验证时间间隔是否达到一个周期
        // 这确保TWAP是基于至少一个完整周期计算的，避免短时间波动影响
        require(timeElapsed >= period, 'PoolATwapOracle: PERIOD_NOT_ELAPSED');

        // 计算TWAP平均价格：
        // (当前累积价格 - 上次累积价格) / 时间间隔 = 平均价格
        // 使用FixedPoint.uq112x112包装结果，保留112位精度
        // price0Average表示token0对token1的平均价格
        price0Average = FixedPoint.uq112x112(uint224((price0Cumulative - price0CumulativeLast) / timeElapsed));
        // price1Average表示token1对token0的平均价格
        price1Average = FixedPoint.uq112x112(uint224((price1Cumulative - price1CumulativeLast) / timeElapsed));

        // 更新状态变量，为下次更新做准备
        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;
    }

    // consult函数：查询基于TWAP的兑换数量
    // 参数：
    //   token - 输入代币地址（必须是token0或token1）
    //   amountIn - 输入代币数量
    // 返回：根据TWAP价格计算的输出代币数量
    function consult(address token, uint amountIn) external view returns (uint amountOut) {
        if (token == token0) {
            // 如果输入是token0，使用price0Average计算输出token1的数量
            // price0Average.mul(amountIn) = amountIn * (token1/token0)
            // decode144将定点数转换为uint256
            amountOut = price0Average.mul(amountIn).decode144();
        } else {
            // 验证输入代币是否为token1
            require(token == token1, 'PoolATwapOracle: INVALID_TOKEN');
            // 如果输入是token1，使用price1Average计算输出token0的数量
            amountOut = price1Average.mul(amountIn).decode144();
        }
    }

    // getCurrentCumulativePrices函数：获取当前累积价格（调试用）
    // 返回当前的累积价格和时间戳，用于验证TWAP计算过程
    function getCurrentCumulativePrices() external view returns (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) {
        return UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
    }
}