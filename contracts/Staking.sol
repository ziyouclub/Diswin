// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

/**
 * @title Staking
 * @dev 质押系统 - 月化收益率20%
 * 支持12个质押等级
 */
contract Staking is Ownable, ReentrancyGuard {
    IERC20 public lookToken;

    // 月化收益率 (以万分比表示: 20% = 2000)
    uint256 public constant MONTHLY_REWARD_RATE = 2000; // 20%
    uint256 public constant RATE_DENOMINATOR = 10000;

    // 质押等级配置
    struct StakingTier {
        uint256 minAmount; // 最小质押数量
        bool enabled; // 是否启用
    }

    // 用户质押信息
    struct StakeInfo {
        uint256 amount; // 质押数量
        uint256 startTime; // 开始质押时间
        uint256 lastClaimTime; // 最后领取奖励时间
        uint256 claimedRewards; // 已领取奖励总额
        uint8 tier; // 所在等级
    }

    // 质押等级配置 (从Tier 1到Tier 12)
    mapping(uint8 => StakingTier) public tiers;
    uint8 public constant MAX_TIER = 12;

    // 用户质押信息
    mapping(address => StakeInfo) public stakes;

    // 总质押量
    uint256 public totalStaked;

    // 事件
    event Staked(address indexed user, uint256 amount, uint8 tier, uint256 timestamp);
    event Unstaked(address indexed user, uint256 amount, uint256 timestamp);
    event RewardClaimed(address indexed user, uint256 amount, uint256 timestamp);
    event TierUpdated(uint8 indexed tier, uint256 minAmount, bool enabled);

    constructor(address _lookTokenAddress) {
        require(_lookTokenAddress != address(0), 'Invalid token address');
        lookToken = IERC20(_lookTokenAddress);

        // 初始化12个质押等级
        initializeTiers();
    }

    /**
     * @dev 初始化质押等级
     */
    function initializeTiers() private {
        uint256[12] memory minAmounts = [
            20e18,
            50e18,
            100e18,
            200e18,
            500e18,
            1000e18,
            2000e18,
            3000e18,
            5000e18,
            10000e18,
            20000e18,
            30000e18
        ];

        for (uint8 i = 0; i < 12; i++) {
            tiers[i + 1] = StakingTier({minAmount: minAmounts[i], enabled: true});
        }
    }

    /**
     * @dev 根据质押数量确定等级
     * @param amount 质押数量
     * @return tier 等级
     */
    function getTierByAmount(uint256 amount) public view returns (uint8) {
        for (uint8 i = MAX_TIER; i >= 1; i--) {
            if (tiers[i].enabled && amount >= tiers[i].minAmount) {
                return i;
            }
        }
        revert('Amount does not meet minimum requirement');
    }

    /**
     * @dev 获取用户待领取的奖励
     * @param user 用户地址
     * @return 待领取的奖励数量
     */
    function getPendingReward(address user) public view returns (uint256) {
        StakeInfo memory stake = stakes[user];

        if (stake.amount == 0) {
            return 0;
        }

        uint256 lastClaimTime = stake.lastClaimTime > 0 ? stake.lastClaimTime : stake.startTime;
        uint256 timeElapsed = block.timestamp - lastClaimTime;

        // 计算月数 (按30天计算)
        uint256 monthsElapsed = timeElapsed / 30 days;

        if (monthsElapsed == 0) {
            return 0;
        }

        // 计算奖励: 质押数量 * 月化收益率 * 月数
        uint256 reward = (stake.amount * MONTHLY_REWARD_RATE * monthsElapsed) / RATE_DENOMINATOR / 100;

        return reward;
    }

    /**
     * @dev 质押代币
     * @param amount 质押数量
     */
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, 'Stake amount must be greater than 0');

        // 确定等级
        uint8 tier = getTierByAmount(amount);

        // 从用户账户转入代币
        require(
            lookToken.transferFrom(msg.sender, address(this), amount),
            'Token transfer failed'
        );

        StakeInfo storage stakeInfo = stakes[msg.sender];

        // 如果已有质押，先领取奖励
        if (stakeInfo.amount > 0) {
            uint256 pending = getPendingReward(msg.sender);
            if (pending > 0) {
                stakeInfo.claimedRewards += pending;
                require(lookToken.transfer(msg.sender, pending), 'Reward transfer failed');
                emit RewardClaimed(msg.sender, pending, block.timestamp);
            }
            // 增加质押数量
            stakeInfo.amount += amount;
        } else {
            // 新建质押
            stakeInfo.amount = amount;
            stakeInfo.startTime = block.timestamp;
            stakeInfo.lastClaimTime = block.timestamp;
            stakeInfo.claimedRewards = 0;
        }

        stakeInfo.tier = tier;
        totalStaked += amount;

        emit Staked(msg.sender, amount, tier, block.timestamp);
    }

    /**
     * @dev 解除质押
     * @param amount 解除数量
     */
    function unstake(uint256 amount) external nonReentrant {
        StakeInfo storage stakeInfo = stakes[msg.sender];

        require(stakeInfo.amount > 0, 'No stake found');
        require(amount > 0 && amount <= stakeInfo.amount, 'Invalid unstake amount');

        // 先领取待领取的奖励
        uint256 pending = getPendingReward(msg.sender);
        if (pending > 0) {
            stakeInfo.claimedRewards += pending;
            require(lookToken.transfer(msg.sender, pending), 'Reward transfer failed');
            emit RewardClaimed(msg.sender, pending, block.timestamp);
        }

        // 更新质押信息
        stakeInfo.amount -= amount;
        stakeInfo.lastClaimTime = block.timestamp;

        // 如果完全解除，删除质押信息
        if (stakeInfo.amount == 0) {
            delete stakes[msg.sender];
        } else {
            // 重新计算等级
            stakeInfo.tier = getTierByAmount(stakeInfo.amount);
        }

        totalStaked -= amount;

        // 返还质押的代币
        require(lookToken.transfer(msg.sender, amount), 'Token transfer failed');

        emit Unstaked(msg.sender, amount, block.timestamp);
    }

    /**
     * @dev 领取奖励
     */
    function claimReward() external nonReentrant {
        StakeInfo storage stakeInfo = stakes[msg.sender];

        require(stakeInfo.amount > 0, 'No stake found');

        uint256 pending = getPendingReward(msg.sender);
        require(pending > 0, 'No pending reward');

        stakeInfo.claimedRewards += pending;
        stakeInfo.lastClaimTime = block.timestamp;

        require(lookToken.transfer(msg.sender, pending), 'Token transfer failed');

        emit RewardClaimed(msg.sender, pending, block.timestamp);
    }

    /**
     * @dev 获取用户质押信息
     * @param user 用户地址
     * @return 质押信息
     */
    function getStakeInfo(address user) external view returns (StakeInfo memory) {
        return stakes[user];
    }

    /**
     * @dev 管理员更新质押等级
     * @param tier 等级
     * @param minAmount 最小质押数量
     * @param enabled 是否启用
     */
    function updateTier(
        uint8 tier,
        uint256 minAmount,
        bool enabled
    ) external onlyOwner {
        require(tier >= 1 && tier <= MAX_TIER, 'Invalid tier');
        tiers[tier] = StakingTier({minAmount: minAmount, enabled: enabled});
        emit TierUpdated(tier, minAmount, enabled);
    }

    /**
     * @dev 获取合约中的代币余额
     * @return 代币余额
     */
    function getContractBalance() external view returns (uint256) {
        return lookToken.balanceOf(address(this));
    }

    /**
     * @dev 管理员提取合约中的代币
     * @param amount 提取数量
     */
    function withdrawTokens(uint256 amount) external onlyOwner {
        require(amount > 0, 'Amount must be greater than 0');
        uint256 balance = lookToken.balanceOf(address(this));
        require(amount <= balance, 'Insufficient contract balance');
        require(lookToken.transfer(msg.sender, amount), 'Token transfer failed');
    }
}
