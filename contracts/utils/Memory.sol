// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (utils/Memory.sol)

pragma solidity ^0.8.24;

import {Panic} from "./Panic.sol";
import {Math} from "./math/Math.sol";

/**
 * @dev Utilities to manipulate memory.
 *
 * Memory is a contiguous and dynamic byte array in which Solidity stores non-primitive types.
 * This library provides functions to manipulate pointers to this dynamic array and work with slices of it.
 *
 * Slices provide a view into a portion of memory without copying data, enabling efficient substring operations.
 *
 * WARNING: When manipulating memory pointers or slices, make sure to follow the Solidity documentation
 * guidelines for https://docs.soliditylang.org/en/v0.8.20/assembly.html#memory-safety[Memory Safety].
 */
// Memory.sol就是操作内存（Memory）的“显微镜”。它直接操作 Solidity 的内存指针，通过 Slice（切片）技术实现了极高性能的字节处理。
// Slice是该库最灵魂的设计。在传统的 Solidity 中，如果想取一个 bytes 的子集，通常需要创建一个新的 bytes 并通过 mcopy 复制数据，这非常耗费 Gas
// Slice的底层结构：将“长度（length）”和“指针（pointer）”打包进一个单一的 bytes32 中（高 128 位存长度，低 128 位存内存地址）
library Memory {
    // Pointer底层就是一个bytes32，即内存中的地址
    type Pointer is bytes32;

    /// @dev Returns a `Pointer` to the current free `Pointer`.
    // 读取0x40位置的值。在EVM中，0x40 存储的是“空闲内存指针”
    function getFreeMemoryPointer() internal pure returns (Pointer ptr) {
        assembly ("memory-safe") {
            ptr := mload(0x40)
        }
    }

    /**
     * @dev Sets the free `Pointer` to a specific value.
     *
     * WARNING: Everything after the pointer may be overwritten.
     **/
    // 手动设置空闲内存指针。这是一个危险操作，但在某些极致优化场景下（如手动构建复杂的返回数据）非常有用
    function setFreeMemoryPointer(Pointer ptr) internal pure {
        assembly ("memory-safe") {
            mstore(0x40, ptr)
        }
    }

    /// @dev `Pointer` to `bytes32`. Expects a pointer to a properly ABI-encoded `bytes` object.
    // 将一个Pointer类型值解包成原始的 bytes32 值（内存地址）
    function asBytes32(Pointer ptr) internal pure returns (bytes32) {
        return Pointer.unwrap(ptr);
    }

    /// @dev `bytes32` to `Pointer`. Expects a pointer to a properly ABI-encoded `bytes` object.
    // 将一个原始的 bytes32 值（内存地址）包装成 Pointer 类型
    function asPointer(bytes32 value) internal pure returns (Pointer) {
        return Pointer.wrap(value);
    }

    /// @dev Move a pointer forward by a given offset.
    // 指针平移函数，即内存指针ptr向后移动offset个字节
    function forward(Pointer ptr, uint256 offset) internal pure returns (Pointer) {
        return Pointer.wrap(bytes32(uint256(Pointer.unwrap(ptr)) + offset));
    }

    /// @dev Equality comparator for memory pointers.
    // 指针相等判定，即比较两个指针的地址值是否相等
    function equal(Pointer ptr1, Pointer ptr2) internal pure returns (bool) {
        return Pointer.unwrap(ptr1) == Pointer.unwrap(ptr2);
    }

    // Slice类型底层就是一个bytes32，(高128位)bytes长度 + (低128位)bytes数据内容的实际地址
    type Slice is bytes32;

    /// @dev Get a slice representation of a bytes object in memory
    // 将标准的 Solidity bytes 转换为Slice类型。这是一个零拷贝操作，只是把长度和地址打包在一起
    function asSlice(bytes memory self) internal pure returns (Slice result) {
        assembly ("memory-safe") {
            // mload(self)：提取bytes的长度
            // shl(128, mload(self))：将bytes的长度左移128位
            // add(self, 0x20) 跳过长度头，得到数据内容的实际地址，放在低位
            result := or(shl(128, mload(self)), add(self, 0x20))
        }
    }

    /// @dev Returns the length of a given slice (equiv to self.length for calldata slices)
    // 获取该Slice的数据内容的字节长度
    function length(Slice self) internal pure returns (uint256 result) {
        assembly ("memory-safe") {
            // 右移 128 位，提取出存放在高128位的长度值
            result := shr(128, self)
        }
    }

    /// @dev Offset a memory slice (equivalent to self[start:] for calldata slices)
    // 提取本Slice的子切片，即self[offset:]
    function slice(Slice self, uint256 offset) internal pure returns (Slice) {
        // 如果偏移量大于原Slice本身数据字节长度，panic
        if (offset > length(self)) Panic.panic(Panic.ARRAY_OUT_OF_BOUNDS);
        // 子切片的数据长度为length(self) - offset，实际数据起始地址为原切片数据地址+offset
        return _asSlice(length(self) - offset, forward(_pointer(self), offset));
    }

    /// @dev Offset and cut a Slice (equivalent to self[start:start+length] for calldata slices)
    // 提取本Slice的子切片，即self[offset: offset+len]
    function slice(Slice self, uint256 offset, uint256 len) internal pure returns (Slice) {
        // 如果偏移量大于原Slice本身数据字节长度，panic
        if (offset + len > length(self)) Panic.panic(Panic.ARRAY_OUT_OF_BOUNDS);
        // 子切片的数据长度为len，实际数据起始地址为原切片数据地址+offset
        return _asSlice(len, forward(_pointer(self), offset));
    }

    /**
     * @dev Read a bytes32 buffer from a given Slice at a specific offset
     *
     * NOTE: If offset > length(slice) - 0x20, part of the return value will be out of bound of the slice. These bytes are zeroed.
     */
    // 从原切片的offset位置读取 32 字节（一个字）的内容。
    // 注：它的强大之处在于：即使你读取的位置靠近切片末尾，它也能保证你不会读到切片之外的“脏数据”。集在读到的一个字的256位中，会将切片外的部分置0。
    function load(Slice self, uint256 offset) internal pure returns (bytes32 value) {
        // 0x20 + offset为预期读取的终点位置
        // outOfBoundBytesw为读取的越界字节数，即你想读的这32个字节中有多少个字节落在Slice的范围之外的
        // 注：Math.saturatingSub(a, b)为饱和减法，即如果a > b，返回a - b；如果a<=b，则返回 0
        uint256 outOfBoundBytes = Math.saturatingSub(0x20 + offset, length(self));
        // 越界检查
        // 如果预期读取的字节数有超过31个落在Slice范围之外，直接panic
        if (outOfBoundBytes > 0x1f) Panic.panic(Panic.ARRAY_OUT_OF_BOUNDS);

        // 提取指针并读取，同时配合掩码清理
        assembly ("memory-safe") {
            // mload(add(and(self, shr(128, not(0))), offset))：提取原slice中的实际数据起始位置指针（低128位）并加上偏移量offset，然后从内存中从上述地址读出1个字的内容
            // shl(mul(8, outOfBoundBytes), not(0))：构建掩码0xff..ff00..00，低位0的个数为outOfBoundBytes*8
            // 将超出Slice范围之外的bit都置0
            value := and(mload(add(and(self, shr(128, not(0))), offset)), shl(mul(8, outOfBoundBytes), not(0)))
        }
    }

    /// @dev Extract the data corresponding to a Slice (allocate new memory)
    // 将当前切片转换成标准的 Solidity bytes
    function toBytes(Slice self) internal pure returns (bytes memory result) {
        // 当前切片中的数据长度
        uint256 len = length(self);
        // 当前切片中的数据内容的实际起始地址
        Memory.Pointer ptr = _pointer(self);
        assembly ("memory-safe") {
            // 获取内存中空闲指针地址result（bytes的本质其实就是内存中的起始地址）
            result := mload(0x40)
            // 在result处先写入数据长度len
            mstore(result, len)
            // 将[ptr:ptr+len]的内容复制到result+32开始的内存中
            // 注：mcopy(dest, src, size)，是Solidity 0.8.24引入的新操作码，即将[src,src+size]的内容复制到dest开始的内存中
            // 在mcopy出现前，如果想要在内存中把src开始的数据复制到dest上，有两种方法：
            // 1. 手写循环：依次使用 mload 读取 32 字节，再用 mstore 写入 32 字节。
            //      缺点：对于长数据，Gas 消耗随长度线性激增；且需要处理末尾不足 32 字节的对齐问题，代码极其臃肿
            // 2. 调用 identity 预编译合约:
            //         assembly {
            //            // 调用地址为 0x04 的预编译合约
            //            let success := staticcall(gas(), 0x04, src, size, dest, size)
            //            if iszero(success) { revert(0, 0) }
            //          }
            //      缺点：虽然比循环快，但触发一次 staticcall 需要 700 Gas 的基础开销。此外，它涉及上下文切换，增加了不必要的开销。
            mcopy(add(result, 0x20), ptr, len)
            // 更新空闲内存指针
            mstore(0x40, add(add(result, len), 0x20))
        }
    }

    /**
     * @dev Private helper: create a slice from raw values (length and pointer)
     *
     * NOTE: this function MUST NOT be called with `len` or `ptr` that exceed `2**128-1`. This should never be
     * the case of slices produced by `asSlice(bytes)`, and function that reduce the scope of slices
     * (`slice(Slice,uint256)` and `slice(Slice,uint256, uint256)`) should not cause this issue if the parent slice is
     * correct.
     */
    // 将实际字节长度len和数据内容的实际地址ptr压缩成一个Slice变量
    function _asSlice(uint256 len, Memory.Pointer ptr) private pure returns (Slice result) {
        assembly ("memory-safe") {
            // len移到高128位，ptr放在低128位
            result := or(shl(128, len), ptr)
        }
    }

    /// @dev Returns the memory location of a given slice (equiv to self.offset for calldata slices)
    // 获取一个Slice变量中的数据内容的实际起始地址，该地址是以Pointer变量的形式返回
    // 即Slice底层的低128位变成一个Pointer变量
    function _pointer(Slice self) private pure returns (Memory.Pointer result) {
        assembly ("memory-safe") {
            result := and(self, shr(128, not(0)))
        }
    }
}
