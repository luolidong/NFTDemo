pragma solidity ^0.8.24;

/**
 * @title StakingPool 质押挖矿合约（单池 + 价格折算）
 * @dev 支持 ETH 和多种 ERC20 质押，通过 Chainlink 价格预言机将所有资产折算成 USD 价值
 * 奖励按 USD 价值比例分配，解决价值不对等问题
 *
 * 核心机制：
 *   1. 用户可质押 ETH 或任意已注册的 ERC20 代币
 *   2. 每种资产通过 Chainlink 预言机获取实时 USD 价格
 *   3. 奖励按 USD 价值比例分配，而非按数量比例
 *   4. KK Token 通过铸造发放
 *
 * 数学模型：
 *   accRewardPerShare = 累计每 USD 价值应得的奖励（乘以 1e12 精度）
 *   用户总价值 = Σ(资产数量 × 资产价格)
 *   用户待领取奖励 = 用户总价值 × accRewardPerShare / 1e12 - rewardDebt
 */
import '../interfaces/IERC20.sol';
import '../libraries/SafeMath.sol';
import '../libraries/TransferHelper.sol';
import './KKToken.sol';
import '../../lib/openzeppelin-contracts/contracts/access/Ownable.sol';
import '../../lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol';

contract StakingPool is Ownable {
    using SafeMath for uint256;

    // ============ 奖励代币 ============

    KKToken public immutable rewardToken;

    // ============ 奖励参数 ============

    uint256 public rewardPerBlock;
    uint256 public accRewardPerShare;
    uint256 public lastRewardBlock;

    /// @notice 当前所有用户的总 USD 价值
    uint256 public totalStakedValue;

    // ============ 价格预言机配置 ============

    /// @notice ETH 的价格预言机（ETH/USD）
    AggregatorV3Interface public ethPriceFeed;

    /// @notice ERC20 代币地址 => 价格预言机（Token/USD）
    mapping(address => AggregatorV3Interface) public tokenPriceFeeds;

    /// @notice 已注册的质押代币列表
    address[] public registeredTokens;

    /// @notice 是否已注册某代币
    mapping(address => bool) public isTokenRegistered;

    // ============ 用户信息 ============

    /// @notice 用户质押信息
    struct UserInfo {
        uint256 ethAmount;
        mapping(address => uint256) erc20Amounts;
        uint256 rewardDebt;
    }

    mapping(address => UserInfo) public userInfo;

    // ============ 事件 ============

    event StakedETH(address indexed user, uint256 amount, uint256 usdValue);
    event StakedERC20(address indexed user, address indexed token, uint256 amount, uint256 usdValue);
    event WithdrawnETH(address indexed user, uint256 amount);
    event WithdrawnERC20(address indexed user, address indexed token, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event TokenRegistered(address indexed token, address indexed priceFeed);
    event RewardPerBlockUpdated(uint256 oldReward, uint256 newReward);

    // ============ 构造函数 ============

    constructor(
        uint256 _rewardPerBlock,
        AggregatorV3Interface _ethPriceFeed
    ) Ownable(msg.sender) {
        rewardToken = new KKToken();
        rewardPerBlock = _rewardPerBlock;
        lastRewardBlock = block.number;
        ethPriceFeed = _ethPriceFeed;
    }

    // ============ 核心逻辑：价格获取 ============

    /**
     * @notice 获取 ETH 的 USD 价格
     * @return ETH 的 USD 价格（精度 1e8）
     */
    function getETHPrice() public view returns (uint256) {
        (, int256 price, , , ) = ethPriceFeed.latestRoundData();
        require(price > 0, 'ETH price feed returned invalid value');
        return uint256(price);
    }

    /**
     * @notice 获取 ERC20 代币的 USD 价格
     * @param token 代币地址
     * @return 代币的 USD 价格（精度取决于预言机）
     */
    function getTokenPrice(address token) public view returns (uint256) {
        AggregatorV3Interface priceFeed = tokenPriceFeeds[token];
        require(address(priceFeed) != address(0), 'Token not registered');
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, 'Token price feed returned invalid value');
        return uint256(price);
    }

    /**
     * @notice 计算 ETH 数量对应的 USD 价值
     * @param amount ETH 数量（wei）
     * @return USD 价值（单位：分，精度 1e10）
     */
    function calculateETHValue(uint256 amount) public view returns (uint256) {
        uint256 price = getETHPrice();
        return amount.mul(price).div(1e10);
    }

    /**
     * @notice 计算 ERC20 数量对应的 USD 价值
     * @param token 代币地址
     * @param amount 代币数量
     * @return USD 价值（单位：分，精度 1e10）
     */
    function calculateTokenValue(address token, uint256 amount) public view returns (uint256) {
        uint256 price = getTokenPrice(token);
        AggregatorV3Interface priceFeed = tokenPriceFeeds[token];
        uint8 decimals = priceFeed.decimals();

        uint256 adjustedPrice;
        if (decimals == 8) {
            adjustedPrice = price;
        } else if (decimals > 8) {
            adjustedPrice = price.div(10 ** (decimals - 8));
        } else {
            adjustedPrice = price.mul(10 ** (8 - decimals));
        }

        return amount.mul(adjustedPrice).div(1e10);
    }

    // ============ 核心逻辑：更新奖励池 ============

    /**
     * @notice 返回用户当前总 USD 价值（ETH + 所有 ERC20）
     * @param user 用户地址
     */
    function getUserTotalValue(address user) public view returns (uint256) {
        UserInfo storage info = userInfo[user];
        uint256 totalValue = calculateETHValue(info.ethAmount);

        for (uint256 i = 0; i < registeredTokens.length; i++) {
            address token = registeredTokens[i];
            totalValue = totalValue.add(calculateTokenValue(token, info.erc20Amounts[token]));
        }

        return totalValue;
    }

    /**
     * @notice 更新全局奖励状态
     * @dev accRewardPerShare 基于总 USD 价值计算
     */
    function updateReward() public {
        if (block.number <= lastRewardBlock) return;

        uint256 blocks = block.number.sub(lastRewardBlock);
        uint256 reward = blocks.mul(rewardPerBlock);

        if (reward > 0 && totalStakedValue > 0) {
            accRewardPerShare = accRewardPerShare.add(reward.mul(1e12).div(totalStakedValue));
        }
        lastRewardBlock = block.number;
    }

    // ============ 用户操作：ETH 质押 ============

    function depositETH() public payable {
        require(msg.value > 0, 'Amount must be greater than 0');

        UserInfo storage user = userInfo[msg.sender];
        updateReward();

        _claimPendingReward(user);

        uint256 usdValue = calculateETHValue(msg.value);
        user.ethAmount = user.ethAmount.add(msg.value);
        totalStakedValue = totalStakedValue.add(usdValue);
        user.rewardDebt = getUserTotalValue(msg.sender).mul(accRewardPerShare).div(1e12);

        emit StakedETH(msg.sender, msg.value, usdValue);
    }

    function withdrawETH(uint256 amount) public {
        require(amount > 0, 'Amount must be greater than 0');

        UserInfo storage user = userInfo[msg.sender];
        require(user.ethAmount >= amount, 'Insufficient staked ETH');

        updateReward();

        _claimPendingReward(user);

        uint256 usdValue = calculateETHValue(amount);
        user.ethAmount = user.ethAmount.sub(amount);
        totalStakedValue = totalStakedValue.sub(usdValue);
        user.rewardDebt = getUserTotalValue(msg.sender).mul(accRewardPerShare).div(1e12);

        payable(msg.sender).transfer(amount);

        emit WithdrawnETH(msg.sender, amount);
    }

    // ============ 用户操作：ERC20 质押 ============

    function depositERC20(address token, uint256 amount) public {
        require(isTokenRegistered[token], 'Token not registered');
        require(amount > 0, 'Amount must be greater than 0');

        UserInfo storage user = userInfo[msg.sender];
        updateReward();

        _claimPendingReward(user);

        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amount);

        uint256 usdValue = calculateTokenValue(token, amount);
        user.erc20Amounts[token] = user.erc20Amounts[token].add(amount);
        totalStakedValue = totalStakedValue.add(usdValue);
        user.rewardDebt = getUserTotalValue(msg.sender).mul(accRewardPerShare).div(1e12);

        emit StakedERC20(msg.sender, token, amount, usdValue);
    }

    function withdrawERC20(address token, uint256 amount) public {
        require(isTokenRegistered[token], 'Token not registered');
        require(amount > 0, 'Amount must be greater than 0');

        UserInfo storage user = userInfo[msg.sender];
        require(user.erc20Amounts[token] >= amount, 'Insufficient staked ERC20');

        updateReward();

        _claimPendingReward(user);

        uint256 usdValue = calculateTokenValue(token, amount);
        user.erc20Amounts[token] = user.erc20Amounts[token].sub(amount);
        totalStakedValue = totalStakedValue.sub(usdValue);
        user.rewardDebt = getUserTotalValue(msg.sender).mul(accRewardPerShare).div(1e12);

        TransferHelper.safeTransfer(token, msg.sender, amount);

        emit WithdrawnERC20(msg.sender, token, amount);
    }

    // ============ 用户操作：领取奖励 ============

    function claimReward() public {
        UserInfo storage user = userInfo[msg.sender];

        updateReward();

        uint256 pending = getUserTotalValue(msg.sender).mul(accRewardPerShare).div(1e12).sub(user.rewardDebt);
        require(pending > 0, 'No pending reward');

        user.rewardDebt = getUserTotalValue(msg.sender).mul(accRewardPerShare).div(1e12);

        rewardToken.mint(msg.sender, pending);

        emit RewardPaid(msg.sender, pending);
    }

    // ============ 查询函数 ============

    function getPendingReward(address user) public view returns (uint256) {
        UserInfo storage info = userInfo[user];

        if (totalStakedValue == 0) return 0;

        uint256 blocks = block.number.sub(lastRewardBlock);
        uint256 reward = blocks.mul(rewardPerBlock);
        uint256 tempAccRewardPerShare = accRewardPerShare.add(reward.mul(1e12).div(totalStakedValue));

        return getUserTotalValue(user).mul(tempAccRewardPerShare).div(1e12).sub(info.rewardDebt);
    }

    function getUserTokenBalance(address user, address token) public view returns (uint256) {
        return userInfo[user].erc20Amounts[token];
    }

    // ============ 管理函数 ============

    function registerToken(address token, AggregatorV3Interface priceFeed) public onlyOwner {
        require(!isTokenRegistered[token], 'Token already registered');
        require(address(token) != address(0), 'Token address cannot be zero');
        require(address(priceFeed) != address(0), 'Price feed address cannot be zero');

        tokenPriceFeeds[token] = priceFeed;
        isTokenRegistered[token] = true;
        registeredTokens.push(token);

        emit TokenRegistered(token, address(priceFeed));
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) public onlyOwner {
        emit RewardPerBlockUpdated(rewardPerBlock, _rewardPerBlock);
        rewardPerBlock = _rewardPerBlock;
    }

    // ============ 紧急提取 ============

    function emergencyWithdrawETH() public {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amount = user.ethAmount;
        require(amount > 0, 'No staked ETH');

        uint256 usdValue = calculateETHValue(amount);
        user.ethAmount = 0;
        totalStakedValue = totalStakedValue.sub(usdValue);
        user.rewardDebt = getUserTotalValue(msg.sender).mul(accRewardPerShare).div(1e12);

        payable(msg.sender).transfer(amount);

        emit WithdrawnETH(msg.sender, amount);
    }

    function emergencyWithdrawERC20(address token) public {
        require(isTokenRegistered[token], 'Token not registered');

        UserInfo storage user = userInfo[msg.sender];
        uint256 amount = user.erc20Amounts[token];
        require(amount > 0, 'No staked ERC20');

        uint256 usdValue = calculateTokenValue(token, amount);
        user.erc20Amounts[token] = 0;
        totalStakedValue = totalStakedValue.sub(usdValue);
        user.rewardDebt = getUserTotalValue(msg.sender).mul(accRewardPerShare).div(1e12);

        TransferHelper.safeTransfer(token, msg.sender, amount);

        emit WithdrawnERC20(msg.sender, token, amount);
    }

    // ============ 内部函数 ============

    function _claimPendingReward(UserInfo storage user) internal {
        uint256 pending = getUserTotalValue(msg.sender).mul(accRewardPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            user.rewardDebt = getUserTotalValue(msg.sender).mul(accRewardPerShare).div(1e12);
            rewardToken.mint(msg.sender, pending);
            emit RewardPaid(msg.sender, pending);
        }
    }

    receive() external payable {
        depositETH();
    }
}