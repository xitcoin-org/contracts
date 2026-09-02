import { expect } from 'chai';
import { network } from 'hardhat';

import {
  TESTNET_ROUTE_ID,
  validateCronosTestnetPlan
} from '../scripts/lib/cronos-testnet-plan.js';

const { ethers } = await network.create();

describe('Cronos testnet deployment controls', function () {
  function input(overrides = {}) {
    return {
      chainId: 338,
      signers: [
        '0x1111111111111111111111111111111111111111',
        '0x2222222222222222222222222222222222222222',
        '0x3333333333333333333333333333333333333333'
      ],
      guardian: '0x4444444444444444444444444444444444444444',
      tokenRecipient: '0x5555555555555555555555555555555555555555',
      tokenSupply: '1000000',
      maxReleaseAmount: '100',
      dailyReleaseLimit: '500',
      ...overrides
    };
  }

  it('accepts only the isolated Cronos testnet plan', function () {
    const plan = validateCronosTestnetPlan(input());
    expect(plan.chainId).to.equal(338n);
    expect(plan.routeId).to.equal(TESTNET_ROUTE_ID);
    expect(plan.tokenSupply).to.equal(ethers.parseEther('1000000'));
  });

  it('rejects Cronos mainnet and noncanonical networks', function () {
    expect(() => validateCronosTestnetPlan(input({ chainId: 25 })))
      .to.throw('must be 338');
    expect(() => validateCronosTestnetPlan(input({ chainId: 101089 })))
      .to.throw('must be 338');
  });

  it('rejects shared authority, invalid recipients and unsafe limits', function () {
    expect(() => validateCronosTestnetPlan(input({
      guardian: '0x1111111111111111111111111111111111111111'
    }))).to.throw('separate');
    expect(() => validateCronosTestnetPlan(input({
      tokenRecipient: ethers.ZeroAddress
    }))).to.throw('zero or dead');
    expect(() => validateCronosTestnetPlan(input({
      maxReleaseAmount: '501'
    }))).to.throw('must not exceed');
  });

  it('deploys a fixed-supply tXTC asset and compatible vault locally', async function () {
    const [recipient, signerOne, signerTwo, signerThree, guardian] =
      await ethers.getSigners();
    const Token = await ethers.getContractFactory('XitcoinTestnetToken');
    const token = await Token.deploy(recipient.address, ethers.parseEther('1000'));
    const Vault = await ethers.getContractFactory('CronosBridgeVault');
    const vault = await Vault.deploy(
      await token.getAddress(),
      TESTNET_ROUTE_ID,
      [signerOne.address, signerTwo.address, signerThree.address],
      guardian.address,
      ethers.parseEther('10'),
      ethers.parseEther('50')
    );
    expect(await token.symbol()).to.equal('tXTC');
    expect(await token.totalSupply()).to.equal(ethers.parseEther('1000'));
    expect(await vault.asset()).to.equal(await token.getAddress());
    expect(await vault.routeId()).to.equal(TESTNET_ROUTE_ID);
  });
});
