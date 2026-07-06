// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VestingWallet} from "openzeppelin-contracts/contracts/finance/VestingWallet.sol";
import {VestingWalletCliff} from "openzeppelin-contracts/contracts/finance/VestingWalletCliff.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @dev TokenVesting 合约实现了基于时间的代币线性释放机制
 * 
 * 释放规则：
 * - Cliff 期：12 个月，期间无任何代币可释放
 * - 线性释放期：Cliff 期结束后，接下来的 24 个月每月解锁 1/24 的代币
 * - 从第 13 个月起开始每月解锁，36 个月后全部释放完毕
 * 
 * 合约部署后开始计算 Cliff 时间，需转入 1,000,000 ERC20 资产
 */
contract TokenVesting is VestingWalletCliff {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;

    uint64 public constant CLIFF_MONTHS = 12;
    uint64 public constant VESTING_MONTHS = 24;
    uint64 public constant SECONDS_PER_MONTH = 30 days;

    /**
     * @dev 初始化 Vesting 合约
     * @param beneficiary 受益人地址，代币将释放到此地址
     * @param tokenAddress 锁定的 ERC20 代币地址
     */
    constructor(address beneficiary, address tokenAddress)
        VestingWallet(beneficiary, uint64(block.timestamp), (CLIFF_MONTHS + VESTING_MONTHS) * SECONDS_PER_MONTH)
        VestingWalletCliff(CLIFF_MONTHS * SECONDS_PER_MONTH)
    {
        token = IERC20(tokenAddress);
    }

    /**
     * @dev 释放当前已解锁的 ERC20 代币给受益人
     * 
     * 重写 VestingWallet 的 release() 方法，使其仅处理 ERC20 代币释放
     * 如需释放 ETH，请使用 releaseETH() 方法
     */
    function release() public virtual override {
        release(address(token));
    }

    /**
     * @dev 释放合约中持有的 ETH 给受益人
     * 
     * 调用父类 VestingWallet 的 release() 方法来处理 ETH 释放
     */
    function releaseETH() public virtual {
        super.release();
    }

    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp)
        internal
        view
        virtual
        override(VestingWalletCliff)
        returns (uint256)
    {
        if (timestamp < cliff()) {
            return 0;
        }

        uint64 timeSinceCliff = timestamp - uint64(cliff());
        uint64 monthsSinceCliff = timeSinceCliff / SECONDS_PER_MONTH;

        if (monthsSinceCliff >= VESTING_MONTHS) {
            return totalAllocation;
        }

        return (totalAllocation * monthsSinceCliff) / VESTING_MONTHS;
    }
}