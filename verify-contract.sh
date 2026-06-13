#!/bin/bash

# 验证 MyToken 合约地址

echo "=========================================="
echo "验证 MyToken 合约"
echo "=========================================="

# 检查合约地址是否正确
MY_TOKEN_ADDRESS="0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e"
RPC_URL="http://127.0.0.1:8545"

echo ""
echo "1. 检查合约是否存在..."
echo ""

# 检查合约代码
CODE=$(cast code $MY_TOKEN_ADDRESS --rpc-url $RPC_URL)

if [ "$CODE" = "0x" ]; then
    echo "❌ 合约不存在！地址 $MY_TOKEN_ADDRESS 没有合约代码"
    echo ""
    echo "需要重新部署合约："
    echo "forge script script/DeployTokenBank.s.sol --rpc-url $RPC_URL --broadcast"
else
    echo "✅ 合约存在"
    echo ""
    echo "2. 查询合约信息..."
    echo ""

    # 查询合约名称
    NAME=$(cast call $MY_TOKEN_ADDRESS "name()" --rpc-url $RPC_URL)
    echo "Name: $NAME"

    # 查询合约符号
    SYMBOL=$(cast call $MY_TOKEN_ADDRESS "symbol()" --rpc-url $RPC_URL)
    echo "Symbol: $SYMBOL"

    # 查询总供应量
    TOTAL_SUPPLY=$(cast call $MY_TOKEN_ADDRESS "totalSupply()" --rpc-url $RPC_URL)
    echo "Total Supply: $TOTAL_SUPPLY"

    # 查询部署者余额
    DEPLOYER="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    BALANCE=$(cast call $MY_TOKEN_ADDRESS "balanceOf(address)" $DEPLOYER --rpc-url $RPC_URL)
    echo "Deployer Balance: $BALANCE"

    echo ""
    echo "=========================================="
    echo ""
    echo "3. 查询最近转账事件..."
    echo ""

    # 查询最近区块的 Transfer 事件
    CURRENT_BLOCK=$(cast block-number --rpc-url $RPC_URL)
    echo "当前区块: $CURRENT_BLOCK"

    # 查询最近 10 个区块的 Transfer 事件
    FROM_BLOCK=$((CURRENT_BLOCK - 10))
    echo "查询区块范围: $FROM_BLOCK - $CURRENT_BLOCK"

    # 使用 cast logs 查询事件
    echo ""
    cast logs --address $MY_TOKEN_ADDRESS --rpc-url $RPC_URL --from-block $FROM_BLOCK --to-block $CURRENT_BLOCK
fi

echo ""
echo "=========================================="
echo "完成"
echo "=========================================="
