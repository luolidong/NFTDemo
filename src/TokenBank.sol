// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IPermit2 {
    struct PermitTransferFrom {
        address permitted;
        address spender;
        uint256 amount;
        uint256 expiration;
        uint256 nonce;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}

/**
 * @title TokenBank
 * @dev 支持 EIP-2612 Permit 和 Permit2 功能的 TokenBank
 */
contract TokenBank is Ownable {
    IERC20 public immutable token;
    IPermit2 public permit2;

    mapping(address => uint256) public deposits;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed owner, uint256 amount);

    /**
     * @dev 构造函数
     * @param _tokenAddress 代币合约地址
     * @param _permit2Address Permit2合约地址
     */
    constructor(address _tokenAddress, address _permit2Address) Ownable(msg.sender) {
        require(_tokenAddress != address(0), "Token address cannot be zero");
        require(_permit2Address != address(0), "Permit2 address cannot be zero");
        token = IERC20(_tokenAddress);
        permit2 = IPermit2(_permit2Address);
    }

    /**
     * @dev 设置Permit2合约地址（仅限owner）
     * @param _permit2Address Permit2合约地址
     */
    function setPermit2(address _permit2Address) external onlyOwner {
        require(_permit2Address != address(0), "Permit2 address cannot be zero");
        permit2 = IPermit2(_permit2Address);
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
     * @dev 使用 Permit2 签名授权进行存款，无需先调用 approve
     * @param _permit Permit2 的 permit 结构体
     * @param _transferDetails 转账详情
     * @param _owner 代币所有者地址
     * @param _signature 用户签名
     */
    function depositWithPermit2(
        IPermit2.PermitTransferFrom calldata _permit,
        IPermit2.SignatureTransferDetails calldata _transferDetails,
        address _owner,
        bytes calldata _signature
    ) external {
        require(_permit.amount > 0, "Amount must be greater than 0");
        require(_permit.permitted == address(token), "Permit token mismatch");
        require(_permit.spender == address(this), "Spender must be TokenBank");

        permit2.permitTransferFrom(
            _permit,
            _transferDetails,
            _owner,
            _signature
        );

        deposits[_owner] += _transferDetails.requestedAmount;

        emit Deposit(_owner, _transferDetails.requestedAmount);
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