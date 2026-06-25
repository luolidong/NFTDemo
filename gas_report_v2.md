# NFTMarket Gas Report v2 (Optimized)

## 部署成本

| 合约 | 部署成本 (Gas) | 部署大小 (Bytes) |
|------|---------------|------------------|
| DigitalAvatar | 2,269,301 | 11,255 |
| MarketToken | 2,542,721 | 13,493 |
| NFTMarketOptimized | 1,642,102 | 8,062 |

## NFTMarketOptimized 函数 Gas 消耗

| 函数名 | Min | Avg | Median | Max | 调用次数 |
|--------|-----|-----|--------|-----|----------|
| buyNFT | 24,532 | 67,182 | 65,861 | 112,474 | 4 |
| delist | 24,376 | 26,540 | 26,540 | 28,704 | 2 |
| getListing | 3,426 | 3,426 | 3,426 | 3,426 | 4 |
| list | 22,250 | 55,454 | 61,221 | 61,221 | 11 |

## 测试用例 Gas 消耗

| 测试用例 | Gas |
|----------|-----|
| testBuyNFT | 226,947 |
| testBuyWithOverpayment | 221,211 |
| testCannotBuyUnlistedNFT | 40,051 |
| testCannotBuyWithInsufficientPayment | 105,281 |
| testCannotListWithoutApproval | 78,262 |
| testCannotListZeroPrice | 35,698 |
| testCannotTransferInvalidData | 143,980 |
| testDelistNFT | 110,870 |
| testListNFT | 85,244 |
| testOnlySellerCanDelist | 104,390 |
| testTransferAndCall | 219,574 |
| testTransferAndCallWithOverpayment | 213,015 |
