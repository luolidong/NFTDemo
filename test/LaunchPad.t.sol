// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {UniswapV2Factory} from "../uniswapv2/UniswapV2Factory.sol";
import {UniswapV2Router02} from "../uniswapv2/UniswapV2Router02.sol";
import {UniswapV2Pair} from "../uniswapv2/UniswapV2Pair.sol";
import {WETH9} from "../uniswapv2/test/WETH9.sol";
import {LaunchPad} from "../src/LaunchPad.sol";
import {MemeToken} from "../src/MemeToken.sol";

contract LaunchPadTest is Test {
    WETH9 public weth;
    UniswapV2Factory public factory;
    UniswapV2Router02 public router;
    MemeToken public memeTokenImplementation;
    LaunchPad public launchpad;

    address public constant ALICE = address(0x1234);
    address public constant BOB = address(0x5678);
    address public constant CHARLIE = address(0x9ABC);

    receive() external payable {}

    uint256 public constant TOTAL_SUPPLY = 10000 ether;
    uint256 public constant PRICE = 1 gwei;
    uint256 public constant MINT_ETH = 10 ether;
    uint256 public constant BUY_ETH = 5 ether;

    function setUp() public {
        weth = new WETH9();
        factory = new UniswapV2Factory(address(this));
        router = new UniswapV2Router02(address(factory), address(weth));
        memeTokenImplementation = new MemeToken();
        launchpad = new LaunchPad(address(router), address(memeTokenImplementation));

        vm.deal(ALICE, 200 ether);
        vm.deal(BOB, 200 ether);
        vm.deal(CHARLIE, 200 ether);
    }

    function test_DeployMeme() public {
        vm.prank(ALICE);
        address memeToken = launchpad.deployMeme(
            "Test Meme",
            "TM",
            TOTAL_SUPPLY,
            PRICE
        );

        require(memeToken != address(0), "Token address should not be zero");

        MemeToken token = MemeToken(memeToken);
        assertEq(token.name(), "Test Meme");
        assertEq(token.symbol(), "TM");
        assertEq(token.totalSupply(), 0, "Total supply should be zero initially");

        (uint256 price, uint256 totalSupply, uint256 remainingSupply, bool exists, bool liquidityAdded) = launchpad.memeInfos(memeToken);
        assertEq(price, PRICE);
        assertEq(totalSupply, TOTAL_SUPPLY);
        assertEq(remainingSupply, TOTAL_SUPPLY);
        assertTrue(exists);
        assertFalse(liquidityAdded);

        assertEq(address(launchpad).balance, 0, "LaunchPad should have no ETH");
    }

    function test_MintMeme_FirstCall_AddsLiquidity() public {
        vm.prank(ALICE);
        address memeToken = launchpad.deployMeme(
            "Test Meme",
            "TM",
            TOTAL_SUPPLY,
            PRICE
        );

        uint256 liquidityEth = MINT_ETH * 5 / 100;
        uint256 purchaseEth = MINT_ETH - liquidityEth;
        uint256 expectedAmount = purchaseEth / PRICE;
        uint256 balanceBefore = MemeToken(memeToken).balanceOf(BOB);

        vm.prank(BOB);
        launchpad.mintMeme{value: MINT_ETH}(memeToken);

        uint256 balanceAfter = MemeToken(memeToken).balanceOf(BOB);
        assertEq(balanceAfter - balanceBefore, expectedAmount, "Minted amount should match (95% of ETH)");

        uint256 liquidityMeme = liquidityEth / PRICE;

        (, , uint256 remainingSupply, , bool liquidityAdded) = launchpad.memeInfos(memeToken);
        assertEq(remainingSupply, TOTAL_SUPPLY - liquidityMeme - expectedAmount, "Remaining supply should decrease");
        assertTrue(liquidityAdded, "Liquidity should be added");

        address pair = factory.getPair(memeToken, address(weth));
        assertNotEq(pair, address(0), "Pair should be created");

        (uint112 reserve0, uint112 reserve1,) = UniswapV2Pair(pair).getReserves();
        uint256 memeReserve = memeToken < address(weth) ? reserve0 : reserve1;
        uint256 ethReserve = memeToken < address(weth) ? reserve1 : reserve0;

        assertEq(memeReserve, liquidityMeme, "Meme reserve should match");
        assertEq(ethReserve, liquidityEth, "ETH reserve should match");

        uint256 expectedContractEth = MINT_ETH - liquidityEth;
        assertEq(address(launchpad).balance, expectedContractEth, "LaunchPad should have remaining ETH");
    }

    function test_MintMeme_SubsequentCalls_NoLiquidity() public {
        vm.prank(ALICE);
        address memeToken = launchpad.deployMeme(
            "Test Meme",
            "TM",
            TOTAL_SUPPLY,
            PRICE
        );

        vm.prank(BOB);
        launchpad.mintMeme{value: MINT_ETH}(memeToken);

        uint256 liquidityEth = MINT_ETH * 5 / 100;
        uint256 liquidityMeme = liquidityEth / PRICE;
        uint256 purchaseEth = MINT_ETH - liquidityEth;
        uint256 firstMintAmount = purchaseEth / PRICE;

        uint256 balanceBefore = MemeToken(memeToken).balanceOf(CHARLIE);

        vm.prank(CHARLIE);
        launchpad.mintMeme{value: MINT_ETH}(memeToken);

        uint256 balanceAfter = MemeToken(memeToken).balanceOf(CHARLIE);
        uint256 subsequentMintAmount = MINT_ETH / PRICE;
        assertEq(balanceAfter - balanceBefore, subsequentMintAmount, "Subsequent mint should get full amount");

        (, , uint256 remainingSupply, , bool liquidityAdded) = launchpad.memeInfos(memeToken);
        assertEq(remainingSupply, TOTAL_SUPPLY - liquidityMeme - firstMintAmount - subsequentMintAmount, "Remaining supply should decrease");
        assertTrue(liquidityAdded, "Liquidity should still be added");
    }

    function test_BuyMeme() public {
        vm.prank(ALICE);
        address memeToken = launchpad.deployMeme(
            "Test Meme",
            "TM",
            TOTAL_SUPPLY,
            PRICE
        );

        vm.prank(BOB);
        launchpad.mintMeme{value: MINT_ETH}(memeToken);

        uint256 balanceBefore = MemeToken(memeToken).balanceOf(CHARLIE);

        vm.prank(CHARLIE);
        launchpad.buyMeme{value: BUY_ETH}(memeToken, 0);

        uint256 balanceAfter = MemeToken(memeToken).balanceOf(CHARLIE);
        assertGt(balanceAfter - balanceBefore, 0, "Should receive some tokens");
    }

    function test_MintMeme_InsufficientSupply() public {
        vm.prank(ALICE);
        address memeToken = launchpad.deployMeme(
            "Test Meme",
            "TM",
            TOTAL_SUPPLY,
            PRICE
        );

        vm.prank(BOB);
        launchpad.mintMeme{value: MINT_ETH}(memeToken);

        (, , uint256 remainingSupply, ,) = launchpad.memeInfos(memeToken);
        uint256 excessAmount = (remainingSupply + 1) * PRICE;
        
        vm.deal(CHARLIE, excessAmount + 1 ether);

        vm.prank(CHARLIE);
        vm.expectRevert("Not enough remaining supply");
        launchpad.mintMeme{value: excessAmount}(memeToken);
    }

    function test_MintMeme_FirstCall_InsufficientSupply() public {
        uint256 smallSupply = 10000;
        uint256 ethAmount = smallSupply * PRICE * 2;

        vm.prank(ALICE);
        address memeToken = launchpad.deployMeme(
            "Test Meme",
            "TM",
            smallSupply,
            PRICE
        );

        vm.prank(BOB);
        vm.expectRevert("Not enough remaining supply");
        launchpad.mintMeme{value: ethAmount}(memeToken);
    }

    function test_BuyMeme_NoLiquidity() public {
        vm.prank(ALICE);
        address memeToken = launchpad.deployMeme(
            "Test Meme",
            "TM",
            TOTAL_SUPPLY,
            PRICE
        );

        vm.prank(BOB);
        vm.expectRevert("Liquidity not added yet");
        launchpad.buyMeme{value: BUY_ETH}(memeToken, 0);
    }

    function test_MintMeme_NonExistentToken() public {
        address fakeToken = address(0xdead);
        
        vm.prank(BOB);
        vm.expectRevert("Meme does not exist");
        launchpad.mintMeme{value: MINT_ETH}(fakeToken);
    }

    function test_BuyMeme_NonExistentToken() public {
        address fakeToken = address(0xdead);
        
        vm.prank(BOB);
        vm.expectRevert("Meme does not exist");
        launchpad.buyMeme{value: BUY_ETH}(fakeToken, 0);
    }

    function test_MintMeme_ZeroEth() public {
        vm.prank(ALICE);
        address memeToken = launchpad.deployMeme(
            "Test Meme",
            "TM",
            TOTAL_SUPPLY,
            PRICE
        );

        vm.prank(BOB);
        vm.expectRevert("ETH must be sent");
        launchpad.mintMeme{value: 0}(memeToken);
    }

    function test_BuyMeme_ZeroEth() public {
        vm.prank(ALICE);
        address memeToken = launchpad.deployMeme(
            "Test Meme",
            "TM",
            TOTAL_SUPPLY,
            PRICE
        );

        vm.prank(BOB);
        launchpad.mintMeme{value: MINT_ETH}(memeToken);

        vm.prank(CHARLIE);
        vm.expectRevert("ETH must be sent");
        launchpad.buyMeme{value: 0}(memeToken, 0);
    }

    function test_WithdrawETH() public {
        vm.prank(ALICE);
        address memeToken = launchpad.deployMeme(
            "Test Meme",
            "TM",
            TOTAL_SUPPLY,
            PRICE
        );

        vm.prank(BOB);
        launchpad.mintMeme{value: MINT_ETH}(memeToken);

        uint256 liquidityEth = MINT_ETH * 5 / 100;
        uint256 expectedContractEth = MINT_ETH - liquidityEth;
        assertEq(address(launchpad).balance, expectedContractEth, "LaunchPad should have ETH");

        uint256 balanceBefore = address(this).balance;
        uint256 withdrawAmount = expectedContractEth / 2;

        launchpad.withdrawETH(address(this), withdrawAmount);

        uint256 balanceAfter = address(this).balance;
        assertEq(balanceAfter - balanceBefore, withdrawAmount, "Should receive withdrawn ETH");
        assertEq(address(launchpad).balance, expectedContractEth - withdrawAmount, "LaunchPad balance should decrease");
    }

    function test_WithdrawAllETH() public {
        vm.prank(ALICE);
        address memeToken = launchpad.deployMeme(
            "Test Meme",
            "TM",
            TOTAL_SUPPLY,
            PRICE
        );

        vm.prank(BOB);
        launchpad.mintMeme{value: MINT_ETH}(memeToken);

        uint256 liquidityEth = MINT_ETH * 5 / 100;
        uint256 expectedContractEth = MINT_ETH - liquidityEth;
        assertEq(address(launchpad).balance, expectedContractEth, "LaunchPad should have ETH");

        uint256 balanceBefore = address(this).balance;

        launchpad.withdrawAllETH(address(this));

        uint256 balanceAfter = address(this).balance;
        assertEq(balanceAfter - balanceBefore, expectedContractEth, "Should receive all ETH");
        assertEq(address(launchpad).balance, 0, "LaunchPad balance should be zero");
    }

    function test_WithdrawETH_NotOwner() public {
        vm.prank(ALICE);
        address memeToken = launchpad.deployMeme(
            "Test Meme",
            "TM",
            TOTAL_SUPPLY,
            PRICE
        );

        vm.prank(BOB);
        launchpad.mintMeme{value: MINT_ETH}(memeToken);

        vm.prank(CHARLIE);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", CHARLIE));
        launchpad.withdrawETH(CHARLIE, 1 ether);
    }

    function test_WithdrawETH_ZeroAmount() public {
        vm.prank(ALICE);
        address memeToken = launchpad.deployMeme(
            "Test Meme",
            "TM",
            TOTAL_SUPPLY,
            PRICE
        );

        vm.prank(BOB);
        launchpad.mintMeme{value: MINT_ETH}(memeToken);

        vm.expectRevert("Amount must be greater than 0");
        launchpad.withdrawETH(address(this), 0);
    }

    function test_WithdrawETH_InsufficientBalance() public {
        vm.prank(ALICE);
        address memeToken = launchpad.deployMeme(
            "Test Meme",
            "TM",
            TOTAL_SUPPLY,
            PRICE
        );

        vm.prank(BOB);
        launchpad.mintMeme{value: MINT_ETH}(memeToken);

        vm.expectRevert("Insufficient balance");
        launchpad.withdrawETH(address(this), MINT_ETH + 1 ether);
    }
}