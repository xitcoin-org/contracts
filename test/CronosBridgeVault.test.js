'use strict';

const { expect } = require('chai');
const { ethers } = require('hardhat');
const {
  anyValue
} = require('@nomicfoundation/hardhat-chai-matchers/withArgs');

describe('CronosBridgeVault', function () {
  const routeId = ethers.id('XTC:CRONOS:25:XITCOIN');
  const maxRelease = ethers.parseEther('100');
  const dailyLimit = ethers.parseEther('150');
  const deadAddress = '0x000000000000000000000000000000000000dEaD';

  let deployer;
  let user;
  let recipient;
  let signerOne;
  let signerTwo;
  let signerThree;
  let guardian;
  let outsider;
  let replacementOne;
  let replacementTwo;
  let replacementThree;
  let token;
  let vault;

  async function deadline(offset = 3600n) {
    const block = await ethers.provider.getBlock('latest');
    return BigInt(block.timestamp) + offset;
  }

  async function domain(target = vault) {
    const network = await ethers.provider.getNetwork();
    return {
      name: 'Xitcoin Cronos Bridge Vault',
      version: '1',
      chainId: network.chainId,
      verifyingContract: await target.getAddress()
    };
  }

  const releaseTypes = {
    Release: [
      { name: 'sourceBurnId', type: 'bytes32' },
      { name: 'recipient', type: 'address' },
      { name: 'amount', type: 'uint256' },
      { name: 'signerSetVersion', type: 'uint64' },
      { name: 'deadline', type: 'uint256' }
    ]
  };

  const controlTypes = {
    Control: [
      { name: 'action', type: 'bytes32' },
      { name: 'payloadHash', type: 'bytes32' },
      { name: 'nonce', type: 'uint256' },
      { name: 'signerSetVersion', type: 'uint64' },
      { name: 'deadline', type: 'uint256' }
    ]
  };

  async function signRelease({
    sourceBurnId,
    to = recipient.address,
    amount = ethers.parseEther('10'),
    version = 1n,
    expires,
    signers = [signerOne, signerTwo],
    target = vault
  }) {
    const expiry = expires ?? await deadline();
    const value = {
      sourceBurnId,
      recipient: to,
      amount,
      signerSetVersion: version,
      deadline: expiry
    };
    const signingDomain = await domain(target);
    const signatures = [];
    for (const signer of signers) {
      signatures.push(
        await signer.signTypedData(signingDomain, releaseTypes, value)
      );
    }
    return { expiry, signatures };
  }

  async function signControl({
    action,
    payloadHash = ethers.ZeroHash,
    nonce,
    version,
    expires,
    signers = [signerOne, signerTwo]
  }) {
    const controlNonce = nonce ?? await vault.governanceNonce();
    const signerVersion = version ?? await vault.signerSetVersion();
    const expiry = expires ?? await deadline();
    const value = {
      action,
      payloadHash,
      nonce: controlNonce,
      signerSetVersion: signerVersion,
      deadline: expiry
    };
    const signingDomain = await domain();
    const signatures = [];
    for (const signer of signers) {
      signatures.push(
        await signer.signTypedData(signingDomain, controlTypes, value)
      );
    }
    return {
      nonce: controlNonce,
      expiry,
      signatures
    };
  }

  beforeEach(async function () {
    [
      deployer,
      user,
      recipient,
      signerOne,
      signerTwo,
      signerThree,
      guardian,
      outsider,
      replacementOne,
      replacementTwo,
      replacementThree
    ] = await ethers.getSigners();

    const Token = await ethers.getContractFactory('MockERC20');
    token = await Token.deploy('Xitcoin', 'XTC');

    const Vault = await ethers.getContractFactory('CronosBridgeVault');
    vault = await Vault.deploy(
      await token.getAddress(),
      routeId,
      [signerOne.address, signerTwo.address, signerThree.address],
      guardian.address,
      maxRelease,
      dailyLimit
    );

    await token.mint(user.address, ethers.parseEther('1000'));
    await token.mint(await vault.getAddress(), ethers.parseEther('500'));
  });

  describe('deployment', function () {
    it('stores the canonical asset, route, signer set and limits', async function () {
      expect(await vault.asset()).to.equal(await token.getAddress());
      expect(await vault.routeId()).to.equal(routeId);
      expect(await vault.signers()).to.deep.equal([
        signerOne.address,
        signerTwo.address,
        signerThree.address
      ]);
      expect(await vault.signerSetVersion()).to.equal(1n);
      expect(await vault.guardian()).to.equal(guardian.address);
      expect(await vault.maxReleaseAmount()).to.equal(maxRelease);
      expect(await vault.dailyReleaseLimit()).to.equal(dailyLimit);
    });

    it('rejects duplicate signers', async function () {
      const Vault = await ethers.getContractFactory('CronosBridgeVault');
      await expect(
        Vault.deploy(
          await token.getAddress(),
          routeId,
          [signerOne.address, signerOne.address, signerThree.address],
          guardian.address,
          maxRelease,
          dailyLimit
        )
      ).to.be.revertedWithCustomError(vault, 'InvalidSignerSet');
    });

    it('rejects inconsistent limits', async function () {
      const Vault = await ethers.getContractFactory('CronosBridgeVault');
      await expect(
        Vault.deploy(
          await token.getAddress(),
          routeId,
          [signerOne.address, signerTwo.address, signerThree.address],
          guardian.address,
          dailyLimit + 1n,
          dailyLimit
        )
      ).to.be.revertedWithCustomError(vault, 'InvalidAmount');
    });
  });

  describe('deposits', function () {
    it('locks the exact amount and emits a unique deposit identifier', async function () {
      const amount = ethers.parseEther('25');
      await token.connect(user).approve(await vault.getAddress(), amount);

      const transaction = vault.connect(user).deposit(amount, recipient.address);
      await expect(transaction)
        .to.emit(vault, 'Deposited')
        .withArgs(
          anyValue,
          routeId,
          user.address,
          recipient.address,
          amount,
          1n
        );

      expect(await vault.depositNonce()).to.equal(1n);
      expect(await token.balanceOf(await vault.getAddress())).to.equal(
        ethers.parseEther('525')
      );
    });

    it('rejects zero and dead recipients', async function () {
      const amount = ethers.parseEther('1');
      await token.connect(user).approve(await vault.getAddress(), amount * 2n);

      await expect(
        vault.connect(user).deposit(amount, ethers.ZeroAddress)
      ).to.be.revertedWithCustomError(vault, 'InvalidAddress');
      await expect(
        vault.connect(user).deposit(amount, deadAddress)
      ).to.be.revertedWithCustomError(vault, 'InvalidAddress');
    });
  });

  describe('releases', function () {
    it('releases XTC after two distinct signer approvals', async function () {
      const sourceBurnId = ethers.id('xitcoin-burn-1');
      const amount = ethers.parseEther('10');
      const { expiry, signatures } = await signRelease({
        sourceBurnId,
        amount
      });

      await expect(
        vault.release(
          sourceBurnId,
          recipient.address,
          amount,
          1,
          expiry,
          signatures
        )
      )
        .to.emit(vault, 'Released')
        .withArgs(sourceBurnId, recipient.address, amount, 1n);

      expect(await token.balanceOf(recipient.address)).to.equal(amount);
      expect(await vault.processedBurns(sourceBurnId)).to.equal(true);
    });

    it('rejects one signature, duplicates and non-signers', async function () {
      const sourceBurnId = ethers.id('xitcoin-burn-quorum');
      const amount = ethers.parseEther('5');

      const one = await signRelease({
        sourceBurnId,
        amount,
        signers: [signerOne]
      });
      await expect(
        vault.release(
          sourceBurnId,
          recipient.address,
          amount,
          1,
          one.expiry,
          one.signatures
        )
      ).to.be.revertedWithCustomError(vault, 'InsufficientSignatures');

      await expect(
        vault.release(
          sourceBurnId,
          recipient.address,
          amount,
          1,
          one.expiry,
          [one.signatures[0], one.signatures[0]]
        )
      ).to.be.revertedWithCustomError(vault, 'DuplicateSignature');

      const unauthorized = await signRelease({
        sourceBurnId,
        amount,
        signers: [signerOne, outsider]
      });
      await expect(
        vault.release(
          sourceBurnId,
          recipient.address,
          amount,
          1,
          unauthorized.expiry,
          unauthorized.signatures
        )
      ).to.be.revertedWithCustomError(vault, 'UnauthorizedSigner');
    });

    it('rejects replay, expired approvals and the wrong signer-set version', async function () {
      const sourceBurnId = ethers.id('xitcoin-burn-replay');
      const amount = ethers.parseEther('5');
      const signed = await signRelease({ sourceBurnId, amount });

      await vault.release(
        sourceBurnId,
        recipient.address,
        amount,
        1,
        signed.expiry,
        signed.signatures
      );
      await expect(
        vault.release(
          sourceBurnId,
          recipient.address,
          amount,
          1,
          signed.expiry,
          signed.signatures
        )
      ).to.be.revertedWithCustomError(vault, 'BurnAlreadyProcessed');

      const expiredId = ethers.id('xitcoin-burn-expired');
      const expired = await signRelease({
        sourceBurnId: expiredId,
        amount,
        expires: 1n
      });
      await expect(
        vault.release(
          expiredId,
          recipient.address,
          amount,
          1,
          expired.expiry,
          expired.signatures
        )
      ).to.be.revertedWithCustomError(vault, 'SignatureExpired');

      await expect(
        vault.release(
          ethers.id('wrong-version'),
          recipient.address,
          amount,
          2,
          signed.expiry,
          signed.signatures
        )
      ).to.be.revertedWithCustomError(vault, 'InvalidSignerSetVersion');
    });

    it('enforces per-release, daily and liquidity limits', async function () {
      const overMaximum = maxRelease + 1n;
      const overMaximumSigned = await signRelease({
        sourceBurnId: ethers.id('over-maximum'),
        amount: overMaximum
      });
      await expect(
        vault.release(
          ethers.id('over-maximum'),
          recipient.address,
          overMaximum,
          1,
          overMaximumSigned.expiry,
          overMaximumSigned.signatures
        )
      ).to.be.revertedWithCustomError(vault, 'ReleaseLimitExceeded');

      const firstId = ethers.id('daily-one');
      const first = await signRelease({
        sourceBurnId: firstId,
        amount: maxRelease
      });
      await vault.release(
        firstId,
        recipient.address,
        maxRelease,
        1,
        first.expiry,
        first.signatures
      );

      const secondAmount = ethers.parseEther('51');
      const secondId = ethers.id('daily-two');
      const second = await signRelease({
        sourceBurnId: secondId,
        amount: secondAmount
      });
      await expect(
        vault.release(
          secondId,
          recipient.address,
          secondAmount,
          1,
          second.expiry,
          second.signatures
        )
      ).to.be.revertedWithCustomError(vault, 'DailyLimitExceeded');
    });

    it('binds approvals to the vault address', async function () {
      const Vault = await ethers.getContractFactory('CronosBridgeVault');
      const secondVault = await Vault.deploy(
        await token.getAddress(),
        routeId,
        [signerOne.address, signerTwo.address, signerThree.address],
        guardian.address,
        maxRelease,
        dailyLimit
      );
      await token.mint(await secondVault.getAddress(), ethers.parseEther('20'));

      const sourceBurnId = ethers.id('domain-bound');
      const amount = ethers.parseEther('1');
      const signedForFirstVault = await signRelease({ sourceBurnId, amount });

      await expect(
        secondVault.release(
          sourceBurnId,
          recipient.address,
          amount,
          1,
          signedForFirstVault.expiry,
          signedForFirstVault.signatures
        )
      ).to.be.revertedWithCustomError(secondVault, 'UnauthorizedSigner');
    });
  });

  describe('emergency and governance controls', function () {
    it('allows only the guardian to pause and requires quorum to resume', async function () {
      await expect(vault.connect(outsider).pause())
        .to.be.revertedWithCustomError(vault, 'UnauthorizedGuardian');

      await expect(vault.connect(guardian).pause())
        .to.emit(vault, 'VaultPaused')
        .withArgs(guardian.address);

      const resume = await signControl({ action: await vault.ACTION_RESUME() });
      await expect(
        vault.resume(resume.nonce, resume.expiry, resume.signatures)
      )
        .to.emit(vault, 'VaultResumed')
        .withArgs(0n);

      expect(await vault.paused()).to.equal(false);
      expect(await vault.governanceNonce()).to.equal(1n);
    });

    it('rotates the signer set and invalidates old approvals', async function () {
      const newSigners = [
        replacementOne.address,
        replacementTwo.address,
        replacementThree.address
      ];
      const payloadHash = ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(
          ['address[3]'],
          [newSigners]
        )
      );
      const rotation = await signControl({
        action: await vault.ACTION_ROTATE_SIGNERS(),
        payloadHash
      });

      await vault.rotateSigners(
        newSigners,
        rotation.nonce,
        rotation.expiry,
        rotation.signatures
      );

      expect(await vault.signerSetVersion()).to.equal(2n);
      expect(await vault.isSigner(signerOne.address)).to.equal(false);
      expect(await vault.isSigner(replacementOne.address)).to.equal(true);

      const sourceBurnId = ethers.id('post-rotation');
      const amount = ethers.parseEther('1');
      const oldSigners = await signRelease({
        sourceBurnId,
        amount,
        version: 2n,
        signers: [signerOne, signerTwo]
      });
      await expect(
        vault.release(
          sourceBurnId,
          recipient.address,
          amount,
          2,
          oldSigners.expiry,
          oldSigners.signatures
        )
      ).to.be.revertedWithCustomError(vault, 'UnauthorizedSigner');

      const newApprovals = await signRelease({
        sourceBurnId,
        amount,
        version: 2n,
        signers: [replacementOne, replacementTwo]
      });
      await vault.release(
        sourceBurnId,
        recipient.address,
        amount,
        2,
        newApprovals.expiry,
        newApprovals.signatures
      );
    });

    it('updates release limits only after a valid quorum action', async function () {
      const newMaximum = ethers.parseEther('200');
      const newDaily = ethers.parseEther('500');
      const payloadHash = ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(
          ['uint256', 'uint256'],
          [newMaximum, newDaily]
        )
      );
      const control = await signControl({
        action: await vault.ACTION_UPDATE_LIMITS(),
        payloadHash
      });

      await vault.updateLimits(
        newMaximum,
        newDaily,
        control.nonce,
        control.expiry,
        control.signatures
      );

      expect(await vault.maxReleaseAmount()).to.equal(newMaximum);
      expect(await vault.dailyReleaseLimit()).to.equal(newDaily);
    });

    it('rejects governance nonce replay', async function () {
      await vault.connect(guardian).pause();
      const resume = await signControl({ action: await vault.ACTION_RESUME() });
      await vault.resume(resume.nonce, resume.expiry, resume.signatures);
      await vault.connect(guardian).pause();

      await expect(
        vault.resume(resume.nonce, resume.expiry, resume.signatures)
      ).to.be.revertedWithCustomError(vault, 'InvalidNonce');
    });
  });

  describe('asset isolation', function () {
    it('forbids rescue of canonical XTC', async function () {
      await expect(
        vault.rescueForeignToken(
          await token.getAddress(),
          recipient.address,
          1,
          0,
          await deadline(),
          []
        )
      ).to.be.revertedWithCustomError(
        vault,
        'CanonicalAssetRescueForbidden'
      );
    });

    it('recovers only unrelated tokens after quorum approval', async function () {
      const Token = await ethers.getContractFactory('MockERC20');
      const foreignToken = await Token.deploy('Foreign', 'FRN');
      const amount = ethers.parseEther('7');
      await foreignToken.mint(await vault.getAddress(), amount);

      const payloadHash = ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(
          ['address', 'address', 'uint256'],
          [await foreignToken.getAddress(), recipient.address, amount]
        )
      );
      const control = await signControl({
        action: await vault.ACTION_RESCUE_FOREIGN_TOKEN(),
        payloadHash
      });

      await vault.rescueForeignToken(
        await foreignToken.getAddress(),
        recipient.address,
        amount,
        control.nonce,
        control.expiry,
        control.signatures
      );

      expect(await foreignToken.balanceOf(recipient.address)).to.equal(amount);
      expect(await token.balanceOf(await vault.getAddress())).to.equal(
        ethers.parseEther('500')
      );
    });
  });
});
