// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (utils/SlotDerivation.sol)
// This file was procedurally generated from scripts/generate/templates/SlotDerivation.js.

pragma solidity ^0.8.20;

/**
 * @dev Library for computing storage (and transient storage) locations from namespaces and deriving slots
 * corresponding to standard patterns. The derivation method for array and mapping matches the storage layout used by
 * the solidity language / compiler.
 *
 * See https://docs.soliditylang.org/en/v0.8.20/internals/layout_in_storage.html#mappings-and-dynamic-arrays[Solidity docs for mappings and dynamic arrays.].
 *
 * Example usage:
 * ```solidity
 * contract Example {
 *     // Add the library methods
 *     using StorageSlot for bytes32;
 *     using SlotDerivation for *;
 *
 *     // Declare a namespace
 *     string private constant _NAMESPACE = "<namespace>"; // eg. OpenZeppelin.Slot
 *
 *     function setValueInNamespace(uint256 key, address newValue) internal {
 *         _NAMESPACE.erc7201Slot().deriveMapping(key).getAddressSlot().value = newValue;
 *     }
 *
 *     function getValueInNamespace(uint256 key) internal view returns (address) {
 *         return _NAMESPACE.erc7201Slot().deriveMapping(key).getAddressSlot().value;
 *     }
 * }
 * ```
 *
 * TIP: Consider using this library along with {StorageSlot}.
 *
 * NOTE: This library provides a way to manipulate storage locations in a non-standard way. Tooling for checking
 * upgrade safety will ignore the slots accessed through this library.
 *
 * _Available since v5.1._
 */

// SlotDerivation库是模拟 Solidity 编译器的存储布局算法，手动计算复杂数据结构（如映射和数组）在以太坊存储（Storage）中的具体位置
library SlotDerivation {
    /**
     * @dev Derive an ERC-7201 slot from a string (namespace).
     */
    // 命名空间槽位计算，即遵循 ERC-7201 标准，计算一个基于字符串的“根槽位”
    // 即slot = keccak256(keccak256(namespace) - 1) & ~0xff
    // 为什么要将低8位清零？
    // 答：
    // 1. 通过 keccak256(...) - 1 的计算，得到的哈希值已经几乎不可能和低位的 Slot 重合。再将低八位清0，这相当于在原本就极其稀疏的 256 位地址空间里，又划定了一块特殊的“保留区”；
    // 2. 这是最实际的原因。当你定义一个命名空间时，你通常是在这个位置存放一个结构体（struct）。如果基准槽位（Base Slot）的最后两位是 00：结构体的第 1 个成员在 ...00，第 2 个成员在 ...01，...最多可以容纳 256 个连续成员而不会导致地址“进位”影响到高位的哈希特征。
    function erc7201Slot(string memory namespace) internal pure returns (bytes32 slot) {
        assembly ("memory-safe") {
            // 计算hash=keccak256(namespace) - 1，并将结果存在0x00开始的内存中
            mstore(0x00, sub(keccak256(add(namespace, 0x20), mload(namespace)), 1))
            // 计算keccak256(hash)并将低8位清0，作为slot号返回
            slot := and(keccak256(0x00, 0x20), not(0xff))
        }
    }

    /**
     * @dev Add an offset to a slot to get the n-th element of a structure or an array.
     */
    // 计算结构体偏移槽位。slot是根槽位，pos为偏移量
    // 在 Solidity 中，结构体的成员是连续存放的。如果结构体起始于 slot，那么第 n 个成员就在 slot + n
    function offset(bytes32 slot, uint256 pos) internal pure returns (bytes32 result) {
        unchecked {
            // 简单的加法
            return bytes32(uint256(slot) + pos);
        }
    }

    /**
     * @dev Derive the location of the first element in an array from the slot where the length is stored.
     */
    // 计算动态数组数据的起始位置
    // Solidity 存储动态数组时，根槽位 slot 存长度，而在 keccak256(slot) 存第一个元素的数据
    function deriveArray(bytes32 slot) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            // 将数组的根槽位写入内存的0x00
            mstore(0x00, slot)
            // 计算keccak256(slot)
            result := keccak256(0x00, 0x20)
        }
    }

    /**
     * @dev Derive the location of a mapping element from the key.
     */
    // 计算mapping(address=>*)的某key对应值所在的槽位，该mapping的根槽位是slot
    // 即keccak256(key·slot)
    function deriveMapping(bytes32 slot, address key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            // 由于address是160位，从栈上取出时（256位）可能高位上有脏数据。先将高96位置0，后写入0x00的内存
            mstore(0x00, and(key, shr(96, not(0))))
            // 将mapping的根槽位写入0x20开始的内存
            mstore(0x20, slot)
            // 计算keccak256(key·slot)
            result := keccak256(0x00, 0x40)
        }
    }

    /**
     * @dev Derive the location of a mapping element from the key.
     */
    // 计算mapping(bool=>*)的某key对应值所在的槽位，该mapping的根槽位是slot
    // 即keccak256(key·slot)
    // 注：在计算槽位时，严格按照true为0x00...01（256位），false为0x00...00（256位）来计算
    function deriveMapping(bytes32 slot, bool key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            // bool的“归一化”：在底层，bool 存储为 0 (false) 或 1 (true)。但由于 bool 在内存中占用的是一个完整的 32 字节字（Word），理论上一个非法的布尔值可能包含其他位（如使用非1的正整数表示true）
            // iszero(key)：如果key是0，则为1；如果key是其他正整数，则为0
            // iszero(iszero(key))：如果key是0，则为0；如果key是其他正整数，则为1
            // 将归一化后的bool写入0x00的内存
            mstore(0x00, iszero(iszero(key)))
            // 将mapping的根槽位写入0x20开始的内存
            mstore(0x20, slot)
            // 计算keccak256(key·slot)
            result := keccak256(0x00, 0x40)
        }
    }

    /**
     * @dev Derive the location of a mapping element from the key.
     */
    // 计算mapping(bytes32=>*)的某key对应值所在的槽位，该mapping的根槽位是slot
    // 即keccak256(key·slot)
    function deriveMapping(bytes32 slot, bytes32 key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            // 将key写入0x00的内存
            mstore(0x00, key)
            // 将mapping的根槽位写入0x20开始的内存
            mstore(0x20, slot)
            // 计算keccak256(key·slot)
            result := keccak256(0x00, 0x40)
        }
    }

    /**
     * @dev Derive the location of a mapping element from the key.
     */
    // 计算mapping(uint256=>*)的某key对应值所在的槽位，该mapping的根槽位是slot
    // 即keccak256(key·slot)
    // 同key为bytes32类型一样
    function deriveMapping(bytes32 slot, uint256 key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, key)
            mstore(0x20, slot)
            result := keccak256(0x00, 0x40)
        }
    }

    /**
     * @dev Derive the location of a mapping element from the key.
     */
    // 计算mapping(int256=>*)的某key对应值所在的槽位，该mapping的根槽位是slot
    // 即keccak256(key·slot)
    // 同key为bytes32类型一样
    function deriveMapping(bytes32 slot, int256 key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            mstore(0x00, key)
            mstore(0x20, slot)
            result := keccak256(0x00, 0x40)
        }
    }

    /**
     * @dev Derive the location of a mapping element from the key.
     */
    // 计算mapping(string=>*)的某key对应值所在的槽位，该mapping的根槽位是slot
    // 即keccak256(字符串的实际字节内容·slot)
    function deriveMapping(bytes32 slot, string memory key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            // 获取key的字节长度
            let length := mload(key)
            // begin为内存中，key实际字节内容的起始地址
            let begin := add(key, 0x20)
            // end为内存中，key实际字节内容的结束地址
            let end := add(begin, length)
            // 将此时end地址上的值缓存起来
            let cache := mload(end)
            // 将根槽位slot写入end地址
            mstore(end, slot)
            // 计算keccak256(字符串字节内容·slot)
            result := keccak256(begin, add(length, 0x20))
            // 计算后，将之前end地址上的值重写回去
            mstore(end, cache)
            // 技巧说明：为了不使用 abi.encodePacked（那会产生昂贵的内存拷贝），它直接在内存中原有的字符串末尾“临时”贴上 slot 值，计算完哈希后再复原。这种做法性能极高
        }
    }

    /**
     * @dev Derive the location of a mapping element from the key.
     */
    // 计算mapping(bytes=>*)的某key对应值所在的槽位，该mapping的根槽位是slot
    // 即keccak256(bytes的实际字节内容·slot)
    // 由于string和bytes在内存中的布局是完全一样的，所以同mapping(string=>*)的某key对应值所在的槽位（上面函数）完全一样
    function deriveMapping(bytes32 slot, bytes memory key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            let length := mload(key)
            let begin := add(key, 0x20)
            let end := add(begin, length)
            let cache := mload(end)
            mstore(end, slot)
            result := keccak256(begin, add(length, 0x20))
            mstore(end, cache)
        }
    }
}
