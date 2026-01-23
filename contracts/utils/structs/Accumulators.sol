// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (utils/structs/Accumulators.sol)

pragma solidity ^0.8.24;

import {Memory} from "../Memory.sol";

/**
 * @dev Structure concatenating an arbitrary number of bytes buffers with limited memory allocation.
 *
 * The Accumulators library provides a memory-efficient alternative to repeated concatenation of bytes.
 * Instead of copying data on each concatenation (O(n**2) complexity), it builds a linked list of references
 * to existing data and performs a single memory allocation during flattening (O(n) complexity).
 *
 * Uses 0x00 as sentinel value for empty state (i.e. null pointers)
 *
 * ==== How it works
 *
 * 1. Create an empty accumulator with null head/tail pointers
 * 2. Add data using {push} (append) or {shift} (prepend). It creates linked list nodes
 * 3. Each node stores a reference to existing data (no copying)
 * 4. Call {flatten} to materialize the final concatenated result in a single operation
 *
 * ==== Performance
 *
 * * Addition: O(1) per operation (just pointer manipulation)
 * * Flattening: O(n) single pass with one memory allocation
 * * Memory: Minimal overhead until flattening (only stores references)
 */
// Accumulators是一个极其高效的内存工具。它的核心逻辑是：“先存引用，最后统一拼装”，旨在解决 Solidity 中 bytes.concat 性能低下的问题
// 在 Solidity 中，如果你多次执行字符串或字节拼接：
//              bytes memory a = abi.encodePacked(a, b);
//              a = abi.encodePacked(a, c);
// 每次拼接，EVM 都会申请一段全新的内存，并把旧数据拷贝过去。
// Accumulators库改用链表结构：添加时：只存指针，不拷贝数据。最后：调用 flatten 时，一次性申请所有内存并完成拷贝。
library Accumulators {
    using Memory for *;

    /**
     * @dev Bytes accumulator: a linked list of `bytes`.
     *
     * NOTE: This is a memory structure that SHOULD not be put in storage.
     */
    // 可以理解为是一个链表
    struct Accumulator {
        // 链表头指针
        Memory.Pointer head;
        // 链表尾指针
        Memory.Pointer tail;
    }

    /// @dev Item (list node) in a bytes accumulator
    // 链表中的一个节点
    struct AccumulatorEntry {
        // 指向下一个节点的指针
        Memory.Pointer next;
        // 存储数据片段的引用（不存储副本）
        Memory.Slice data;
    }

    /// @dev Create a new (empty) accumulator
    // 初始化一个accumulator对象
    function accumulator() internal pure returns (Accumulator memory self) {
        // 将头尾指针设为 0x00（空）
        self.head = _nullPtr();
        self.tail = _nullPtr();
    }

    /// @dev Add a bytes buffer to (the end of) an Accumulator
    // 在链表的尾部添加bytes内容data
    function push(Accumulator memory self, bytes memory data) internal pure returns (Accumulator memory) {
        return push(self, data.asSlice());
    }

    /// @dev Add a memory slice to (the end of) an Accumulator
    // 在链表的尾部添加Memory.Slice内容data
    function push(Accumulator memory self, Memory.Slice data) internal pure returns (Accumulator memory) {
        // 创建一个新节点，next为0，数据是传入的data
        Memory.Pointer ptr = _asPtr(AccumulatorEntry({next: _nullPtr(), data: data}));

        if (_nullPtr().equal(self.head)) {
            // 如果整个链表还没有添加过节点，即第一个节点，将head和tail都指向新节点
            self.head = ptr;
            self.tail = ptr;
        } else {
            // 不是第一个节点的话，将当前尾部节点的 next 指向新节点，并将尾部指针指向新节点
            _asAccumulatorEntry(self.tail).next = ptr;
            self.tail = ptr;
        }

        return self;
    }

    /// @dev Add a bytes buffer to (the beginning of) an Accumulator
    // 在链表的头部添加bytes内容data
    function shift(Accumulator memory self, bytes memory data) internal pure returns (Accumulator memory) {
        return shift(self, data.asSlice());
    }

    /// @dev Add a memory slice to (the beginning of) an Accumulator
    // 在链表的头部添加Memory.Slice内容data
    function shift(Accumulator memory self, Memory.Slice data) internal pure returns (Accumulator memory) {
        // 创建一个新节点，next 指向当前链表的 head，实现“插队”，数据是传入的data
        Memory.Pointer ptr = _asPtr(AccumulatorEntry({next: self.head, data: data}));

        if (_nullPtr().equal(self.head)) {
            // 如果整个链表还没有添加过节点，即第一个节点，将head和tail都指向新节点
            self.head = ptr;
            self.tail = ptr;
        } else {
            // 不是第一个节点的话，将当前头部指针指向新节点
            self.head = ptr;
        }

        return self;
    }

    /// @dev Flatten all the bytes entries in an Accumulator into a single buffer
    // 将链表中的节点的data依次写入一个bytes buffer中
    // 注：是整个库技术含量最高的地方，通过汇编一次性完成内存分配和数据填充
    function flatten(Accumulator memory self) internal pure returns (bytes memory result) {
        assembly ("memory-safe") {
            // 获取自由指针
            result := mload(0x40)
            // 数据起始位置（跳过长度字段）
            let ptr := add(result, 0x20)
            // 遍历链表
            for {
                // 获取Accumulator的head指针
                let it := mload(self)
            } iszero(iszero(it)) {
                // 如果it不为0，即不是空指针，获取其指向的AccumulatorEntry
                // 即移动到下一个节点 —— it = it.next
                it := mload(it)
            } {
                // 获取AccumulatorEntry.data的指针
                // 注：data是一个Memory.Slice，其底层就是一个bytes32，(高128位)bytes长度 + (低128位)bytes数据内容的实际地址
                let slice := mload(add(it, 0x20))
                // 提取slice的低128位，即bytes数据内容的实际起始地址
                let offset := and(slice, shr(128, not(0)))
                // 提取slice的高128位，即bytes数据内容的字节长度
                let length := shr(128, slice)
                // 使用 Cancun 升级的 mcopy 指令将bytes数据内容复制到ptr开始的地址中
                mcopy(ptr, offset, length)
                // 完成复制后，将ptr向后移动length个字节
                ptr := add(ptr, length)
            }
            // 遍历完整个链表后，计算合并后的总bytes字节数，然后将其写入result的头部
            mstore(result, sub(ptr, add(result, 0x20)))
            // 更新自由指针
            mstore(0x40, ptr)
        }
    }

    // 将结构体AccumulatorEntry引用转为指针
    // 即，内存中“solidity高级结构体”到“逻辑指针”的无损转换
    function _asPtr(AccumulatorEntry memory item) private pure returns (Memory.Pointer ptr) {
        assembly ("memory-safe") {
            // 注：item 在assembly块中代表的就是该结构体在内存里的偏移量
            ptr := item
        }
    }

    // 将指针转回结构体AccumulatorEntry引用
    // 即，_asPtr()的逆过程
    function _asAccumulatorEntry(Memory.Pointer ptr) private pure returns (AccumulatorEntry memory item) {
        assembly ("memory-safe") {
            item := ptr
        }
    }

    // 返回一个指向 0x00 的逻辑空指针
    function _nullPtr() private pure returns (Memory.Pointer) {
        return Memory.asPointer(0x00);
    }
}
