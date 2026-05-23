const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('AdRewards', function () {
  let lookToken;
  let adRewards;
  let owner;
  let user1;
  let user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // 部署LOOK代币
    const LookToken = await ethers.getContractFactory('LookToken');
    lookToken = await LookToken.deploy();
    await lookToken.deployed();

    // 部署广告奖励合约
    const AdRewards = await ethers.getContractFactory('AdRewards');
    adRewards = await AdRewards.deploy(lookToken.address);
    await adRewards.deployed();

    // 将1000个LOOK转移到AdRewards合约用作奖励池
    const rewardPoolAmount = ethers.utils.parseEther('1000');
    await lookToken.transfer(adRewards.address, rewardPoolAmount);
  });

  describe('Deployment', function () {
    it('Should set correct LOOK token address', async function () {
      expect(await adRewards.lookToken()).to.equal(lookToken.address);
    });
  });

  describe('Watch Ad', function () {
    it('User can watch ad and receive reward', async function () {
      const adId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('ad1'));
      const rewardPerAd = ethers.utils.parseEther('1');

      const initialBalance = await lookToken.balanceOf(user1.address);
      await adRewards.connect(user1).watchAd(adId);
      const finalBalance = await lookToken.balanceOf(user1.address);

      expect(finalBalance).to.equal(initialBalance.add(rewardPerAd));
    });

    it('Should not allow watching same ad twice', async function () {
      const adId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('ad1'));

      await adRewards.connect(user1).watchAd(adId);
      await expect(adRewards.connect(user1).watchAd(adId)).to.be.revertedWith(
        'Ad already claimed by user'
      );
    });

    it('Should track daily reward limit', async function () {
      const dailyLimit = 20; // 每天最多20个
      const rewardPerAd = ethers.utils.parseEther('1');

      // 观看20个广告
      for (let i = 0; i < dailyLimit; i++) {
        const adId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(`ad${i}`));
        await adRewards.connect(user1).watchAd(adId);
      }

      // 尝试观看第21个广告应该失败
      const adId21 = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('ad21'));
      await expect(adRewards.connect(user1).watchAd(adId21)).to.be.revertedWith(
        'Daily limit exceeded'
      );
    });
  });

  describe('Get Remaining Reward', function () {
    it('Should return correct remaining daily reward', async function () {
      const remainingBefore = await adRewards.getRemainingDailyReward(user1.address);
      expect(remainingBefore).to.equal(ethers.utils.parseEther('20'));

      // 观看一个广告
      const adId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('ad1'));
      await adRewards.connect(user1).watchAd(adId);

      const remainingAfter = await adRewards.getRemainingDailyReward(user1.address);
      expect(remainingAfter).to.equal(ethers.utils.parseEther('19'));
    });
  });

  describe('Contract Management', function () {
    it('Owner can withdraw tokens', async function () {
      const withdrawAmount = ethers.utils.parseEther('100');
      const initialBalance = await lookToken.balanceOf(owner.address);

      await adRewards.withdrawTokens(withdrawAmount);

      const finalBalance = await lookToken.balanceOf(owner.address);
      expect(finalBalance).to.equal(initialBalance.add(withdrawAmount));
    });

    it('Should get correct contract balance', async function () {
      const contractBalance = await adRewards.getContractBalance();
      expect(contractBalance).to.equal(ethers.utils.parseEther('1000'));
    });
  });
});
