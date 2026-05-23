require('dotenv').config();
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-ethers');
require('@nomiclabs/hardhat-etherscan');

const PRIVATE_KEY = process.env.PRIVATE_KEY || '0x0000000000000000000000000000000000000000000000000000000000000000';
const BSC_TESTNET_RPC = process.env.BSC_TESTNET_RPC || 'https://data-seed-prebsc-1-b.binance.org:8545';
const BSC_MAINNET_RPC = process.env.BSC_MAINNET_RPC || 'https://bsc-dataseed.binance.org';
const BSCSCAN_API_KEY = process.env.BSCSCAN_API_KEY || '';

module.exports = {
  solidity: {
    version: '0.8.19',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {},
    bscTestnet: {
      url: BSC_TESTNET_RPC,
      chainId: 97,
      gasPrice: 10e9,
      accounts: [PRIVATE_KEY],
    },
    bsc: {
      url: BSC_MAINNET_RPC,
      chainId: 56,
      gasPrice: 5e9,
      accounts: [PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: BSCSCAN_API_KEY,
  },
  paths: {
    sources: './contracts',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts',
  },
};
