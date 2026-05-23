// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

/**
 * @title LOOK Token
 * @dev LOOK是Diswin生态中的治理和收益代币
 * 总供应量: 1亿枚
 */
contract LookToken is ERC20, ERC20Burnable, ERC20Pausable, Ownable {
    // 铸造者地址映射
    mapping(address => bool) public minters;

    // 事件
    event MinterAdded(address indexed account);
    event MinterRemoved(address indexed account);

    constructor() ERC20('LOOK', 'LOOK') {
        // 初始铸造10%供应量 (1000万枚)
        _mint(msg.sender, 10_000_000 * 10 ** decimals());
        minters[msg.sender] = true;
    }

    /**
     * @dev 添加铸造者
     * @param account 要添加的地址
     */
    function addMinter(address account) public onlyOwner {
        require(account != address(0), 'Cannot add zero address as minter');
        minters[account] = true;
        emit MinterAdded(account);
    }

    /**
     * @dev 移除铸造者
     * @param account 要移除的地址
     */
    function removeMinter(address account) public onlyOwner {
        minters[account] = false;
        emit MinterRemoved(account);
    }

    /**
     * @dev 铸造代币
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) public {
        require(minters[msg.sender], 'Only minters can mint');
        require(to != address(0), 'Cannot mint to zero address');
        _mint(to, amount);
    }

    /**
     * @dev 暂停所有转账
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev 恢复所有转账
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    // 内部函数 - 钩子
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Pausable) whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}
