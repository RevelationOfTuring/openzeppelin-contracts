// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (utils/Pausable.sol)

pragma solidity ^0.8.20;

import {Context} from "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
// 本合约提供了一种状态切换机制。合约默认处于“正常运行”状态，但在紧急情况下，管理员可以将其切换为“暂停”状态，从而锁定关键功能。
abstract contract Pausable is Context {
    // 暂停状态是true，非暂停状态是false
    bool private _paused;

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    /**
     * @dev The operation failed because the contract is paused.
     */
    error EnforcedPause();

    /**
     * @dev The operation failed because the contract is not paused.
     */
    error ExpectedPause();

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    // 调用被该修改器修饰的函数，如果合约被暂停，这些操作直接回滚
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    // 调用被该修改器修饰的函数，如果合约处于非暂停状态，这些操作直接回滚
    // 使用该修改器比较少见，通常用于“仅在紧急情况下允许”的操作（如“紧急提取本金”）。
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    // 返回合约的暂停状态。如果处于暂停状态，返回true。否则返回false
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    // 如果处于暂停状态，抛出错误EnforcedPause
    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    // 如果处于非暂停状态，抛出错误EnforcedPause
    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    // 内部控制函数，将合约状态从非暂停更改为暂停
    // 如果合约状态为暂停状态，调用该函数会报错
    // 为什么要加入whenNotPaused限制？答：防止状态重置和重复触发，这会误导后端索引器
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    // 内部控制函数，将合约状态从暂停更改为非暂停
    // 如果合约状态为非暂停状态，调用该函数会报错
    // 为什么要加入whenPaused限制？答：防止状态重置和重复触发，这会误导后端索引器
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}
