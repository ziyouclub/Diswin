const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('LOOK Token', function () {
  let lookToken;
  let owner;
  let addr1;
  let addr2;

  beforeEach(async function () {
    const LookToken = await ethers.getContractFactory('LookToken');
    lookToken = await LookToken.deploy();
    await lookToken.deployed();

    [owner, addr1, addr2] = await ethers.getSigners();
  });

  describe('Deployment', function () {
    it('Should have correct name and symbol', async function () {
      expect(await lookToken.name()).to.equal('LOOK');
      expect(await lookToken.symbol()).to.equal('LOOK');
    });

    it('Should mint initial supply to owner', async function () {
      const initialSupply = ethers.utils.parseEther('10000000'); // 1000万
      const balance = await lookToken.balanceOf(owner.address);
      expect(balance).to.equal(initialSupply);
    });

    it('Owner should be a minter', async function () {
      expect(await lookToken.minters(owner.address)).to.be.true;
    });
  });

  describe('Minter Management', function () {
    it('Should add minter', async function () {
      await lookToken.addMinter(addr1.address);
      expect(await lookToken.minters(addr1.address)).to.be.true;
    });

    it('Should remove minter', async function () {
      await lookToken.addMinter(addr1.address);
      await lookToken.removeMinter(addr1.address);
      expect(await lookToken.minters(addr1.address)).to.be.false;
    });

    it('Should not add zero address as minter', async function () {
      await expect(lookToken.addMinter(ethers.constants.AddressZero)).to.be.revertedWith(
        'Cannot add zero address as minter'
      );
    });
  });

  describe('Minting', function () {
    it('Owner can mint tokens', async function () {
      const mintAmount = ethers.utils.parseEther('1000');
      await lookToken.mint(addr1.address, mintAmount);
      const balance = await lookToken.balanceOf(addr1.address);
      expect(balance).to.equal(mintAmount);
    });

    it('Non-minter cannot mint', async function () {
      const mintAmount = ethers.utils.parseEther('1000');
      await expect(
        lookToken.connect(addr1).mint(addr1.address, mintAmount)
      ).to.be.revertedWith('Only minters can mint');
    });

    it('Minter can mint tokens after being added', async function () {
      await lookToken.addMinter(addr1.address);
      const mintAmount = ethers.utils.parseEther('1000');
      await lookToken.connect(addr1).mint(addr2.address, mintAmount);
      const balance = await lookToken.balanceOf(addr2.address);
      expect(balance).to.equal(mintAmount);
    });
  });

  describe('Pause', function () {
    it('Owner can pause transfers', async function () {
      await lookToken.pause();
      const transferAmount = ethers.utils.parseEther('100');
      await expect(
        lookToken.transfer(addr1.address, transferAmount)
      ).to.be.revertedWith('Pausable: paused');
    });

    it('Owner can unpause transfers', async function () {
      await lookToken.pause();
      await lookToken.unpause();
      const transferAmount = ethers.utils.parseEther('100');
      await expect(lookToken.transfer(addr1.address, transferAmount)).not.to.be.reverted;
    });
  });

  describe('Transfer', function () {
    it('Should transfer tokens between accounts', async function () {
      const transferAmount = ethers.utils.parseEther('100');
      await lookToken.transfer(addr1.address, transferAmount);
      const balance = await lookToken.balanceOf(addr1.address);
      expect(balance).to.equal(transferAmount);
    });
  });

  describe('Burn', function () {
    it('User can burn their tokens', async function () {
      const burnAmount = ethers.utils.parseEther('100');
      await lookToken.transfer(addr1.address, burnAmount);
      await lookToken.connect(addr1).burn(burnAmount);
      const balance = await lookToken.balanceOf(addr1.address);
      expect(balance).to.equal(0);
    });
  });
});
