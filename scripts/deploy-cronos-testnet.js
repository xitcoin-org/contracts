import { mkdir, open } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';

import { network } from 'hardhat';

import {
  CRONOS_TESTNET_CHAIN_ID,
  validateCronosTestnetPlan
} from './lib/cronos-testnet-plan.js';

function required(name) {
  const value = String(process.env[name] ?? '').trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

const { ethers } = await network.connect('cronosTestnet');
const currentNetwork = await ethers.provider.getNetwork();
if (currentNetwork.chainId !== CRONOS_TESTNET_CHAIN_ID) {
  throw new Error(
    `refusing deployment on chain ID ${currentNetwork.chainId}; Cronos testnet 338 is required`
  );
}

const [deployer] = await ethers.getSigners();
const plan = validateCronosTestnetPlan({
  chainId: currentNetwork.chainId,
  signers: [
    required('BRIDGE_TESTNET_SIGNER_1'),
    required('BRIDGE_TESTNET_SIGNER_2'),
    required('BRIDGE_TESTNET_SIGNER_3')
  ],
  guardian: required('BRIDGE_TESTNET_GUARDIAN'),
  tokenRecipient: process.env.BRIDGE_TESTNET_TOKEN_RECIPIENT || deployer.address,
  tokenSupply: process.env.BRIDGE_TESTNET_TOKEN_SUPPLY || '1000000',
  maxReleaseAmount: process.env.BRIDGE_TESTNET_MAX_RELEASE || '100',
  dailyReleaseLimit: process.env.BRIDGE_TESTNET_DAILY_LIMIT || '500'
});

const balance = await ethers.provider.getBalance(deployer.address);
if (balance === 0n) throw new Error('Cronos testnet deployer has no tCRO for gas');

const Token = await ethers.getContractFactory('XitcoinTestnetToken');
const token = await Token.deploy(plan.tokenRecipient, plan.tokenSupply);
await token.waitForDeployment();
const tokenDeployment = token.deploymentTransaction();
const tokenReceipt = await tokenDeployment.wait();

const Vault = await ethers.getContractFactory('CronosBridgeVault');
const vault = await Vault.deploy(
  await token.getAddress(),
  plan.routeId,
  plan.signers,
  plan.guardian,
  plan.maxReleaseAmount,
  plan.dailyReleaseLimit
);
await vault.waitForDeployment();
const vaultDeployment = vault.deploymentTransaction();
const vaultReceipt = await vaultDeployment.wait();

const deployed = Object.freeze({
  schema_version: 1,
  environment: 'isolated-testnet',
  network: 'Cronos EVM Testnet',
  chain_id: Number(plan.chainId),
  xitcoin_chain_id: 'xitcoin-testnet-v2-1',
  route_label: plan.routeLabel,
  route_id: plan.routeId,
  deployer: deployer.address,
  contracts: {
    test_token: {
      address: await token.getAddress(),
      symbol: 'tXTC',
      deployment_transaction: tokenDeployment.hash,
      deployment_block: tokenReceipt.blockNumber
    },
    bridge_vault: {
      address: await vault.getAddress(),
      deployment_transaction: vaultDeployment.hash,
      deployment_block: vaultReceipt.blockNumber,
      signer_set_version: '1',
      signers: plan.signers,
      guardian: plan.guardian,
      max_release_amount: plan.maxReleaseAmount.toString(),
      daily_release_limit: plan.dailyReleaseLimit.toString()
    }
  }
});

const output = resolve(
  process.env.CRONOS_TESTNET_DEPLOYMENT_OUTPUT ||
    'deployments/generated/cronos-testnet.json'
);
await mkdir(dirname(output), { recursive: true, mode: 0o700 });
const handle = await open(output, 'wx', 0o600);
try {
  await handle.writeFile(`${JSON.stringify(deployed, null, 2)}\n`);
} finally {
  await handle.close();
}

console.log(`Cronos testnet deployment recorded at ${output}`);
console.log(`test_token=${deployed.contracts.test_token.address}`);
console.log(`bridge_vault=${deployed.contracts.bridge_vault.address}`);
