// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/Nonces.sol)
pragma solidity ^0.8.20;

/**
 * @dev Provides tracking nonces for addresses. Nonces will only increment.
 */

// Nonce（Number used once） 是一个至关重要的概念，主要用于防止重放攻击。本库是一个轻量级的抽象合约，专门为需要签名验证、元交易（Meta-transactions）或 EIP-712 离线签名的合约提供基础支持
abstract contract Nonces {
    /**
     * @dev The nonce used for an `account` is not the expected current nonce.
     */
    error InvalidAccountNonce(address account, uint256 currentNonce);

    // 记录每个地址当前可用的Nonce值
    // 每个地址的Nonce从0开始，每使用一次增加1
    mapping(address account => uint256) private _nonces;

    /**
     * @dev Returns the next unused nonce for an address.
     */
    // 让外部（如前端钱包）查询 owner 下一次签名时应该使用的Nonce值
    // 在构造离线签名消息（如 EIP-712）时，前端必须调用这个函数来获取正确的 Nonce，否则合约校验会失败
    function nonces(address owner) public view virtual returns (uint256) {
        return _nonces[owner];
    }

    /**
     * @dev Consumes a nonce.
     *
     * Returns the current value and increments nonce.
     */
    // 内部消耗函数。这是合约中最关键的逻辑，通常在验证签名成功后调用
    function _useNonce(address owner) internal virtual returns (uint256) {
        // For each account, the nonce has an initial value of 0, can only be incremented by one, and cannot be
        // decremented or reset. This guarantees that the nonce never overflows.
        unchecked {
            // It is important to do x++ and not ++x here.
            return _nonces[owner]++;
        }
    }

    /**
     * @dev Same as {_useNonce} but checking that `nonce` is the next valid for `owner`.
     */
    // 检查型消耗函数
    // 它不仅消耗Nonce，还会强制检查传入的 nonce 是否等于当前的预期值
    function _useCheckedNonce(address owner, uint256 nonce) internal virtual {
        uint256 current = _useNonce(owner);
        if (nonce != current) {
            revert InvalidAccountNonce(owner, current);
        }
    }
}
