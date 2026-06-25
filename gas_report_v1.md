# NFTMarket Gas Report v1

## 部署成本

| 合约 | 部署成本 (Gas) | 部署大小 (Bytes) |
|------|---------------|------------------|
| DigitalAvatar | 2,269,301 | 11,255 |
| MarketToken | 2,542,721 | 13,493 |
| NFTMarket | 1,858,927 | 8,793 |

## NFTMarket 函数 Gas 消耗

| 函数名 | Min | Avg | Median | Max | 调用次数 |
|--------|-----|-----|--------|-----|----------|
| buyNFT | 24,522 | 70,501 | 69,566 | 118,352 | 4 |
| delist | 25,985 | 26,183 | 26,183 | 26,382 | 2 |
| getListing | 7,476 | 7,476 | 7,476 | 7,476 | 4 |
| list | 22,238 | 93,511 | 107,471 | 107,471 | 11 |
| setMarketToken | 29,001 | 29,001 | 29,001 | 29,001 | 1 |
| setNFTContract | 24,215 | 26,619 | 26,619 | 29,024 | 2 |

## 测试用例 Gas 消耗

| 测试用例 | Gas |
|----------|-----|
| testBuyNFT | 277,605 |
| testBuyWithOverpayment | 268,373 |
| testCannotBuyUnlistedNFT | 39,896 |
| testCannotBuyWithInsufficientPayment | 153,261 |
| testCannotListWithoutApproval | 80,636 |
| testCannotListZeroPrice | 35,702 |
| testCannotTransferInvalidData | 192,157 |
| testDelistNFT | 153,610 |
| testListNFT | 135,462 |
| testOnlyOwnerCanUpdateContracts | 94,512 |
| testOnlySellerCanDelist | 152,605 |
| testTransferAndCall | 270,302 |
| testTransferAndCallWithOverpayment | 260,294 |
