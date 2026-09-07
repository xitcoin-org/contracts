import { expect } from 'chai';
import { network } from 'hardhat';
const { ethers } = await network.create();

// Characterizes existing source permissions for the documentation. This is not
// a regression asserting that ownership unanimity is enforced or a code fix.
describe('Published legacy ownership policy', function () {
  it('allows the current owner to transfer ownership without voter approval', async function () {
    const [owner, a, b, c, nextOwner, outsider] = await ethers.getSigners();
    const implementation = await ethers.deployContract('XitcoinImplementation');
    const proxy = await ethers.deployContract('LegacyProxyFixture', [
      await implementation.getAddress(),
      implementation.interface.encodeFunctionData('initialize', [[a.address, b.address, c.address], 100])
    ]);
    const token = await ethers.getContractAt('XitcoinImplementation', await proxy.getAddress());
    await expect(token.connect(outsider).transferOwnership(nextOwner.address)).to.revert(ethers);
    expect(await token.ownerChangeVoteCount()).to.equal(0);
    await token.connect(owner).transferOwnership(nextOwner.address);
    expect(await token.owner()).to.equal(nextOwner.address);
    expect(await token.ownerChangeVoteCount()).to.equal(0);
    await expect(token.connect(owner).burn(1)).to.revert(ethers);
    await expect(token.connect(nextOwner).upgradeToAndCall(await implementation.getAddress(), '0x')).to.be.revertedWith('Unauthorized upgrade');
  });
});
