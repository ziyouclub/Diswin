const hre = require('hardhat');

async function main() {
  console.log('Deploying contracts...');

  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with account: ${deployer.address}`);
  console.log(`Account balance: ${(await deployer.getBalance()).toString()} wei`);

  // 部署LOOK代币
  console.log('\n1. Deploying LOOK Token...');
  const LookToken = await hre.ethers.getContractFactory('LookToken');
  const lookToken = await LookToken.deploy();
  await lookToken.deployed();
  console.log(`   ✓ LOOK Token deployed to: ${lookToken.address}`);

  // 部署广告奖励���约
  console.log('\n2. Deploying AdRewards Contract...');
  const AdRewards = await hre.ethers.getContractFactory('AdRewards');
  const adRewards = await AdRewards.deploy(lookToken.address);
  await adRewards.deployed();
  console.log(`   ✓ AdRewards deployed to: ${adRewards.address}`);

  // 部署质押合约
  console.log('\n3. Deploying Staking Contract...');
  const Staking = await hre.ethers.getContractFactory('Staking');
  const staking = await Staking.deploy(lookToken.address);
  await staking.deployed();
  console.log(`   ✓ Staking deployed to: ${staking.address}`);

  // 将代币分配给不同的合约和账户
  console.log('\n4. Distributing tokens...');

  // 为广告奖励合约分配100万个LOOK
  const adRewardsAmount = hre.ethers.utils.parseEther('1000000');
  await lookToken.transfer(adRewards.address, adRewardsAmount);
  console.log(`   ✓ Transferred ${hre.ethers.utils.formatEther(adRewardsAmount)} LOOK to AdRewards`);

  // 为质押合约分配200万个LOOK（用作奖励）
  const stakingRewardsAmount = hre.ethers.utils.parseEther('2000000');
  await lookToken.transfer(staking.address, stakingRewardsAmount);
  console.log(`   ✓ Transferred ${hre.ethers.utils.formatEther(stakingRewardsAmount)} LOOK to Staking`);

  // 打印部署摘要
  console.log('\n========== Deployment Summary =========');
  console.log(`LOOK Token:      ${lookToken.address}`);
  console.log(`AdRewards:       ${adRewards.address}`);
  console.log(`Staking:         ${staking.address}`);
  console.log(`Deployer:        ${deployer.address}`);
  console.log('========================================\n');

  // 验证合约
  console.log('Waiting for block confirmations...');
  await lookToken.deployTransaction.wait(5);

  console.log('\nVerifying contracts on BSCScan...');
  try {
    await hre.run('verify:verify', {
      address: lookToken.address,
      constructorArguments: [],
    });
    console.log('✓ LOOK Token verified');
  } catch (e) {
    console.log('LOOK Token verification failed:', e.message);
  }

  try {
    await hre.run('verify:verify', {
      address: adRewards.address,
      constructorArguments: [lookToken.address],
    });
    console.log('✓ AdRewards verified');
  } catch (e) {
    console.log('AdRewards verification failed:', e.message);
  }

  try {
    await hre.run('verify:verify', {
      address: staking.address,
      constructorArguments: [lookToken.address],
    });
    console.log('✓ Staking verified');
  } catch (e) {
    console.log('Staking verification failed:', e.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
