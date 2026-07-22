// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/**
 * @title DAOGov
 * @dev DAO治理合约，基于OpenZeppelin Governor框架实现
 * 
 * DAOGov是去中心化自治组织(DAO)的核心治理合约，负责提案创建、投票和执行。
 * 通过组合多个Governor扩展模块，实现完整的治理功能：
 * - GovernorSettings: 管理投票延迟、投票周期、提案门槛
 * - GovernorVotes: 基于代币投票权的治理机制
 * - GovernorVotesQuorumFraction: 基于代币总量比例的法定人数要求
 * - GovernorCountingSimple: 简单多数投票计数(赞成/反对/弃权)
 * 
 * DAOGov作为DAOBank的owner，所有资金提取操作都必须通过治理投票批准。
 */
contract DAOGov is GovernorSettings, GovernorVotes, GovernorVotesQuorumFraction, GovernorCountingSimple {
    /**
     * @dev 构造函数
     * @param token 投票代币合约地址(必须实现IVotes接口)
     * @param votingDelay 投票延迟(区块数)，提案创建后需要等待此数量的区块才能开始投票
     * @param votingPeriod 投票周期(区块数)，投票持续时间
     * @param initialProposalThreshold 提案门槛(代币数量)，创建提案所需的最小代币持有量
     * @param quorumNumerator 法定人数分子，法定人数 = (总供应量 * quorumNumerator) / 100
     */
    constructor(
        IVotes token,
        uint48 votingDelay,
        uint32 votingPeriod,
        uint256 initialProposalThreshold,
        uint256 quorumNumerator
    )
        Governor("DAOGov")
        GovernorSettings(votingDelay, votingPeriod, initialProposalThreshold)
        GovernorVotes(token)
        GovernorVotesQuorumFraction(quorumNumerator)
    {}

    /**
     * @dev 获取提案门槛
     * 由于Governor和GovernorSettings都定义了proposalThreshold()方法，
     * 需要显式覆盖并调用父类实现，解决菱形继承歧义问题。
     * @return 当前提案门槛(代币数量)
     */
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }
}