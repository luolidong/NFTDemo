// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/DAOToken.sol";

contract DAOTokenTest is Test {
    DAOToken public token;
    address public owner;
    address public voter;
    address public delegatee;

    function setUp() public {
        owner = address(this);
        voter = address(0x1);
        delegatee = address(0x2);
        token = new DAOToken();
    }

    function test_InitialSetup() public view {
        assertEq(token.name(), "DAOToken");
        assertEq(token.symbol(), "DAO");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 1000000 * 10 ** 18);
        assertEq(token.balanceOf(owner), 1000000 * 10 ** 18);
    }

    function test_DelegateToSelf() public {
        uint256 amount = 1000 * 10 ** 18;
        token.transfer(voter, amount);

        vm.prank(voter);
        token.delegate(voter);

        assertEq(token.delegates(voter), voter);
        assertEq(token.getVotes(voter), amount);
    }

    function test_DelegateToOther() public {
        uint256 amount = 1000 * 10 ** 18;
        token.transfer(voter, amount);

        vm.prank(voter);
        token.delegate(delegatee);

        assertEq(token.delegates(voter), delegatee);
        assertEq(token.getVotes(delegatee), amount);
        assertEq(token.getVotes(voter), 0);
    }

    function test_TransferUpdatesVotes() public {
        uint256 amount = 1000 * 10 ** 18;
        token.transfer(voter, amount);

        vm.prank(voter);
        token.delegate(voter);

        assertEq(token.getVotes(voter), amount);

        vm.prank(voter);
        token.transfer(delegatee, 500 * 10 ** 18);

        assertEq(token.getVotes(voter), 500 * 10 ** 18);
        assertEq(token.balanceOf(voter), 500 * 10 ** 18);
        assertEq(token.balanceOf(delegatee), 500 * 10 ** 18);
    }

    function test_GetPastVotes() public {
        uint256 amount = 1000 * 10 ** 18;

        uint256 blockBeforeTransfer = block.number;
        vm.roll(blockBeforeTransfer + 1);

        token.transfer(voter, amount);

        uint256 blockBeforeDelegate = block.number;
        vm.roll(blockBeforeDelegate + 1);

        vm.prank(voter);
        token.delegate(voter);

        vm.roll(block.number + 10);

        assertEq(token.getPastVotes(voter, blockBeforeTransfer), 0);
        assertEq(token.getPastVotes(voter, blockBeforeDelegate), 0);
        assertEq(token.getPastVotes(voter, block.number - 1), amount);
        assertEq(token.getVotes(voter), amount);
    }

    function test_Permit() public {
        uint256 privateKey = 1;
        address signer = vm.addr(privateKey);
        uint256 amount = 1000 * 10 ** 18;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(signer);

        token.transfer(signer, amount);

        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 permitTypehash = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(permitTypehash, signer, delegatee, amount, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        token.permit(signer, delegatee, amount, deadline, v, r, s);

        assertEq(token.allowance(signer, delegatee), amount);
        assertEq(token.nonces(signer), nonce + 1);
    }

    function test_TransferFromWithPermit() public {
        uint256 privateKey = 1;
        address signer = vm.addr(privateKey);
        uint256 amount = 1000 * 10 ** 18;
        uint256 deadline = block.timestamp + 1 hours;

        token.transfer(signer, amount);

        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 permitTypehash = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(permitTypehash, signer, delegatee, amount, 0, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        token.permit(signer, delegatee, amount, deadline, v, r, s);

        vm.prank(delegatee);
        token.transferFrom(signer, delegatee, amount);

        assertEq(token.balanceOf(delegatee), amount);
        assertEq(token.balanceOf(signer), 0);
    }

    function test_DelegateBySig() public {
        uint256 privateKey = 1;
        address signer = vm.addr(privateKey);
        uint256 amount = 1000 * 10 ** 18;
        uint256 nonce = token.nonces(signer);
        uint256 expiry = block.timestamp + 1 hours;

        token.transfer(signer, amount);

        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 delegationTypehash = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");
        bytes32 structHash = keccak256(abi.encode(delegationTypehash, signer, nonce, expiry));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        token.delegateBySig(signer, nonce, expiry, v, r, s);

        assertEq(token.delegates(signer), signer);
        assertEq(token.getVotes(signer), amount);
    }

    function test_DelegateChange() public {
        uint256 amount = 1000 * 10 ** 18;
        address newDelegatee = address(0x3);
        token.transfer(voter, amount);

        vm.prank(voter);
        token.delegate(delegatee);

        assertEq(token.delegates(voter), delegatee);
        assertEq(token.getVotes(delegatee), amount);

        vm.prank(voter);
        token.delegate(newDelegatee);

        assertEq(token.delegates(voter), newDelegatee);
        assertEq(token.getVotes(delegatee), 0);
        assertEq(token.getVotes(newDelegatee), amount);
    }

    function test_GetPastTotalSupply() public {
        uint256 initialSupply = token.totalSupply();

        uint256 blockBefore = block.number;
        vm.roll(blockBefore + 1);

        uint256 mintAmount = 100 * 10 ** 18;
        vm.prank(owner);
        token.transfer(voter, mintAmount);

        vm.roll(block.number + 10);

        assertEq(token.getPastTotalSupply(blockBefore), initialSupply);
        assertEq(token.getPastTotalSupply(block.number - 1), initialSupply);
    }

    function test_RevertFutureLookup() public {
        vm.expectRevert();
        token.getPastVotes(voter, block.number + 100);
    }
}