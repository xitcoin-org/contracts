import { configVariable, defineConfig } from 'hardhat/config';
import hardhatEthers from '@nomicfoundation/hardhat-ethers';
import hardhatEthersChaiMatchers from '@nomicfoundation/hardhat-ethers-chai-matchers';
import hardhatMocha from '@nomicfoundation/hardhat-mocha';

export default defineConfig({
  plugins: [hardhatEthers, hardhatEthersChaiMatchers, hardhatMocha],
  solidity: {
    compilers: [
      {
        version: '0.8.4',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
      {
        version: '0.8.30',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          },
          evmVersion: 'paris',
          metadata: {
            bytecodeHash: 'none'
          }
        }
      }
    ]
  },
  networks: {
    cronosTestnet: {
      type: 'http',
      chainType: 'l1',
      chainId: 338,
      url: configVariable('CRONOS_TESTNET_RPC_URL'),
      accounts: [configVariable('CRONOS_TESTNET_DEPLOYER_KEY')]
    }
  },
  paths: {
    sources: './contracts',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts'
  },
  test: {
    mocha: {
      timeout: 120000
    }
  }
});
