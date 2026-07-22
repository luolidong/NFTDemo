// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @title DAOToken
 * @dev 支持投票功能的ERC20代币，用于DAO治理
 * 
 * DAOToken继承了ERC20、ERC20Permit和ERC20Votes三个模块：
 * - ERC20: 标准代币功能(转账、余额查询等)
 * - ERC20Permit: 支持无Gas费授权(EIP-2612)
 * - ERC20Votes: 支持投票权委托和历史投票记录(EIP-712)
 * 
 * 代币持有者可以通过delegate()方法将投票权委托给自己或其他地址，
 * 投票权基于代币持有量计算，支持历史快照查询。
 */
contract DAOToken is ERC20, ERC20Permit, ERC20Votes {
    /**
     * @dev 初始供应量：100万枚，每枚18位小数
     */
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10 ** 18;

    /**
     * @dev 构造函数
     * 初始化代币名称为"DAOToken"，符号为"DAO"，并将全部初始供应量铸造给部署者
     */
    constructor() ERC20("DAOToken", "DAO") ERC20Permit("DAOToken") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /**
     * @dev 更新代币余额时同步更新投票权
     * 重写ERC20的_update方法，确保转账时正确更新投票权状态
     * 需要同时覆盖ERC20和ERC20Votes的_update方法，解决菱形继承问题
     * @param from 转出地址
     * @param to 转入地址
     * @param amount 转账金额
     */
    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    /**
     * @dev 获取nonce值
     * ERC20Permit和Nonces都定义了nonces()方法，需要显式覆盖解决歧义
     * @param owner 查询地址
     * @return 当前nonce值
     */
    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}