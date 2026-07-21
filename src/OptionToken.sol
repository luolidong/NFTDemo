// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";

/**
 * @title OptionToken - ETH 看涨期权合约
 * @notice 实现基于 ERC20 标准的看涨期权，标的资产为 ETH，支付代币为 USDT
 * @dev 项目方存入 ETH 作为抵押品发行期权 Token，用户可在行权期内以行权价格购买 ETH
 * 
 * 核心机制：
 * - 项目方角色：发行期权（mint）、过期销毁（expire）
 * - 用户角色：在行权期内行权（exercise），以 USDT 换取 ETH
 * - 1:1 发行比例：存入 1 ETH = 获得 1 期权 Token
 * 
 * 时间窗口：
 * - exerciseDate：行权开始日期（时间戳）
 * - expiryDate：行权结束日期/过期日期（时间戳）
 * - 仅在 [exerciseDate, expiryDate] 期间可行权
 */
contract OptionToken is ERC20, Ownable, ReentrancyGuard {
    /**
     * @notice 行权价格（单位：USDT/ETH，18位小数）
     * @dev 例如：3000 * 10**18 表示行权价格为 3000 USDT/ETH
     */
    uint256 public immutable strikePrice;

    /**
     * @notice 行权开始日期（时间戳）
     * @dev 用户最早可在该日期当天开始行权
     */
    uint256 public immutable exerciseDate;

    /**
     * @notice 行权结束日期/过期日期（时间戳）
     * @dev 用户最晚可在该日期当天行权，过期后合约进入终止状态
     */
    uint256 public immutable expiryDate;

    /**
     * @notice 支付代币（USDT）接口
     * @dev 用户行权时需支付此代币
     */
    IERC20 public immutable paymentToken;

    /**
     * @notice 支付代币的小数位数
     * @dev 动态获取支付代币的小数位，兼容真实 USDT（6位小数）和测试 USDT（18位小数）
     */
    uint8 public immutable paymentTokenDecimals;

    /**
     * @notice 期权是否已过期终止
     * @dev 过期后：禁止发行新期权、禁止行权、禁止代币转账、项目方收回剩余 ETH
     */
    bool public isExpired;

    /**
     * @notice 期权发行事件
     * @param minter 发行者地址
     * @param ethAmount 存入的 ETH 数量
     * @param optionAmount 发行的期权 Token 数量
     */
    event OptionMinted(address indexed minter, uint256 ethAmount, uint256 optionAmount);

    /**
     * @notice 期权行权事件
     * @param exerciser 行权者地址
     * @param optionAmount 行权的期权 Token 数量
     * @param usdtAmount 支付的 USDT 数量
     * @param ethReceived 获得的 ETH 数量
     */
    event OptionExercised(address indexed exerciser, uint256 optionAmount, uint256 usdtAmount, uint256 ethReceived);

    /**
     * @notice 期权过期销毁事件
     * @param remainingOptions 过期时剩余的期权 Token 总量
     * @param ethReclaimed 项目方收回的 ETH 数量
     */
    event OptionExpired(uint256 remainingOptions, uint256 ethReclaimed);

    /**
     * @notice 构造函数 - 初始化期权合约参数
     * @param _strikePrice 行权价格（USDT/ETH，18位小数）
     * @param _exerciseDate 行权开始日期（时间戳）
     * @param _expiryDate 行权结束日期（时间戳）
     * @param _paymentToken 支付代币地址（USDT）
     * @param _name 期权 Token 名称
     * @param _symbol 期权 Token 符号
     */
    constructor(
        uint256 _strikePrice,
        uint256 _exerciseDate,
        uint256 _expiryDate,
        address _paymentToken,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        require(_strikePrice > 0, "Strike price must be positive");
        require(_exerciseDate > block.timestamp, "Exercise date must be in the future");
        require(_expiryDate > _exerciseDate, "Expiry date must be after exercise date");
        require(_paymentToken != address(0), "Payment token cannot be zero address");
        
        strikePrice = _strikePrice;
        exerciseDate = _exerciseDate;
        expiryDate = _expiryDate;
        paymentToken = IERC20(_paymentToken);
        paymentTokenDecimals = IERC20Metadata(_paymentToken).decimals();
        isExpired = false;
    }

    /**
     * @notice 发行期权 Token（项目方角色）
     * @dev 项目方存入 ETH 作为抵押品，按 1:1 比例发行期权 Token
     * @dev 仅合约 owner 可调用，且期权未过期
     */
    function mint() external payable onlyOwner nonReentrant {
        require(msg.value > 0, "Must deposit ETH");
        require(!isExpired, "Option has expired");
        
        _mint(msg.sender, msg.value);
        
        emit OptionMinted(msg.sender, msg.value, msg.value);
    }

    /**
     * @notice 行权（用户角色）
     * @dev 用户在行权期内以行权价格支付 USDT，换取 ETH，并销毁期权 Token
     * @param _amount 行权的期权 Token 数量（即换取的 ETH 数量）
     */
    function exercise(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be positive");
        require(!isExpired, "Option has expired");
        require(block.timestamp >= exerciseDate, "Exercise date not reached");
        require(block.timestamp <= expiryDate, "Exercise period ended");
        
        /**
         * 计算所需 USDT 数量：
         * usdtAmount = amount * strikePrice / 10**18 （转换为 18 位小数的 USDT）
         * usdtAmount = usdtAmount * 10**paymentTokenDecimals / 10**18 （适配支付代币的实际小数位）
         */
        uint256 usdtAmount = _amount * strikePrice / 10**18;
        usdtAmount = usdtAmount * 10**paymentTokenDecimals / 10**18;
        
        require(balanceOf(msg.sender) >= _amount, "Insufficient option balance");
        require(paymentToken.balanceOf(msg.sender) >= usdtAmount, "Insufficient USDT");
        require(paymentToken.allowance(msg.sender, address(this)) >= usdtAmount, "USDT allowance insufficient");
        
        _burn(msg.sender, _amount);
        
        paymentToken.transferFrom(msg.sender, owner(), usdtAmount);
        
        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success, "ETH transfer failed");
        
        emit OptionExercised(msg.sender, _amount, usdtAmount, _amount);
    }

    /**
     * @notice 过期销毁（项目方角色）
     * @dev 期权过期后，项目方调用此函数终止合约：
     * 1. 销毁项目方持有的剩余期权 Token
     * 2. 项目方收回合约中剩余的 ETH
     * 3. 冻结所有期权 Token 的转账功能
     * @dev 仅合约 owner 可调用，且必须在 expiryDate 之后
     */
    function expire() external onlyOwner nonReentrant {
        require(!isExpired, "Option already expired");
        require(block.timestamp > expiryDate, "Expiry date not passed");
        
        isExpired = true;
        
        uint256 ownerBalance = balanceOf(owner());
        if (ownerBalance > 0) {
            _burn(owner(), ownerBalance);
        }
        
        uint256 remainingOptions = totalSupply();
        uint256 ethBalance = address(this).balance;
        
        (bool success, ) = owner().call{value: ethBalance}("");
        require(success, "ETH transfer to owner failed");
        
        emit OptionExpired(remainingOptions, ethBalance);
    }

    /**
     * @notice 重写 ERC20 的 _update 方法
     * @dev 期权过期后禁止普通转账（mint 和 burn 仍允许）
     * @param from 转账来源地址
     * @param to 转账目标地址
     * @param value 转账金额
     */
    function _update(address from, address to, uint256 value) internal virtual override {
        if (isExpired && from != address(0) && to != address(0)) {
            revert("Transfers disabled after expiry");
        }
        super._update(from, to, value);
    }

    /**
     * @notice 获取合约中的 ETH 余额
     * @return 合约当前持有的 ETH 数量
     */
    function getEthBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice 接收 ETH 函数
     * @dev 允许合约接收 ETH（用于 mint 时的存款）
     */
    receive() external payable {}
}