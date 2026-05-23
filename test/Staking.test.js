const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('Staking', function () {
  let lookToken;
  let staking;
  let owner;
  let user1;
  let user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // 部署LOOK代币
    const LookToken = await ethers.getContractFactory('LookToken');
    lookToken = await LookToken.deploy();
    await lookToken.deployed();

    // 部署质押合约
    const Staking = await ethers.getContractFactory('Staking');
    staking = await Staking.deploy(lookToken.address);
    await staking.deployed();

    // 将代币分配给用户
    const distributeAmount = ethers.utils.parseEther('100000');
    await lookToken.transfer(user1.address, distributeAmount);
    await lookToken.transfer(user2.address, distributeAmount);

    // 用户授权合约转账代币
    await lookToken.connect(user1).approve(staking.address, ethers.constants.MaxUint256);
    await lookToken.connect(user2).approve(staking.address, ethers.constants.MaxUint256);
  });

  describe('Deployment', function () {
    it('Should set correct LOOK token address', async function () {
      expect(await staking.lookToken()).to.equal(lookToken.address);
    });

    it('Should initialize all 12 tiers', async function () {
      const expectedMinAmounts = [
        20, 50, 100, 200, 500, 1000, 2000, 3000, 5000, 10000, 20000, 30000,
      ];

      for (let i = 1; i <= 12; i++) {
        const tier = await staking.tiers(i);
        expect(tier.enabled).to.be.true;
        expect(tier.minAmount).to.equal(ethers.utils.parseEther(expectedMinAmounts[i - 1].toString()));
      }
    });
  });

  describe('Tier Management', function () {
    it('Should determine correct tier by amount', async function () {
      expect(await staking.getTierByAmount(ethers.utils.parseEther('20'))).to.equal(1);
      expect(await staking.getTierByAmount(ethers.utils.parseEther('50'))).to.equal(2);
      expect(await staking.getTierByAmount(ethers.utils.parseEther('100'))).to.equal(3);
      expect(await staking.getTierByAmount(ethers.utils.parseEther('30000'))).to.equal(12);
    });

    it('Should revert if amount does not meet minimum', async function () {
      await expect(staking.getTierByAmount(ethers.utils.parseEther('10'))).to.be.revertedWith(
        'Amount does not meet minimum requirement'
      );
    });
  });

  describe('Staking', function () {
    it('User can stake tokens', async function () {
      const stakeAmount = ethers.utils.parseEther('100');
      await staking.connect(user1).stake(stakeAmount);

      const stakeInfo = await staking.getStakeInfo(user1.address);
      expect(stakeInfo.amount).to.equal(stakeAmount);
      expect(stakeInfo.tier).to.equal(3); // 100个对应Tier 3
    });

    it('Should reject zero stake amount', async function () {
      await expect(staking.connect(user1).stake(0)).to.be.revertedWith(
        'Stake amount must be greater than 0'
      );
    });

    it('Should reject amount below minimum', async function () {
      await expect(staking.connect(user1).stake(ethers.utils.parseEther('10'))).to.be.revertedWith(
        'Amount does not meet minimum requirement'
      );
    });

    it('User can add to existing stake', async function () {
      const stakeAmount1 = ethers.utils.parseEther('100');
      const stakeAmount2 = ethers.utils.parseEther('100');

      await staking.connect(user1).stake(stakeAmount1);
      await staking.connect(user1).stake(stakeAmount2);

      const stakeInfo = await staking.getStakeInfo(user1.address);
      expect(stakeInfo.amount).to.equal(stakeAmount1.add(stakeAmount2));
    });
  });

  describe('Unstaking', function () {
    it('User can unstake tokens', async function () {
      const stakeAmount = ethers.utils.parseEther('100');
      await staking.connect(user1).stake(stakeAmount);

      const unstakeAmount = ethers.utils.parseEther('50');
      await staking.connect(user1).unstake(unstakeAmount);

      const stakeInfo = await staking.getStakeInfo(user1.address);
      expect(stakeInfo.amount).to.equal(stakeAmount.sub(unstakeAmount));
    });

    it('Should reject unstaking more than staked', async function () {
      const stakeAmount = ethers.utils.parseEther('100');
      await staking.connect(user1).stake(stakeAmount);

      const unstakeAmount = ethers.utils.parseEther('200');
      await expect(staking.connect(user1).unstake(unstakeAmount)).to.be.revertedWith(
        'Invalid unstake amount'
      );
    });
  });

  describe('Rewards', function () {
    it('Should calculate pending rewards correctly', async function () {
      const stakeAmount = ethers.utils.parseEther('1000');
      await staking.connect(user1).stake(stakeAmount);

      // 快进30天（1个月）
      await ethers.provider.send('hardhat_mine', ['0x15180']); // 大约30天的区块

      const pending = await staking.getPendingReward(user1.address);
      // 预期奖励: 1000 * 20% = 200
      expect(pending).to.be.gt(0);
    });

    it('User can claim rewards', async function () {
      const stakeAmount = ethers.utils.parseEther('1000');
      await staking.connect(user1).stake(stakeAmount);

      // 快进30天
      await ethers.provider.send('hardhat_mine', ['0x15180']);

      const initialBalance = await lookToken.balanceOf(user1.address);
      await staking.connect(user1).claimReward();
      const finalBalance = await lookToken.balanceOf(user1.address);

      expect(finalBalance).to.be.gt(initialBalance);
    });
  });

  describe('Contract Management', function () {
    it('Owner can update tier', async function () {
      const newMinAmount = ethers.utils.parseEther('25');
      await staking.updateTier(1, newMinAmount, true);

      const tier = await staking.tiers(1);
      expect(tier.minAmount).to.equal(newMinAmount);
    });

    it('Owner can disable tier', async function () {
      await staking.updateTier(1, ethers.utils.parseEther('20'), false);
      const tier = await staking.tiers(1);
      expect(tier.enabled).to.be.false;
    });

    it('Should get correct contract balance', async function () {
      const stakeAmount = ethers.utils.parseEther('100');
      await staking.connect(user1).stake(stakeAmount);

      const contractBalance = await staking.getContractBalance();
      expect(contractBalance).to.be.gte(stakeAmount);
    });
  });
});
