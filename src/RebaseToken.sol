// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title RebaseToken - 通缩型ERC20代币
 * @notice 实现每年自动通缩1%的ERC20代币
 * @dev 采用全局缩放因子(Scaling Factor)模式，避免遍历所有持有者
 *
 * 核心机制：
 * - 内部存储scaledBalances（不会变化）
 * - balanceOf()返回 scaledBalances * scalingFactor / 1e18（反映通缩后的余额）
 * - 每年调用rebase()将scalingFactor乘以99/100，实现1%通缩
 *
 * 示例：
 * - 初始：scalingFactor = 1e18，余额100 = 100
 * - 1年后：scalingFactor = 0.99e18，余额100 * 0.99 = 99
 * - 2年后：scalingFactor = 0.9801e18，余额100 * 0.9801 = 98.01
 */
contract RebaseToken {
    // ============ ERC20标准属性 ============
    string public name;
    string public symbol;
    uint8 public decimals;

    // ============ 通缩参数常量 ============
    /// @notice 初始发行量：10,000,000 枚
    uint256 public constant INITIAL_SUPPLY = 10000000 * 10**18;

    /// @notice 缩放因子基数，用于精度计算
    uint256 public constant SCALING_FACTOR_BASE = 1e18;

    /// @notice 通缩间隔：365天（1年）
    uint256 public constant REBASE_INTERVAL = 365 days;

    /// @notice 通缩率分子：99（保留99%）
    uint256 public constant REBASE_RATE_NUMERATOR = 99;

    /// @notice 通缩率分母：100
    uint256 public constant REBASE_RATE_DENOMINATOR = 100;

    // ============ 核心状态变量 ============
    /// @notice 当前缩放因子，初始为1e18（1:1），每年乘以99/100
    uint256 public scalingFactor;

    /// @notice 上次通缩时间戳
    uint256 public lastRebaseTime;

    /// @notice 缩放后的总供应量（内部存储，不变）
    uint256 public scaledTotalSupply;

    /// @notice 缩放后的账户余额映射（内部存储，不变）
    mapping(address => uint256) public scaledBalances;

    /// @notice 授权额度映射
    mapping(address => mapping(address => uint256)) public allowance;

    // ============ 事件定义 ============
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Rebase(uint256 oldScalingFactor, uint256 newScalingFactor, uint256 newTotalSupply);

    // ============ 构造函数 ============
    /**
     * @notice 初始化代币，将初始发行量分配给部署者
     */
    constructor() {
        name = "RebaseToken";
        symbol = "RBT";
        decimals = 18;
        scalingFactor = SCALING_FACTOR_BASE; // 初始1:1
        lastRebaseTime = block.timestamp;
        scaledTotalSupply = INITIAL_SUPPLY;
        scaledBalances[msg.sender] = INITIAL_SUPPLY;
        emit Transfer(address(0), msg.sender, INITIAL_SUPPLY);
    }

    // ============ ERC20标准方法 ============

    /**
     * @notice 获取通缩后的总供应量
     * @return 当前实际总供应量 = scaledTotalSupply * scalingFactor / 1e18
     * @dev 随着scalingFactor降低，总供应量逐年减少
     */
    function totalSupply() external view returns (uint256) {
        return scaledTotalSupply * scalingFactor / SCALING_FACTOR_BASE;
    }

    /**
     * @notice 获取账户通缩后的余额
     * @param account 要查询的地址
     * @return 实际余额 = scaledBalances[account] * scalingFactor / 1e18
     * @dev 随着scalingFactor降低，余额逐年按比例减少
     */
    function balanceOf(address account) external view returns (uint256) {
        return scaledBalances[account] * scalingFactor / SCALING_FACTOR_BASE;
    }

    /**
     * @notice 转账代币
     * @param to 接收地址
     * @param value 转账金额（真实金额）
     * @return 成功返回true
     * @dev 需要将真实金额转换为scaled金额后再操作内部存储
     */
    function transfer(address to, uint256 value) external returns (bool) {
        // 将真实金额转换为scaled金额
        uint256 scaledValue = value * SCALING_FACTOR_BASE / scalingFactor;
        require(scaledBalances[msg.sender] >= scaledValue, "Insufficient balance");

        scaledBalances[msg.sender] -= scaledValue;
        scaledBalances[to] += scaledValue;

        emit Transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @notice 授权额度
     * @param spender 被授权地址
     * @param value 授权金额
     * @return 成功返回true
     */
    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @notice 授权转账
     * @param from 发送地址
     * @param to 接收地址
     * @param value 转账金额（真实金额）
     * @return 成功返回true
     * @dev 需要将真实金额转换为scaled金额后再操作内部存储
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        // 将真实金额转换为scaled金额
        uint256 scaledValue = value * SCALING_FACTOR_BASE / scalingFactor;
        require(scaledBalances[from] >= scaledValue, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Allowance exceeded");

        scaledBalances[from] -= scaledValue;
        scaledBalances[to] += scaledValue;
        allowance[from][msg.sender] -= value;

        emit Transfer(from, to, value);
        return true;
    }

    // ============ 通缩核心方法 ============

    /**
     * @notice 执行年度通缩
     * @dev 任何人都可以调用，但必须等待365天间隔
     * 效果：scalingFactor = scalingFactor * 99 / 100
     * 所有持有者的余额自动减少1%
     */
    function rebase() external {
        require(block.timestamp >= lastRebaseTime + REBASE_INTERVAL, "Rebase interval not elapsed");

        uint256 oldScalingFactor = scalingFactor;
        // 通缩1%：乘以99/100
        scalingFactor = scalingFactor * REBASE_RATE_NUMERATOR / REBASE_RATE_DENOMINATOR;
        lastRebaseTime = block.timestamp;

        uint256 newTotalSupply = scaledTotalSupply * scalingFactor / SCALING_FACTOR_BASE;
        emit Rebase(oldScalingFactor, scalingFactor, newTotalSupply);
    }

    // ============ 辅助方法 ============

    /**
     * @notice 获取账户的原始scaled余额（内部存储值）
     * @param account 要查询的地址
     * @return scaled余额（不受通缩影响）
     */
    function getScaledBalance(address account) external view returns (uint256) {
        return scaledBalances[account];
    }
}