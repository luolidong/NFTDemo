// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title MyPermitToken
 * @dev ERC20 Token with EIP-2612 Permit functionality
 * 基于 OpenZeppelin 实现，支持 permit 功能
 */
contract MyPermitToken is ERC20, ERC20Permit {
    /**
     * @dev Constructor that gives msg.sender all of existing tokens.
     * 名称: MyPermitToken
     * 符号: MPT2
     * 初始供应量: 100,000 tokens
     */
    constructor() ERC20("MyPermitToken", "MPT2") ERC20Permit("MyPermitToken") {
        _mint(msg.sender, 100000 * 10 ** decimals());
    }
}