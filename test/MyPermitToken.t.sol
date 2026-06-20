// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MyPermitToken.sol";

contract MyPermitTokenTest is Test {
    MyPermitToken public token;
    address public owner;
    address public spender;

    function setUp() public {
        owner = address(this);
        spender = address(0x1);
        token = new MyPermitToken();
    }

    function test_InitialSetup() public view {
        assertEq(token.name(), "MyPermitToken");
        assertEq(token.symbol(), "MPT2");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 100000 * 10 ** 18);
        assertEq(token.balanceOf(owner), 100000 * 10 ** 18);
    }

    function test_Permit() public {
        uint256 privateKey = 1;
        address signer = vm.addr(privateKey);
        uint256 amount = 1000 * 10 ** 18;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(signer);

        // 将代币转移给 signer 以便测试
        token.transfer(signer, amount);

        // 创建签名
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        bytes32 permitTypehash = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(permitTypehash, signer, spender, amount, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        // 使用私钥签名
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // 使用 permit 授权
        vm.prank(signer);
        token.permit(signer, spender, amount, deadline, v, r, s);

        // 验证授权
        assertEq(token.allowance(signer, spender), amount);
        assertEq(token.nonces(signer), nonce + 1);
    }

    function test_Transfer() public {
        uint256 amount = 1000 * 10 ** 18;
        token.transfer(spender, amount);
        assertEq(token.balanceOf(spender), amount);
        assertEq(token.balanceOf(owner), 100000 * 10 ** 18 - amount);
    }
}