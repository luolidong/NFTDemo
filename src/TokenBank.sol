// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenBank
 * @dev 支持 EIP-2612 Permit 功能的 TokenBank
 */
contract TokenBank is Ownable {
    IERC20 public immutable token;

    mapping(address => uint256) public deposits;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed owner, uint256 amount);

    /**
     * @dev 构造函数
     * @param _tokenAddress 代币合约地址
     */
    constructor(address _tokenAddress) Ownable(msg.sender) {
        require(_tokenAddress != address(0), "Token address cannot be zero");
        token = IERC20(_tokenAddress);
    }

    /**
     * @dev 存款功能
     * @param _amount 存款金额
     */
    function deposit(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");

        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        deposits[msg.sender] += _amount;

        emit Deposit(msg.sender, _amount);
    }

    /**
     * @dev 使用 permit 签名授权进行存款，无需先调用 approve
     * @param _amount 存款金额
     * @param _deadline 签名截止时间戳
     * @param _v ECDSA 签名参数 v
     * @param _r ECDSA 签名参数 r
     * @param _s ECDSA 签名参数 s
     */
    function permitDeposit(
        uint256 _amount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        require(_amount > 0, "Amount must be greater than 0");

        // 调用 token 的 permit 函数进行授权
        IERC20Permit(address(token)).permit(
            msg.sender,
            address(this),
            _amount,
            _deadline,
            _v,
            _r,
            _s
        );

        // 执行转账
        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        // 更新存款记录
        deposits[msg.sender] += _amount;

        emit Deposit(msg.sender, _amount);
    }

    /**
     * @dev 提款功能，仅限所有者
     */
    function withdraw() external onlyOwner {
        uint256 totalBalance = token.balanceOf(address(this));
        require(totalBalance > 0, "No tokens to withdraw");

        require(token.transfer(owner(), totalBalance), "Transfer failed");

        emit Withdraw(owner(), totalBalance);
    }

    /**
     * @dev 获取合约持有的代币余额
     * @return 代币余额
     */
    function getBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @dev 获取用户的存款余额
     * @param _user 用户地址
     * @return 存款余额
     */
    function getUserDeposit(address _user) external view returns (uint256) {
        return deposits[_user];
    }
}