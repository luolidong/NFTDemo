// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/OptionToken.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockUSDT is ERC20 {
    constructor() ERC20("MockUSDT", "USDT") {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockUSDT6Decimals is ERC20 {
    constructor() ERC20("MockUSDT6", "USDT6") {}
    
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract OptionTokenTest is Test {
    OptionToken public optionToken;
    MockUSDT public usdt;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    
    uint256 public constant STRIKE_PRICE = 3000 * 10**18;
    uint256 public constant EXERCISE_DATE_OFFSET = 7 days;
    uint256 public constant EXPIRY_DATE_OFFSET = 8 days;
    uint256 public exerciseDate;
    uint256 public expiryDate;
    
    function setUp() public {
        exerciseDate = block.timestamp + EXERCISE_DATE_OFFSET;
        expiryDate = block.timestamp + EXPIRY_DATE_OFFSET;
        
        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        
        vm.startPrank(owner);
        usdt = new MockUSDT();
        optionToken = new OptionToken(STRIKE_PRICE, exerciseDate, expiryDate, address(usdt), "ETH Call Option", "ETH-CALL");
        vm.stopPrank();
    }
    
    function testInitialState() public {
        assertEq(optionToken.strikePrice(), STRIKE_PRICE);
        assertEq(optionToken.exerciseDate(), exerciseDate);
        assertEq(optionToken.expiryDate(), expiryDate);
        assertEq(address(optionToken.paymentToken()), address(usdt));
        assertEq(optionToken.paymentTokenDecimals(), 18);
        assertFalse(optionToken.isExpired());
        assertEq(optionToken.totalSupply(), 0);
        assertEq(optionToken.getEthBalance(), 0);
    }
    
    function testMintByOwner() public {
        uint256 ethAmount = 1 ether;
        
        vm.prank(owner);
        optionToken.mint{value: ethAmount}();
        
        assertEq(optionToken.balanceOf(owner), ethAmount);
        assertEq(optionToken.totalSupply(), ethAmount);
        assertEq(optionToken.getEthBalance(), ethAmount);
    }
    
    function testMintByNonOwner() public {
        uint256 ethAmount = 1 ether;
        
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        vm.prank(user1);
        optionToken.mint{value: ethAmount}();
    }
    
    function testMintZeroAmount() public {
        vm.expectRevert("Must deposit ETH");
        vm.prank(owner);
        optionToken.mint{value: 0}();
    }
    
    function testExerciseBeforeDate() public {
        uint256 ethAmount = 1 ether;
        
        vm.prank(owner);
        optionToken.mint{value: ethAmount}();
        
        vm.prank(owner);
        optionToken.transfer(user1, ethAmount);
        
        uint256 usdtAmount = ethAmount * STRIKE_PRICE / 10**18;
        vm.prank(owner);
        usdt.mint(user1, usdtAmount);
        
        vm.prank(user1);
        usdt.approve(address(optionToken), usdtAmount);
        
        vm.expectRevert("Exercise date not reached");
        vm.prank(user1);
        optionToken.exercise(ethAmount);
    }
    
    function testExerciseAfterExpiryDate() public {
        uint256 ethAmount = 1 ether;
        
        vm.prank(owner);
        optionToken.mint{value: ethAmount}();
        
        vm.prank(owner);
        optionToken.transfer(user1, ethAmount);
        
        vm.warp(expiryDate + 1 days);
        
        vm.expectRevert("Exercise period ended");
        vm.prank(user1);
        optionToken.exercise(ethAmount);
    }
    
    function testExerciseOnDate() public {
        uint256 ethAmount = 1 ether;
        
        vm.prank(owner);
        optionToken.mint{value: ethAmount}();
        
        vm.prank(owner);
        optionToken.transfer(user1, ethAmount);
        
        uint256 usdtAmount = ethAmount * STRIKE_PRICE / 10**18;
        vm.prank(owner);
        usdt.mint(user1, usdtAmount);
        
        vm.prank(user1);
        usdt.approve(address(optionToken), usdtAmount);
        
        vm.warp(exerciseDate);
        
        uint256 user1EthBefore = user1.balance;
        uint256 ownerUsdtBefore = usdt.balanceOf(owner);
        
        vm.prank(user1);
        optionToken.exercise(ethAmount);
        
        assertEq(optionToken.balanceOf(user1), 0);
        assertEq(optionToken.totalSupply(), 0);
        assertEq(user1.balance, user1EthBefore + ethAmount);
        assertEq(usdt.balanceOf(owner), ownerUsdtBefore + usdtAmount);
        assertEq(usdt.balanceOf(user1), 0);
    }
    
    function testExercisePartialAmount() public {
        uint256 ethAmount = 1 ether;
        uint256 exerciseAmount = 0.5 ether;
        
        vm.prank(owner);
        optionToken.mint{value: ethAmount}();
        
        vm.prank(owner);
        optionToken.transfer(user1, ethAmount);
        
        uint256 usdtAmount = exerciseAmount * STRIKE_PRICE / 10**18;
        vm.prank(owner);
        usdt.mint(user1, usdtAmount);
        
        vm.prank(user1);
        usdt.approve(address(optionToken), usdtAmount);
        
        vm.warp(exerciseDate);
        
        uint256 user1EthBefore = user1.balance;
        uint256 ownerUsdtBefore = usdt.balanceOf(owner);
        
        vm.prank(user1);
        optionToken.exercise(exerciseAmount);
        
        assertEq(optionToken.balanceOf(user1), ethAmount - exerciseAmount);
        assertEq(optionToken.totalSupply(), ethAmount - exerciseAmount);
        assertEq(user1.balance, user1EthBefore + exerciseAmount);
        assertEq(usdt.balanceOf(owner), ownerUsdtBefore + usdtAmount);
        assertEq(usdt.balanceOf(user1), 0);
    }
    
    function testExerciseInsufficientOptions() public {
        uint256 ethAmount = 0.5 ether;
        
        vm.prank(owner);
        optionToken.mint{value: ethAmount}();
        
        vm.prank(owner);
        optionToken.transfer(user1, ethAmount);
        
        vm.warp(exerciseDate);
        
        vm.expectRevert();
        vm.prank(user1);
        optionToken.exercise(1 ether);
    }
    
    function testExerciseInsufficientUSDT() public {
        uint256 ethAmount = 1 ether;
        
        vm.prank(owner);
        optionToken.mint{value: ethAmount}();
        
        vm.prank(owner);
        optionToken.transfer(user1, ethAmount);
        
        uint256 usdtAmount = (ethAmount * STRIKE_PRICE / 10**18) / 2;
        vm.prank(owner);
        usdt.mint(user1, usdtAmount);
        
        vm.prank(user1);
        usdt.approve(address(optionToken), usdtAmount);
        
        vm.warp(exerciseDate);
        
        vm.expectRevert("Insufficient USDT");
        vm.prank(user1);
        optionToken.exercise(ethAmount);
    }
    
    function testExerciseInsufficientAllowance() public {
        uint256 ethAmount = 1 ether;
        
        vm.prank(owner);
        optionToken.mint{value: ethAmount}();
        
        vm.prank(owner);
        optionToken.transfer(user1, ethAmount);
        
        uint256 usdtAmount = ethAmount * STRIKE_PRICE / 10**18;
        vm.prank(owner);
        usdt.mint(user1, usdtAmount);
        
        vm.prank(user1);
        usdt.approve(address(optionToken), usdtAmount / 2);
        
        vm.warp(exerciseDate);
        
        vm.expectRevert("USDT allowance insufficient");
        vm.prank(user1);
        optionToken.exercise(ethAmount);
    }
    
    function testExpireBeforeExpiryDate() public {
        uint256 ethAmount = 1 ether;
        
        vm.prank(owner);
        optionToken.mint{value: ethAmount}();
        
        vm.expectRevert("Expiry date not passed");
        vm.prank(owner);
        optionToken.expire();
    }
    
    function testExpireAfterExpiryDate() public {
        uint256 ethAmount = 1 ether;
        
        vm.prank(owner);
        optionToken.mint{value: ethAmount}();
        
        vm.warp(expiryDate + 1 days);
        
        uint256 ownerEthBefore = owner.balance;
        
        vm.prank(owner);
        optionToken.expire();
        
        assertTrue(optionToken.isExpired());
        assertEq(optionToken.balanceOf(owner), 0);
        assertEq(optionToken.getEthBalance(), 0);
        assertEq(owner.balance, ownerEthBefore + ethAmount);
    }
    
    function testExpireAfterPartialExercise() public {
        uint256 ethAmount = 1 ether;
        uint256 exerciseAmount = 0.3 ether;
        uint256 remainingAmount = 0.7 ether;
        
        vm.prank(owner);
        optionToken.mint{value: ethAmount}();
        
        vm.prank(owner);
        optionToken.transfer(user1, ethAmount);
        
        uint256 usdtAmount = exerciseAmount * STRIKE_PRICE / 10**18;
        vm.prank(owner);
        usdt.mint(user1, usdtAmount);
        
        vm.prank(user1);
        usdt.approve(address(optionToken), usdtAmount);
        
        vm.warp(exerciseDate);
        
        vm.prank(user1);
        optionToken.exercise(exerciseAmount);
        
        vm.warp(expiryDate + 1 days);
        
        uint256 ownerEthBefore = owner.balance;
        
        vm.prank(owner);
        optionToken.expire();
        
        assertTrue(optionToken.isExpired());
        assertEq(owner.balance, ownerEthBefore + remainingAmount);
    }
    
    function testExpireByNonOwner() public {
        vm.warp(expiryDate + 1 days);
        
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        vm.prank(user1);
        optionToken.expire();
    }
    
    function testMintAfterExpire() public {
        vm.warp(expiryDate + 1 days);
        
        vm.prank(owner);
        optionToken.expire();
        
        vm.expectRevert("Option has expired");
        vm.prank(owner);
        optionToken.mint{value: 1 ether}();
    }
    
    function testExerciseAfterExpire() public {
        uint256 ethAmount = 1 ether;
        
        vm.prank(owner);
        optionToken.mint{value: ethAmount}();
        
        vm.prank(owner);
        optionToken.transfer(user1, ethAmount);
        
        vm.warp(expiryDate + 1 days);
        
        vm.prank(owner);
        optionToken.expire();
        
        vm.expectRevert("Option has expired");
        vm.prank(user1);
        optionToken.exercise(ethAmount);
    }
    
    function testTransferAfterExpire() public {
        uint256 ethAmount = 1 ether;
        
        vm.prank(owner);
        optionToken.mint{value: ethAmount}();
        
        vm.prank(owner);
        optionToken.transfer(user1, ethAmount);
        
        vm.warp(expiryDate + 1 days);
        
        vm.prank(owner);
        optionToken.expire();
        
        vm.expectRevert("Transfers disabled after expiry");
        vm.prank(user1);
        optionToken.transfer(user2, ethAmount / 2);
    }
    
    function testExerciseWith6DecimalsUSDT() public {
        MockUSDT6Decimals usdt6 = new MockUSDT6Decimals();
        uint256 ethAmount = 1 ether;
        
        vm.prank(owner);
        OptionToken optionToken6 = new OptionToken(
            STRIKE_PRICE, 
            exerciseDate, 
            expiryDate, 
            address(usdt6), 
            "ETH Call Option 6D", 
            "ETH-CALL-6D"
        );
        
        assertEq(optionToken6.paymentTokenDecimals(), 6);
        
        vm.prank(owner);
        optionToken6.mint{value: ethAmount}();
        
        vm.prank(owner);
        optionToken6.transfer(user1, ethAmount);
        
        uint256 usdtAmount = ethAmount * STRIKE_PRICE / 10**18;
        usdtAmount = usdtAmount * 10**6 / 10**18;
        
        vm.prank(owner);
        usdt6.mint(user1, usdtAmount);
        
        vm.prank(user1);
        usdt6.approve(address(optionToken6), usdtAmount);
        
        vm.warp(exerciseDate);
        
        uint256 user1EthBefore = user1.balance;
        
        vm.prank(user1);
        optionToken6.exercise(ethAmount);
        
        assertEq(optionToken6.balanceOf(user1), 0);
        assertEq(user1.balance, user1EthBefore + ethAmount);
    }
}