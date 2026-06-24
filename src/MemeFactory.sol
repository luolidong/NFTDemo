// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./MemeToken.sol";

contract MemeFactory {
    using Clones for address;

    address public immutable memeTokenImplementation;
    event TokenDeployed(address indexed token, string symbol, address indexed deployer);
    event TokenMinted(address indexed token, address indexed minter, uint256 amount);

    constructor(address _memeTokenImplementation) {
        require(_memeTokenImplementation != address(0), "Implementation cannot be zero");
        memeTokenImplementation = _memeTokenImplementation;
    }

    function deployInscription(string calldata symbol, uint256 totalSupply, uint256 perMint) external returns (address) {
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(totalSupply > 0, "Total supply must be greater than 0");
        require(perMint > 0, "Per mint must be greater than 0");

        address clone = memeTokenImplementation.clone();
        
        MemeToken(clone).initialize(symbol, symbol, totalSupply, perMint);
        
        emit TokenDeployed(clone, symbol, msg.sender);
        
        return clone;
    }

    function mintInscription(address tokenAddr) external {
        require(tokenAddr != address(0), "Token address cannot be zero");
        
        MemeToken(tokenAddr).mint();
        
        emit TokenMinted(tokenAddr, msg.sender, MemeToken(tokenAddr).perMint());
    }
}