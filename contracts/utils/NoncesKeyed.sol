// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.2.0) (utils/NoncesKeyed.sol)
pragma solidity ^0.8.20;

import {Nonces} from "./Nonces.sol";

/**
 * @dev Alternative to {Nonces}, that supports key-ed nonces.
 *
 * Follows the https://eips.ethereum.org/EIPS/eip-4337#semi-abstracted-nonce-support[ERC-4337's semi-abstracted nonce system].
 *
 * NOTE: This contract inherits from {Nonces} and reuses its storage for the first nonce key (i.e. `0`). This
 * makes upgrading from {Nonces} to {NoncesKeyed} safe when using their upgradeable versions (e.g. `NoncesKeyedUpgradeable`).
 * Doing so will NOT reset the current state of nonces, avoiding replay attacks where a nonce is reused after the upgrade.
 */

// NoncesKeyed是对基础合约Nonces的一个非常高级且重要的扩展。它引入了“分频道（Keyed）”的 Nonce 机制
// 这种设计的核心灵感来源于ERC-4337 (账户抽象)。传统的Nonce是线性递增的（0, 1, 2...），这意味着用户必须按顺序发送交易。而 NoncesKeyed 允许用户在不同的key下并行发送交易，互不干扰。
abstract contract NoncesKeyed is Nonces {
    // _nonces 映射
    // key (192位)：代表一个独立的“频道”或“序列”。
    // nonce (64位)：该频道内的递增计数器。
    // 注：当key == 0时，它会重用父类Nonces的存储。这保证了从普通Nonce升级到Keyed Nonce时的系统安全性，防止重放攻击
    mapping(address owner => mapping(uint192 key => uint64)) private _nonces;

    /// @dev Returns the next unused nonce for an address and key. Result contains the key prefix.
    // 查询特定用户在特定 key 下的下一个可用 Nonce
    function nonces(address owner, uint192 key) public view virtual returns (uint256) {
        // 如果 key 为 0，调用父类逻辑；否则，调用内部的 _pack 函数，将 key 和 nonce 打包成一个完整的 uint256 返回
        return key == 0 ? nonces(owner) : _pack(key, _nonces[owner][key]);
    }

    /**
     * @dev Consumes the next unused nonce for an address and key.
     *
     * Returns the current value without the key prefix. Consumed nonce is increased, so calling this function twice
     * with the same arguments will return different (sequential) results.
     */
    // 内部消耗函数，消耗指定key下的Nonce并递增
    // 返回值为key+自增前的对应nonce
    function _useNonce(address owner, uint192 key) internal virtual returns (uint256) {
        // For each account, the nonce has an initial value of 0, can only be incremented by one, and cannot be
        // decremented or reset. This guarantees that the nonce never overflows.
        unchecked {
            // It is important to do x++ and not ++x here.
            return key == 0 ? _useNonce(owner) : _pack(key, _nonces[owner][key]++);
        }
    }

    /**
     * @dev Same as {_useNonce} but checking that `nonce` is the next valid for `owner`.
     *
     * This version takes the key and the nonce in a single uint256 parameter:
     * - use the first 24 bytes for the key
     * - use the last 8 bytes for the nonce
     */
    // 校验型消耗函数（单参数版本）
    // Key和Nonce会被打包成一个256位的keyNonce传入
    function _useCheckedNonce(address owner, uint256 keyNonce) internal virtual override {
        // 先将keyNonce差分成key和nonce
        (uint192 key, ) = _unpack(keyNonce);
        if (key == 0) {
            // 如果key为0，那么就走父类Nonces合约的校验消耗函数
            super._useCheckedNonce(owner, keyNonce);
        } else {
            // 如果key不为0，先消耗该owner对应key的nonce
            uint256 current = _useNonce(owner, key);
            // 验证传入的 keyNonce 是否正好等于合约记录的当前值。如果用户乱序发送（例如在 key 1 下跳过了 nonce 5 直接发了 6），合约会抛出 InvalidAccountNonce 错误
            if (keyNonce != current) revert InvalidAccountNonce(owner, current);
        }
    }

    /**
     * @dev Same as {_useNonce} but checking that `nonce` is the next valid for `owner`.
     *
     * This version takes the key and the nonce as two different parameters.
     */
    // 校验型消耗函数（双参数版本），直接分别传入192位的key和64位的nonce
    function _useCheckedNonce(address owner, uint192 key, uint64 nonce) internal virtual {
        _useCheckedNonce(owner, _pack(key, nonce));
    }

    /// @dev Pack key and nonce into a keyNonce
    // 数据打包，将key和nonce打包成一个uint256
    function _pack(uint192 key, uint64 nonce) private pure returns (uint256) {
        // 将192位的key左移64位，然后把64位的nonce拼在低位
        return (uint256(key) << 64) | nonce;
    }

    /// @dev Unpack a keyNonce into its key and nonce components
    // 数据解包，将256位的keyNonce拆解成192位的key和64位的nonce。是pack操作的逆过程。
    function _unpack(uint256 keyNonce) private pure returns (uint192 key, uint64 nonce) {
        return (uint192(keyNonce >> 64), uint64(keyNonce));
    }
}
