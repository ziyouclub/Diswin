// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

/**
 * @title AdRewards
 * @dev 管理用户观看广告获取LOOK代币
 * 单个广告奖励: 1枚LOOK
 * 每日限额: 20枚
 */
contract AdRewards is Ownable, ReentrancyGuard {
    IERC20 public lookToken;

    // 配置参数
    uint256 public constant REWARD_PER_AD = 1e18; // 1枚LOOK (18位小数)
    uint256 public constant DAILY_LIMIT = 20; // 每日限额20枚
    uint256 public constant DAILY_LIMIT_AMOUNT = 20e18;

    // 用户数据结构
    struct UserDaily {
        uint256 watchedCount; // 今天观看的广告数
        uint256 claimedAmount; // 今天已获得的代币总额
        uint256 lastResetTime; // 上次重置时间
    }

    // 用户每日统计
    mapping(address => UserDaily) public userDaily;

    // 广告ID到用户的映射 (用于防止重复核销)
    mapping(bytes32 => mapping(address => bool)) public adUserClaimed;

    // 事件
    event AdWatched(address indexed user, bytes32 indexed adId, uint256 timestamp);
    event RewardClaimed(address indexed user, uint256 amount, uint256 timestamp);
    event DailyLimitUpdated(uint256 newLimit);

    constructor(address _lookTokenAddress) {
        require(_lookTokenAddress != address(0), 'Invalid token address');
        lookToken = IERC20(_lookTokenAddress);
    }

    /**
     * @dev 获取用户今日剩余可获得的代币数
     * @param user 用户地址
     * @return 剩余代币数
     */
    function getRemainingDailyReward(address user) public view returns (uint256) {
        UserDaily memory daily = userDaily[user];

        // 检查是否需要重置 (超过24小时)
        if (block.timestamp >= daily.lastResetTime + 1 days) {
            return DAILY_LIMIT_AMOUNT;
        }

        uint256 remaining = DAILY_LIMIT_AMOUNT > daily.claimedAmount
            ? DAILY_LIMIT_AMOUNT - daily.claimedAmount
            : 0;
        return remaining;
    }

    /**
     * @dev 获取用户今日已获得的代币数
     * @param user 用户地址
     * @return 已获得的代币数
     */
    function getTodayClaimedAmount(address user) public view returns (uint256) {
        UserDaily memory daily = userDaily[user];

        // 检查是否需要重置
        if (block.timestamp >= daily.lastResetTime + 1 days) {
            return 0;
        }

        return daily.claimedAmount;
    }

    /**
     * @dev 核销广告并获得奖励
     * @param adId 广告ID
     * @return 奖励金额
     */
    function watchAd(bytes32 adId) external nonReentrant returns (uint256) {
        require(adId != bytes32(0), 'Invalid ad ID');
        require(!adUserClaimed[adId][msg.sender], 'Ad already claimed by user');

        // 检查是否需要重置每日计数
        UserDaily storage daily = userDaily[msg.sender];
        if (block.timestamp >= daily.lastResetTime + 1 days) {
            daily.watchedCount = 0;
            daily.claimedAmount = 0;
            daily.lastResetTime = block.timestamp;
        }

        // 检查每日限额
        require(daily.claimedAmount + REWARD_PER_AD <= DAILY_LIMIT_AMOUNT, 'Daily limit exceeded');

        // 更新用户数据
        daily.watchedCount += 1;
        daily.claimedAmount += REWARD_PER_AD;
        adUserClaimed[adId][msg.sender] = true;

        // 发放奖励
        require(lookToken.transfer(msg.sender, REWARD_PER_AD), 'Token transfer failed');

        emit AdWatched(msg.sender, adId, block.timestamp);
        emit RewardClaimed(msg.sender, REWARD_PER_AD, block.timestamp);

        return REWARD_PER_AD;
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

    /**
     * @dev 获取合约中的代币余额
     * @return 代币余额
     */
    function getContractBalance() external view returns (uint256) {
        return lookToken.balanceOf(address(this));
    }
}
