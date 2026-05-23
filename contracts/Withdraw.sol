// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

/**
 * @title Withdraw
 * @dev 管理用户提现 - 余额需大于等于50个LOOK才能提现
 */
contract Withdraw is Ownable, ReentrancyGuard {
    IERC20 public lookToken;

    // 提现配置
    uint256 public constant MINIMUM_WITHDRAW = 50e18; // 最少提现50个LOOK
    uint256 public constant WITHDRAW_FEE_RATE = 100; // 提现手续费 1% (以万分比表示)
    uint256 public constant FEE_DENOMINATOR = 10000;

    // 提现状态枚举
    enum WithdrawStatus {
        PENDING, // 待处理
        APPROVED, // 已批准
        REJECTED, // 已拒绝
        COMPLETED // 已完成
    }

    // 提现记录结构体
    struct WithdrawRequest {
        address user;
        uint256 amount;
        uint256 timestamp;
        WithdrawStatus status;
        string reason; // 拒绝原因
    }

    // 用户提现记录
    mapping(address => WithdrawRequest[]) public userWithdraws;

    // 提现费用池
    uint256 public feePool;

    // 事件
    event WithdrawRequested(
        address indexed user,
        uint256 amount,
        uint256 fee,
        uint256 timestamp
    );
    event WithdrawApproved(address indexed user, uint256 requestIndex, uint256 timestamp);
    event WithdrawRejected(
        address indexed user,
        uint256 requestIndex,
        string reason,
        uint256 timestamp
    );
    event WithdrawCompleted(address indexed user, uint256 amount, uint256 timestamp);
    event FeeWithdrawn(address indexed owner, uint256 amount, uint256 timestamp);

    constructor(address _lookTokenAddress) {
        require(_lookTokenAddress != address(0), 'Invalid token address');
        lookToken = IERC20(_lookTokenAddress);
    }

    /**
     * @dev 用户申请提现
     * @param amount 提现金额
     */
    function requestWithdraw(uint256 amount) external nonReentrant {
        require(amount >= MINIMUM_WITHDRAW, 'Amount must be at least 50 LOOK');
        require(lookToken.balanceOf(msg.sender) >= amount, 'Insufficient balance');

        // 计算提现手续费
        uint256 fee = (amount * WITHDRAW_FEE_RATE) / FEE_DENOMINATOR;
        uint256 actualAmount = amount - fee;

        // 从用户账户转入到合约
        require(
            lookToken.transferFrom(msg.sender, address(this), amount),
            'Token transfer failed'
        );

        // 添加提现记录
        userWithdraws[msg.sender].push(
            WithdrawRequest({
                user: msg.sender,
                amount: actualAmount,
                timestamp: block.timestamp,
                status: WithdrawStatus.PENDING,
                reason: ''
            })
        );

        // 累计手续费
        feePool += fee;

        emit WithdrawRequested(msg.sender, actualAmount, fee, block.timestamp);
    }

    /**
     * @dev 管理员批准提现
     * @param user 用户地址
     * @param requestIndex 提现请求索引
     */
    function approveWithdraw(address user, uint256 requestIndex) external onlyOwner {
        require(requestIndex < userWithdraws[user].length, 'Invalid request index');

        WithdrawRequest storage request = userWithdraws[user][requestIndex];
        require(request.status == WithdrawStatus.PENDING, 'Request already processed');

        request.status = WithdrawStatus.APPROVED;

        // 转账给用户
        require(
            lookToken.transfer(user, request.amount),
            'Token transfer to user failed'
        );

        request.status = WithdrawStatus.COMPLETED;

        emit WithdrawApproved(user, requestIndex, block.timestamp);
        emit WithdrawCompleted(user, request.amount, block.timestamp);
    }

    /**
     * @dev 管理员拒绝提现
     * @param user 用户地址
     * @param requestIndex 提现请求索引
     * @param reason 拒绝原因
     */
    function rejectWithdraw(
        address user,
        uint256 requestIndex,
        string memory reason
    ) external onlyOwner {
        require(requestIndex < userWithdraws[user].length, 'Invalid request index');

        WithdrawRequest storage request = userWithdraws[user][requestIndex];
        require(request.status == WithdrawStatus.PENDING, 'Request already processed');

        // 计算实际提现金额（包括手续费）
        uint256 fee = (request.amount * WITHDRAW_FEE_RATE) / (FEE_DENOMINATOR - WITHDRAW_FEE_RATE);
        uint256 totalAmount = request.amount + fee;

        request.status = WithdrawStatus.REJECTED;
        request.reason = reason;

        // 返回代币给用户（包括手续费）
        require(lookToken.transfer(user, totalAmount), 'Token transfer to user failed');

        // 减少手续费池
        feePool -= fee;

        emit WithdrawRejected(user, requestIndex, reason, block.timestamp);
    }

    /**
     * @dev 获取用户的提现历史
     * @param user 用户地址
     * @return 提现请求数组
     */
    function getUserWithdraws(address user) external view returns (WithdrawRequest[] memory) {
        return userWithdraws[user];
    }

    /**
     * @dev 获取用户特定提现请求
     * @param user 用户地址
     * @param requestIndex 请求索引
     * @return 提现请求详情
     */
    function getWithdrawRequest(address user, uint256 requestIndex)
        external
        view
        returns (WithdrawRequest memory)
    {
        require(requestIndex < userWithdraws[user].length, 'Invalid request index');
        return userWithdraws[user][requestIndex];
    }

    /**
     * @dev 获取用户提现请求数
     * @param user 用户地址
     * @return 请求总数
     */
    function getUserWithdrawCount(address user) external view returns (uint256) {
        return userWithdraws[user].length;
    }

    /**
     * @dev 管理员提取手续费
     * @param amount 提取金额
     */
    function withdrawFee(uint256 amount) external onlyOwner {
        require(amount > 0, 'Amount must be greater than 0');
        require(amount <= feePool, 'Insufficient fee pool');

        feePool -= amount;
        require(lookToken.transfer(msg.sender, amount), 'Token transfer failed');

        emit FeeWithdrawn(msg.sender, amount, block.timestamp);
    }

    /**
     * @dev 获取合约中的代币余额
     * @return 余额
     */
    function getContractBalance() external view returns (uint256) {
        return lookToken.balanceOf(address(this));
    }

    /**
     * @dev 获取费用池余额
     * @return 费用池余额
     */
    function getFeePool() external view returns (uint256) {
        return feePool;
    }
}
