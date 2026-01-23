// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/structs/DoubleEndedQueue.sol)
pragma solidity ^0.8.20;

import {Panic} from "../Panic.sol";

/**
 * @dev A sequence of items with the ability to efficiently push and pop items (i.e. insert and remove) on both ends of
 * the sequence (called front and back). Among other access patterns, it can be used to implement efficient LIFO and
 * FIFO queues. Storage use is optimized, and all operations are O(1) constant time. This includes {clear}, given that
 * the existing queue contents are left in storage.
 *
 * The struct is called `Bytes32Deque`. Other types can be cast to and from `bytes32`. This data structure can only be
 * used in storage, and not in memory.
 * ```solidity
 * DoubleEndedQueue.Bytes32Deque queue;
 * ```
 */
// DoubleEndedQueue库实现了双端队列（Double-Ended Queue，简称 Deque）。两端都能以 O(1) 复杂度进行增删的数据结构。这比普通的 Solidity 数组（只能在末尾高效操作，在头部操作需要移动所有元素）要高效得多。
// 实际使用场景：
// 1. 借贷协议中的“清算队列”: 当系统发现某些仓位由于价格波动需要被清算时，将这些仓位 ID 放入队列。如果某个极其危险的仓位需要“插队”，可以使用 pushFront 把它直接塞到队首。
// 2. 治理系统中的“待办提案”：治理合约维护一个按时间顺序排列的提案队列。新提案通过审核后 pushBack 到末尾，执行器从 front() 开始检查，如果时间到了，就 popFront 出来执行。如果提案被取消或失败，可以从队尾（如果是最新的）用 popBack 快速移除。
library DoubleEndedQueue {
    /**
     * @dev Indices are 128 bits so begin and end are packed in a single storage slot for efficient access.
     *
     * Struct members have an underscore prefix indicating that they are "private" and should not be read or written to
     * directly. Use the functions provided below instead. Modifying the struct manually may violate assumptions and
     * lead to unexpected behavior.
     *
     * The first item is at data[begin] and the last item is at data[end - 1]. This range can wrap around.
     */
    struct Bytes32Deque {
        // 数据永远存在于 [_begin, _end) 这个左闭右开的区间内
        uint128 _begin;
        uint128 _end;
        // 它并不使用真实的“物理数组”，而是利用 mapping。
        // 由于 uint128 的范围极大且支持溢出回绕（Wrapping），可以把它想象成一个巨大的圆形传送带
        mapping(uint128 index => bytes32) _data;
    }

    /**
     * @dev Inserts an item at the end of the queue.
     *
     * Reverts with {Panic-RESOURCE_ERROR} if the queue is full.
     */
    // 尾部入队
    function pushBack(Bytes32Deque storage deque, bytes32 value) internal {
        unchecked {
            uint128 backIndex = deque._end;
            // 如果 end+1 追上了 begin，说明距离 2^128 个位置全占满还差1个位置（极难发生），revert
            if (backIndex + 1 == deque._begin) Panic.panic(Panic.RESOURCE_ERROR);
            // mapping中加入数据（key为deque._end）
            deque._data[backIndex] = value;
            // deque._end自增1（允许溢出）
            deque._end = backIndex + 1;
        }
    }

    /**
     * @dev Removes the item at the end of the queue and returns it.
     *
     * Reverts with {Panic-EMPTY_ARRAY_POP} if the queue is empty.
     */
    // 尾部出队，返回出队值
    function popBack(Bytes32Deque storage deque) internal returns (bytes32 value) {
        unchecked {
            uint128 backIndex = deque._end;
            // 如果deque._end==deque._begin，表示是空队列，无法出队，revert
            if (backIndex == deque._begin) Panic.panic(Panic.EMPTY_ARRAY_POP);
            // backIndex自减1，该位置是尾部最后一个元素的index（允许溢出）
            --backIndex;
            // 获取尾部元素
            value = deque._data[backIndex];
            // 删除mapping中的尾部元素
            delete deque._data[backIndex];
            // 更新storage中的尾index
            deque._end = backIndex;
        }
    }

    /**
     * @dev Inserts an item at the beginning of the queue.
     *
     * Reverts with {Panic-RESOURCE_ERROR} if the queue is full.
     */
    // 头部入队
    function pushFront(Bytes32Deque storage deque, bytes32 value) internal {
        unchecked {
            // 头部index前移（允许溢出）
            uint128 frontIndex = deque._begin - 1;
            // 如果 _begin - 1 追上了 _end，说明距离2^128 个位置全占满还差1个位置（极难发生），revert
            if (frontIndex == deque._end) Panic.panic(Panic.RESOURCE_ERROR);
            // mapping中加入数据（key为deque._begin - 1）
            deque._data[frontIndex] = value;
            // 更新deque._begin
            deque._begin = frontIndex;
        }
    }

    /**
     * @dev Removes the item at the beginning of the queue and returns it.
     *
     * Reverts with {Panic-EMPTY_ARRAY_POP} if the queue is empty.
     */
    // 头部出队，返回出队值
    function popFront(Bytes32Deque storage deque) internal returns (bytes32 value) {
        unchecked {
            uint128 frontIndex = deque._begin;
            // 如果deque._end==deque._begin，表示是空队列，无法出队，revert
            if (frontIndex == deque._end) Panic.panic(Panic.EMPTY_ARRAY_POP);
            // 获取头部元素
            value = deque._data[frontIndex];
            // 删除mapping中的头部元素
            delete deque._data[frontIndex];
            // 更新storage中的头index（后移且允许溢出）
            deque._begin = frontIndex + 1;
        }
    }

    /**
     * @dev Returns the item at the beginning of the queue.
     *
     * Reverts with {Panic-ARRAY_OUT_OF_BOUNDS} if the queue is empty.
     */
    // 获取队头元素
    function front(Bytes32Deque storage deque) internal view returns (bytes32 value) {
        // 如果当前双端队列为空队列，revert
        if (empty(deque)) Panic.panic(Panic.ARRAY_OUT_OF_BOUNDS);
        // 取头index对应的值
        return deque._data[deque._begin];
    }

    /**
     * @dev Returns the item at the end of the queue.
     *
     * Reverts with {Panic-ARRAY_OUT_OF_BOUNDS} if the queue is empty.
     */
    // 获取队尾元素
    function back(Bytes32Deque storage deque) internal view returns (bytes32 value) {
        // 如果当前双端队列为空队列，revert
        if (empty(deque)) Panic.panic(Panic.ARRAY_OUT_OF_BOUNDS);
        unchecked {
            // 取尾index-1对应的值（允许溢出）
            return deque._data[deque._end - 1];
        }
    }

    /**
     * @dev Return the item at a position in the queue given by `index`, with the first item at 0 and last item at
     * `length(deque) - 1`.
     *
     * Reverts with {Panic-ARRAY_OUT_OF_BOUNDS} if the index is out of bounds.
     */
    // 获取队列中第i个元素（如果是第1个，index为0）
    function at(Bytes32Deque storage deque, uint256 index) internal view returns (bytes32 value) {
        // index 必须小于当前队列的长度
        if (index >= length(deque)) Panic.panic(Panic.ARRAY_OUT_OF_BOUNDS);
        // By construction, length is a uint128, so the check above ensures that index can be safely downcast to uint128
        unchecked {
            // 读取key为deque._begin + index的元素并返回
            // 注：前面的检查已经保证uint128(index)是安全的，不会发生截断
            return deque._data[deque._begin + uint128(index)];
        }
    }

    /**
     * @dev Resets the queue back to being empty.
     *
     * NOTE: The current items are left behind in storage. This does not affect the functioning of the queue, but misses
     * out on potential gas refunds.
     */
    // 重置当前双端队列
    // 注：mapping中的原有数据不会被删除
    function clear(Bytes32Deque storage deque) internal {
        // 极速重置，只需修改头尾两个index
        deque._begin = 0;
        deque._end = 0;
    }

    /**
     * @dev Returns the number of items in the queue.
     */
    // 获取当前双端队列中的元素个数，即队长
    function length(Bytes32Deque storage deque) internal view returns (uint256) {
        unchecked {
            return uint256(deque._end - deque._begin);
        }
    }

    /**
     * @dev Returns true if the queue is empty.
     */
    // 查询当前双端队列是否为空
    function empty(Bytes32Deque storage deque) internal view returns (bool) {
        // 头index于尾index相等时即为空
        return deque._end == deque._begin;
    }
}
