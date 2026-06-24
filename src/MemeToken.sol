// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract MemeToken is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    
    uint256 public totalSupply_;
    uint256 public perMint;
    uint256 public totalMinted;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    bool public initialized;

    event Mint(address indexed to, uint256 amount);

    function initialize(string calldata name_, string calldata symbol_, uint256 initialSupply_, uint256 perMint_) external {
        require(!initialized, "Already initialized");
        require(bytes(name_).length > 0, "Name cannot be empty");
        require(bytes(symbol_).length > 0, "Symbol cannot be empty");
        require(initialSupply_ > 0, "Total supply must be greater than 0");
        require(perMint_ > 0, "Per mint must be greater than 0");
        
        name = name_;
        symbol = symbol_;
        perMint = perMint_;
        
        totalSupply_ = initialSupply_;
        balanceOf[msg.sender] = initialSupply_;
        totalMinted = totalSupply_;
        initialized = true;
        
        emit Transfer(address(0), msg.sender, totalSupply_);
    }

    function totalSupply() external view returns (uint256) {
        return totalSupply_;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Allowance exceeded");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        emit Transfer(from, to, value);
        return true;
    }

    function mint() external {
        require(initialized, "Not initialized");
        uint256 newTotal = totalSupply_ + perMint;
        require(newTotal >= totalSupply_, "Total supply overflow");
        
        totalSupply_ = newTotal;
        balanceOf[msg.sender] += perMint;
        totalMinted += perMint;
        
        emit Transfer(address(0), msg.sender, perMint);
        emit Mint(msg.sender, perMint);
    }
}