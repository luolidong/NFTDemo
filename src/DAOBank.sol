// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DAOBank
 * @dev 由DAO治理合约管理的资金库合约
 * 
 * DAOBank作为去中心化自治组织(DAO)的资金管理合约，负责存储和管理组织的资产。
 * 只有DAOGov治理合约作为owner可以执行资金提取操作，确保所有资金操作都经过
 * 社区投票批准，保障资金安全。
 */
contract DAOBank is Ownable {
    /**
     * @dev ETH存款事件
     * @param user 存款用户地址
     * @param amount 存款金额(wei)
     */
    event Deposit(address indexed user, uint256 amount);

    /**
     * @dev ERC20代币存款事件
     * @param user 存款用户地址
     * @param token 代币合约地址
     * @param amount 存款金额(最小单位)
     */
    event DepositToken(address indexed user, address indexed token, uint256 amount);

    /**
     * @dev ETH提取事件
     * @param receiver 接收方地址
     * @param amount 提取金额(wei)
     */
    event Withdraw(address indexed receiver, uint256 amount);

    /**
     * @dev ERC20代币提取事件
     * @param receiver 接收方地址
     * @param token 代币合约地址
     * @param amount 提取金额(最小单位)
     */
    event WithdrawToken(address indexed receiver, address indexed token, uint256 amount);

    /**
     * @dev 构造函数
     * @param initialOwner 初始owner，应设置为DAOGov治理合约地址
     */
    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev 接收ETH存款的回退函数
     * 当用户直接向合约转账ETH时触发，自动记录存款事件
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev 存款ERC20代币到合约
     * 调用者需要先对合约授权足够的代币额度
     * @param token ERC20代币合约地址
     * @param amount 存款金额(最小单位)
     */
    function depositToken(address token, uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        emit DepositToken(msg.sender, token, amount);
    }

    /**
     * @dev 提取ETH到指定地址(仅owner可调用)
     * 必须通过DAOGov治理投票批准后才能执行
     * @param receiver ETH接收方地址
     * @param amount 提取金额(wei)
     */
    function withdraw(address receiver, uint256 amount) external onlyOwner {
        require(receiver != address(0), "Invalid receiver");
        require(amount > 0, "Amount must be greater than 0");
        require(address(this).balance >= amount, "Insufficient ETH balance");
        payable(receiver).transfer(amount);
        emit Withdraw(receiver, amount);
    }

    /**
     * @dev 提取ERC20代币到指定地址(仅owner可调用)
     * 必须通过DAOGov治理投票批准后才能执行
     * @param token ERC20代币合约地址
     * @param receiver 代币接收方地址
     * @param amount 提取金额(最小单位)
     */
    function withdrawToken(address token, address receiver, uint256 amount) external onlyOwner {
        require(receiver != address(0), "Invalid receiver");
        require(amount > 0, "Amount must be greater than 0");
        require(IERC20(token).transfer(receiver, amount), "Transfer failed");
        emit WithdrawToken(receiver, token, amount);
    }

    /**
     * @dev 查询合约ETH余额
     * @return 当前合约ETH余额(wei)
     */
    function getEthBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev 查询指定ERC20代币余额
     * @param token ERC20代币合约地址
     * @return 合约中该代币的余额(最小单位)
     */
    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}