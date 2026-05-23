# Diswin - LOOK Token DeFi Platform

一个基于 BSC（币安智能链）的完整 DeFi 生态系统，包含 LOOK 代币、广告奖励系统和质押机制。

## 📋 项目概览

### LOOK 代币 (LookToken.sol)
- **总供应量**: 1亿枚
- **初始铸造**: 10%（1000万枚）给部署者
- **功能**: ERC-20 标准，支持铸造、销毁和暂停

### 广告奖励系统 (AdRewards.sol)
- **单个广告奖励**: 1 LOOK
- **每日限额**: 20 LOOK
- **特性**: 
  - 防止广告重复核销
  - 每日自动重置计数
  - 精确的奖励追踪

### 质押系统 (Staking.sol)
- **月化收益率**: 20%
- **12个质押等级**:
  ```
  Tier 1:  20 LOOK
  Tier 2:  50 LOOK
  Tier 3:  100 LOOK
  Tier 4:  200 LOOK
  Tier 5:  500 LOOK
  Tier 6:  1,000 LOOK
  Tier 7:  2,000 LOOK
  Tier 8:  3,000 LOOK
  Tier 9:  5,000 LOOK
  Tier 10: 10,000 LOOK
  Tier 11: 20,000 LOOK
  Tier 12: 30,000 LOOK
  ```
- **特性**:
  - 自动等级提升
  - 分月计算收益
  - 随时提取奖励
  - 灵活解除质押

## 🚀 快速开始

### 安装依赖

```bash
npm install
```

### 环境配置

创建 `.env` 文件（基于 `.env.example`）：

```bash
cp .env.example .env
```

编辑 `.env` 文件，填入您的私钥和 API 密钥：

```env
PRIVATE_KEY=your_private_key_here
BSC_TESTNET_RPC=https://data-seed-prebsc-1-b.binance.org:8545
BSC_MAINNET_RPC=https://bsc-dataseed.binance.org
BSCSCAN_API_KEY=your_bscscan_api_key_here
```

### 编译合约

```bash
npm run compile
```

### 运行测试

```bash
npm run test
```

### 部署到 BSC 测试网

```bash
npm run deploy:testnet
```

### 部署到 BSC 主网

```bash
npm run deploy:mainnet
```

## 📝 智能合约 API

### LOOK Token

#### 铸造
```solidity
mint(address to, uint256 amount) - 铸造新代币
```

#### 管理
```solidity
addMinter(address account) - 添加铸造者
removeMinter(address account) - 移除铸造者
pause() - 暂停转账
unpause() - 恢复转账
```

### 广告奖励 (AdRewards)

#### 核销广告
```solidity
watchAd(bytes32 adId) - 核销广告并获得奖励
```

#### 查询
```solidity
getRemainingDailyReward(address user) - 获取用户今日剩余可获奖励
getTodayClaimedAmount(address user) - 获取用户今日已获奖励
```

### 质押 (Staking)

#### 质押操作
```solidity
stake(uint256 amount) - 质押代币
unstake(uint256 amount) - 解除质押
claimReward() - 领取奖励
```

#### 查询
```solidity
getTierByAmount(uint256 amount) - 根据数量获取等级
getPendingReward(address user) - 获取待领奖励
getStakeInfo(address user) - 获取质押信息
```

#### 管理
```solidity
updateTier(uint8 tier, uint256 minAmount, bool enabled) - 更新等级配置
```

## 🧪 测试

项目包含完整的单元测试：

- `test/LookToken.test.js` - LOOK 代币测试
- `test/AdRewards.test.js` - 广告奖励系统测试
- `test/Staking.test.js` - 质押系统测试

运行所有测试：
```bash
npm run test
```

## 📂 项目结构

```
project/
├── contracts/
│   ├── LookToken.sol       # LOOK 代币合约
│   ├── AdRewards.sol       # 广告奖励合约
│   └── Staking.sol         # 质押合约
├── test/
│   ├── LookToken.test.js   # 代币测试
│   ├── AdRewards.test.js   # 广告奖励测试
│   └── Staking.test.js     # 质押测试
├── scripts/
│   └── deploy.js           # 部署脚本
├── hardhat.config.js       # Hardhat 配置
├── package.json            # NPM 配置
├── .env.example            # 环境变量模板
└── README.md               # 本文件
```

## 🔐 安全特性

- ✅ ReentrancyGuard 防止重入攻击
- ✅ OpenZeppelin 经过审计的代码库
- ✅ 完整的访问控制
- ✅ 参数验证
- ✅ 事件日志

## 🌐 网络配置

### BSC 测试网
- 链 ID: 97
- RPC: https://data-seed-prebsc-1-b.binance.org:8545
- 浏览器: https://testnet.bscscan.com

### BSC 主网
- 链 ID: 56
- RPC: https://bsc-dataseed.binance.org
- 浏览器: https://bscscan.com

## 📄 许可证

MIT License

## 👨‍💼 维护者

Diswin Development Team

## 🤝 贡献

欢迎提交 Pull Request 和 Issue！

## 📞 支持

如有问题，请在 GitHub Issues 中提出。
