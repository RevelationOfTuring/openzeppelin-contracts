// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (utils/ShortStrings.sol)

pragma solidity ^0.8.20;

import {StorageSlot} from "./StorageSlot.sol";

// | string  | 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA   |
// | length  | 0x                                                              BB |
// ShortString的底层其实就是一个bytes32
type ShortString is bytes32;

/**
 * @dev This library provides functions to convert short memory strings
 * into a `ShortString` type that can be used as an immutable variable.
 *
 * Strings of arbitrary length can be optimized using this library if
 * they are short enough (up to 31 bytes) by packing them with their
 * length (1 byte) in a single EVM word (32 bytes). Additionally, a
 * fallback mechanism can be used for every other case.
 *
 * Usage example:
 *
 * ```solidity
 * contract Named {
 *     using ShortStrings for *;
 *
 *     ShortString private immutable _name;
 *     string private _nameFallback;
 *
 *     constructor(string memory contractName) {
 *         _name = contractName.toShortStringWithFallback(_nameFallback);
 *     }
 *
 *     function name() external view returns (string memory) {
 *         return _name.toStringWithFallback(_nameFallback);
 *     }
 * }
 * ```
 */

// 背景：在以太坊中，string 是动态类型，即使只有一个字符，EVM 也会将其存储在昂贵的动态槽位中，且无法直接标记为 immutable（不可变量）。
// ShortStrings巧妙地利用一个 EVM 字（32 字节）同时存储 字符串内容（前31字节） 和 长度（最后1字节）。这样，短的string就可以像 uint256 一样直接作为 immutable 变量存在，为 name() 或 symbol() 这种高频调用的函数节省大量 Gas。
// 也就是说，ShortStrings可表示的字符串的最大长度为31字节。
library ShortStrings {
    // Used as an identifier for strings longer than 31 bytes.
    // 哨兵值（Sentinel）：这是一个标志。如果一个string的长度>31字节，是无法转换成一个ShortString类型。
    // 在这种情况下，如果是有回退机制，本库会将该字符串直接存到storage中，并用返回FALLBACK_SENTINEL。这就像是一个“标记”，告诉程序：“去查看备用存储（Fallback Storage）”。
    bytes32 private constant FALLBACK_SENTINEL = 0x00000000000000000000000000000000000000000000000000000000000000FF;

    error StringTooLong(string str);
    error InvalidShortString();

    /**
     * @dev Encode a string of at most 31 chars into a `ShortString`.
     *
     * This will trigger a `StringTooLong` error is the input string is too long.
     */
    // 压缩逻辑：将字符串转换为ShortString
    function toShortString(string memory str) internal pure returns (ShortString) {
        // 字符串变成bytes
        bytes memory bstr = bytes(str);
        // 如果字符串的长度>31，revert
        if (bstr.length > 0x1f) {
            revert StringTooLong(str);
        }

        // 在 Solidity 中，将 bytes 转换为 bytes32 时，遵循的是左对齐（Left-aligned）原则。
        // bytes32(uint256(bytes32(bstr)) | bstr.length)：将bytes的内容扩充到bytes32且左对齐，然后将其字节长度放在写入最低的一个字节中
        // 最后将该bytes32包装成ShortString返回
        return ShortString.wrap(bytes32(uint256(bytes32(bstr)) | bstr.length));
    }

    /**
     * @dev Decode a `ShortString` back to a "normal" string.
     */
    // 解压缩逻辑：将ShortString转换为字符串
    function toString(ShortString sstr) internal pure returns (string memory) {
        // 获取ShortString的内容字节长度
        uint256 len = byteLength(sstr);
        // using `new string(len)` would work locally but is not memory safe.
        // 内存中分配一个字长的空间
        string memory str = new string(0x20);
        assembly ("memory-safe") {
            // 在str处，写入字节长度len，即设置字符串长度头
            mstore(str, len)
            // 在str+1个字处，写入整个ShortString底层的bytes32
            // 这里有个聪明的技巧：虽然 ShortString底层的bytes32 的最后1字节是长度，但是evm在访问该string时只会根据头部指定的 len 来截取显示。所以最后一个字节会被忽略掉，不会影响字符串内容。
            // 这种做法极大地节省了 Gas，因为我们不需要通过复杂的位运算把末尾的长度“抠掉”变成 0 之后再存入内存，直接整块存进去，然后靠 length 变量来限制读取范围即可
            mstore(add(str, 0x20), sstr)
        }

        // 返回str
        return str;
    }

    /**
     * @dev Return the length of a `ShortString`.
     */
    // 获取ShortString的内容字节长度，即取最低8位
    function byteLength(ShortString sstr) internal pure returns (uint256) {
        // 将ShortString拆箱成为bytes32并取最低8位
        uint256 result = uint256(ShortString.unwrap(sstr)) & 0xFF;
        if (result > 0x1f) {
            // 如果取出的长度信息大于31，revert
            revert InvalidShortString();
        }
        // 返回
        return result;
    }

    /**
     * @dev Encode a string into a `ShortString`, or write it to storage if it is too long.
     */
    // 压缩逻辑：带回退机制地将字符串转换为ShortString
    function toShortStringWithFallback(string memory value, string storage store) internal returns (ShortString) {
        if (bytes(value).length < 0x20) {
            // 如果字符串长度小于32字节，直接使用toShortString()直接压缩
            return toShortString(value);
        } else {
            // 如果字符串长度不小于32字节，则将字符串存入传统的 storage 槽位store中
            StorageSlot.getStringSlot(store).value = value;
            // 返回FALLBACK_SENTINEL
            return ShortString.wrap(FALLBACK_SENTINEL);
        }
    }

    /**
     * @dev Decode a string that was encoded to `ShortString` or written to storage using {toShortStringWithFallback}.
     */
    // 解压缩逻辑：带回退机制地将ShortString转换为字符串
    function toStringWithFallback(ShortString value, string storage store) internal pure returns (string memory) {
        if (ShortString.unwrap(value) != FALLBACK_SENTINEL) {
            // 如果输入的ShortString不是FALLBACK_SENTINEL，直接使用toString()解压缩
            return toString(value);
        } else {
            // 如果输入的ShortString是FALLBACK_SENTINEL，说明其字节长度大于31，那么就从传统的 storage 槽位store中将该字符串复制到内存中返回
            return store;
        }
    }

    /**
     * @dev Return the length of a string that was encoded to `ShortString` or written to storage using
     * {toShortStringWithFallback}.
     *
     * WARNING: This will return the "byte length" of the string. This may not reflect the actual length in terms of
     * actual characters as the UTF-8 encoding of a single character can span over multiple bytes.
     */
    // 带回退机制地获取ShortString的内容字节长度
    function byteLengthWithFallback(ShortString value, string storage store) internal view returns (uint256) {
        if (ShortString.unwrap(value) != FALLBACK_SENTINEL) {
            // 如果输入的ShortString不是FALLBACK_SENTINEL，直接使用byteLength()获取字节长度
            return byteLength(value);
        } else {
            // 如果输入的ShortString是FALLBACK_SENTINEL，说明其字节长度大于31，那么就从传统的 storage 槽位store中获取其字节长度
            return bytes(store).length;
        }
    }
}
