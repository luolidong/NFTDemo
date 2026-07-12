// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../uniswapv2/interfaces/IUniswapV2Router02.sol";
import "./MemeToken.sol";

contract LaunchPad is ReentrancyGuard, Ownable {
    using Clones for address;

    IUniswapV2Router02 public immutable router;
    address public immutable weth;
    address public immutable memeTokenImplementation;

    struct MemeInfo {
        uint256 price;
        uint256 totalSupply;
        uint256 remainingSupply;
        bool exists;
        bool liquidityAdded;
    }

    mapping(address => MemeInfo) public memeInfos;

    event MemeDeployed(
        address indexed token,
        string name,
        string symbol,
        uint256 price,
        uint256 totalSupply,
        address indexed deployer
    );
    event MemeMinted(
        address indexed token,
        address indexed buyer,
        uint256 amount,
        uint256 ethPaid
    );
    event MemeBought(
        address indexed token,
        address indexed buyer,
        uint256 amount,
        uint256 ethPaid
    );
    event LiquidityAdded(
        address indexed token,
        uint256 ethAmount,
        uint256 memeAmount
    );
    event ETHWithdrawn(
        address indexed to,
        uint256 amount
    );

    constructor(
        address _router,
        address _memeTokenImplementation
    ) Ownable(msg.sender) {
        require(_router != address(0), "Router cannot be zero");
        require(_memeTokenImplementation != address(0), "Implementation cannot be zero");
        
        router = IUniswapV2Router02(_router);
        weth = router.WETH();
        memeTokenImplementation = _memeTokenImplementation;
    }

    function deployMeme(
        string calldata name_,
        string calldata symbol_,
        uint256 totalSupply_,
        uint256 price_
    ) external nonReentrant returns (address) {
        require(bytes(name_).length > 0, "Name cannot be empty");
        require(bytes(symbol_).length > 0, "Symbol cannot be empty");
        require(totalSupply_ > 0, "Total supply must be greater than 0");
        require(price_ > 0, "Price must be greater than 0");

        address clone = memeTokenImplementation.clone();
        
        MemeToken(clone).initializeWithLaunchpad(name_, symbol_, 0, 0, address(this));

        memeInfos[clone] = MemeInfo({
            price: price_,
            totalSupply: totalSupply_,
            remainingSupply: totalSupply_,
            exists: true,
            liquidityAdded: false
        });

        emit MemeDeployed(clone, name_, symbol_, price_, totalSupply_, msg.sender);

        return clone;
    }

    function mintMeme(address token) external payable nonReentrant {
        require(memeInfos[token].exists, "Meme does not exist");
        require(msg.value > 0, "ETH must be sent");

        MemeInfo storage info = memeInfos[token];
        uint256 amount;

        if (!info.liquidityAdded) {
            uint256 liquidityEth = msg.value * 5 / 100;
            uint256 liquidityMeme = liquidityEth / info.price;
            require(liquidityMeme > 0, "Liquidity meme amount must be greater than 0");

            uint256 purchaseEth = msg.value - liquidityEth;
            amount = purchaseEth / info.price;
            require(amount > 0, "Amount must be greater than 0");
            require(amount + liquidityMeme <= info.remainingSupply, "Not enough remaining supply");

            MemeToken(token).mintTo(address(this), liquidityMeme);
            MemeToken(token).approve(address(router), liquidityMeme);

            router.addLiquidityETH{value: liquidityEth}(
                address(token),
                liquidityMeme,
                0,
                0,
                msg.sender,
                block.timestamp + 1 hours
            );

            info.remainingSupply -= liquidityMeme;
            info.liquidityAdded = true;

            emit LiquidityAdded(token, liquidityEth, liquidityMeme);
        } else {
            amount = msg.value / info.price;
            require(amount > 0, "Amount must be greater than 0");
            require(amount <= info.remainingSupply, "Not enough remaining supply");
        }

        info.remainingSupply -= amount;
        MemeToken(token).mintTo(msg.sender, amount);

        emit MemeMinted(token, msg.sender, amount, msg.value);
    }

    function buyMeme(address token, uint256 amountOutMin) external payable nonReentrant {
        require(memeInfos[token].exists, "Meme does not exist");
        require(memeInfos[token].liquidityAdded, "Liquidity not added yet");
        require(msg.value > 0, "ETH must be sent");

        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = token;

        uint256 balanceBefore = MemeToken(token).balanceOf(msg.sender);

        router.swapExactETHForTokens{value: msg.value}(
            amountOutMin,
            path,
            msg.sender,
            block.timestamp + 1 hours
        );

        uint256 amountReceived = MemeToken(token).balanceOf(msg.sender) - balanceBefore;

        emit MemeBought(token, msg.sender, amountReceived, msg.value);
    }

    function withdrawETH(address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "To cannot be zero");
        require(amount > 0, "Amount must be greater than 0");
        require(address(this).balance >= amount, "Insufficient balance");

        payable(to).transfer(amount);

        emit ETHWithdrawn(to, amount);
    }

    function withdrawAllETH(address to) external onlyOwner nonReentrant {
        require(to != address(0), "To cannot be zero");
        require(address(this).balance > 0, "No ETH to withdraw");

        uint256 amount = address(this).balance;
        payable(to).transfer(amount);

        emit ETHWithdrawn(to, amount);
    }

    receive() external payable {}
}