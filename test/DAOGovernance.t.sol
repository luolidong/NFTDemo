// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "../src/DAOToken.sol";
import "../src/DAOGov.sol";
import "../src/DAOBank.sol";

contract DAOGovernanceTest is Test {
    DAOToken public daoToken;
    DAOGov public daoGov;
    DAOBank public daoBank;

    address public alice;
    address public bob;
    address public charlie;
    address public treasury;

    uint48 public constant VOTING_DELAY = 1;
    uint32 public constant VOTING_PERIOD = 5;
    uint256 public constant PROPOSAL_THRESHOLD = 0;
    uint256 public constant QUORUM_NUMERATOR = 4;

    function setUp() public {
        alice = address(0x1);
        bob = address(0x2);
        charlie = address(0x3);
        treasury = address(0x4);

        daoToken = new DAOToken();

        daoGov = new DAOGov(
            IVotes(address(daoToken)),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_NUMERATOR
        );

        daoBank = new DAOBank(address(daoGov));

        uint256 tokenAmount = 333333 * 10 ** 18;
        daoToken.transfer(alice, tokenAmount);
        daoToken.transfer(bob, tokenAmount);
        daoToken.transfer(charlie, tokenAmount);

        vm.prank(alice);
        daoToken.delegate(alice);

        vm.prank(bob);
        daoToken.delegate(bob);

        vm.prank(charlie);
        daoToken.delegate(charlie);

        vm.deal(address(daoBank), 100 ether);
    }

    function test_ProposalWithdrawETH() public {
        uint256 withdrawAmount = 50 ether;
        uint256 initialBankBalance = address(daoBank).balance;
        uint256 initialTreasuryBalance = treasury.balance;

        bytes memory withdrawCallData = abi.encodeWithSignature(
            "withdraw(address,uint256)",
            treasury,
            withdrawAmount
        );

        address[] memory targets = new address[](1);
        targets[0] = address(daoBank);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = withdrawCallData;

        string memory description = "Withdraw 50 ETH to treasury";

        uint256 proposalId = daoGov.propose(targets, values, calldatas, description);

        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(alice);
        daoGov.castVote(proposalId, 1);

        vm.prank(bob);
        daoGov.castVote(proposalId, 1);

        vm.prank(charlie);
        daoGov.castVote(proposalId, 0);

        vm.roll(block.number + VOTING_PERIOD + 1);

        daoGov.execute(targets, values, calldatas, keccak256(bytes(description)));

        assertEq(address(daoBank).balance, initialBankBalance - withdrawAmount);
        assertEq(treasury.balance, initialTreasuryBalance + withdrawAmount);
    }

    function test_ProposalWithdrawToken() public {
        uint256 tokenAmount = 100 * 10 ** 18;
        vm.prank(alice);
        daoToken.transfer(address(daoBank), tokenAmount);

        bytes memory withdrawCallData = abi.encodeWithSignature(
            "withdrawToken(address,address,uint256)",
            address(daoToken),
            treasury,
            tokenAmount / 2
        );

        address[] memory targets = new address[](1);
        targets[0] = address(daoBank);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = withdrawCallData;

        string memory description = "Withdraw DAOToken to treasury";

        uint256 proposalId = daoGov.propose(targets, values, calldatas, description);

        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(alice);
        daoGov.castVote(proposalId, 1);

        vm.prank(bob);
        daoGov.castVote(proposalId, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);

        daoGov.execute(targets, values, calldatas, keccak256(bytes(description)));

        assertEq(daoToken.balanceOf(treasury), tokenAmount / 2);
        assertEq(daoToken.balanceOf(address(daoBank)), tokenAmount / 2);
    }

    function test_OnlyGovernanceCanWithdraw() public {
        vm.expectRevert();
        vm.prank(alice);
        daoBank.withdraw(alice, 1 ether);
    }

    function test_QuorumRequirement() public {
        DAOGov highQuorumGov = new DAOGov(
            IVotes(address(daoToken)),
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            90
        );

        bytes memory withdrawCallData = abi.encodeWithSignature(
            "withdraw(address,uint256)",
            alice,
            1 ether
        );

        address[] memory targets = new address[](1);
        targets[0] = address(daoBank);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = withdrawCallData;

        string memory description = "Test quorum";

        uint256 proposalId = highQuorumGov.propose(targets, values, calldatas, description);

        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(alice);
        highQuorumGov.castVote(proposalId, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);

        assertEq(uint256(highQuorumGov.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
    }

    function test_VoteAgainstFailsProposal() public {
        bytes memory withdrawCallData = abi.encodeWithSignature(
            "withdraw(address,uint256)",
            alice,
            1 ether
        );

        address[] memory targets = new address[](1);
        targets[0] = address(daoBank);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = withdrawCallData;

        string memory description = "Test against vote";

        uint256 proposalId = daoGov.propose(targets, values, calldatas, description);

        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(alice);
        daoGov.castVote(proposalId, 1);

        vm.prank(bob);
        daoGov.castVote(proposalId, 0);

        vm.prank(charlie);
        daoGov.castVote(proposalId, 0);

        vm.roll(block.number + VOTING_PERIOD + 1);

        assertEq(uint256(daoGov.state(proposalId)), uint256(IGovernor.ProposalState.Defeated));
    }
}