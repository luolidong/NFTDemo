// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/TokenBank.sol";
import "../src/MyPermitToken.sol";

contract TokenBankTest is Test {
    MyPermitToken public token;
    TokenBank public bank;
    address public owner;
    address public user1;
    uint256 public user1PrivateKey;

    function setUp() public {
        owner = address(this);
        user1PrivateKey = 1;
        user1 = vm.addr(user1PrivateKey);

        // 部署代币合约
        token = new MyPermitToken();

        // 部署银行合约
        bank = new TokenBank(address(token));

        // 给 user1 转一些代币用于测试
        token.transfer(user1, 10000 * 10 ** 18);
    }

    function test_Deposit() public {
        uint256 depositAmount = 1000 * 10 ** 18;

        // user1 先授权
        vm.prank(user1);
        token.approve(address(bank), depositAmount);

        // user1 存款
        vm.prank(user1);
        bank.deposit(depositAmount);

        // 验证
        assertEq(bank.getUserDeposit(user1), depositAmount);
        assertEq(token.balanceOf(address(bank)), depositAmount);
        assertEq(token.balanceOf(user1), 10000 * 10 ** 18 - depositAmount);
    }

    function test_PermitDeposit() public {
        uint256 depositAmount = 1000 * 10 ** 18;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(user1);

        // 创建 permit 签名
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 permitTypehash = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(permitTypehash, user1, address(bank), depositAmount, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        // 使用私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);

        // 验证初始状态
        assertEq(token.allowance(user1, address(bank)), 0);
        assertEq(bank.getUserDeposit(user1), 0);

        // 使用 permitDeposit 存款
        vm.prank(user1);
        bank.permitDeposit(depositAmount, deadline, v, r, s);

        // 验证结果
        assertEq(bank.getUserDeposit(user1), depositAmount);
        assertEq(token.balanceOf(address(bank)), depositAmount);
        assertEq(token.balanceOf(user1), 10000 * 10 ** 18 - depositAmount);
        assertEq(token.nonces(user1), nonce + 1);
    }

    function test_PermitDeposit_MultipleTimes() public {
        uint256 depositAmount1 = 500 * 10 ** 18;

        // 第一次存款
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(user1);
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 permitTypehash = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(permitTypehash, user1, address(bank), depositAmount1, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);

        vm.prank(user1);
        bank.permitDeposit(depositAmount1, deadline, v, r, s);

        // 第二次存款
        uint256 depositAmount2 = 300 * 10 ** 18;
        nonce = token.nonces(user1);
        structHash = keccak256(abi.encode(permitTypehash, user1, address(bank), depositAmount2, nonce, deadline));
        digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (v, r, s) = vm.sign(user1PrivateKey, digest);

        vm.prank(user1);
        bank.permitDeposit(depositAmount2, deadline, v, r, s);

        // 验证
        assertEq(bank.getUserDeposit(user1), depositAmount1 + depositAmount2);
        assertEq(token.balanceOf(address(bank)), depositAmount1 + depositAmount2);
    }

    function test_PermitDeposit_RevertIf_AmountZero() public {
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(user1);
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 permitTypehash = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(permitTypehash, user1, address(bank), uint256(0), nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, digest);

        vm.prank(user1);
        vm.expectRevert("Amount must be greater than 0");
        bank.permitDeposit(0, deadline, v, r, s);
    }

    function test_Withdraw() public {
        // 先存款
        uint256 depositAmount = 1000 * 10 ** 18;
        vm.prank(user1);
        token.approve(address(bank), depositAmount);
        vm.prank(user1);
        bank.deposit(depositAmount);

        // 提款
        uint256 bankBalanceBefore = token.balanceOf(address(bank));
        uint256 ownerBalanceBefore = token.balanceOf(owner);

        bank.withdraw();

        assertEq(token.balanceOf(address(bank)), 0);
        assertEq(token.balanceOf(owner), ownerBalanceBefore + bankBalanceBefore);
    }
}