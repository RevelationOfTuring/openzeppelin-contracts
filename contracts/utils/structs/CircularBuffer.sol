// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (utils/structs/CircularBuffer.sol)

pragma solidity ^0.8.24;

import {Math} from "../math/Math.sol";
import {Arrays} from "../Arrays.sol";
import {Panic} from "../Panic.sol";

/**
 * @dev A fixed-size buffer for keeping `bytes32` items in storage.
 *
 * This data structure allows for pushing elements to it, and when its length exceeds the specified fixed size,
 * new items take the place of the oldest element in the buffer, keeping at most `N` elements in the
 * structure.
 *
 * Elements can't be removed but the data structure can be cleared. See {clear}.
 *
 * Complexity:
 * - insertion ({push}): O(1)
 * - lookup ({last}): O(1)
 * - inclusion ({includes}): O(N) (worst case)
 * - reset ({clear}): O(1)
 *
 * The struct is called `Bytes32CircularBuffer`. Other types can be cast to and from `bytes32`. This data structure
 * can only be used in storage, and not in memory.
 *
 * Example usage:
 *
 * ```solidity
 * contract Example {
 *     // Add the library methods
 *     using CircularBuffer for CircularBuffer.Bytes32CircularBuffer;
 *
 *     // Declare a buffer storage variable
 *     CircularBuffer.Bytes32CircularBuffer private myBuffer;
 * }
 * ```
 *
 * _Available since v5.1._
 */
// CircularBuffer提供了一个非常实用的存储数据结构：环形缓冲区
// 给定一个固定大小 N 的空间，当存入第 N+1 个元素时，它会自动覆盖最旧的那个元素。 这在处理“最近 N 次交易记录”、“最近 N 个价格点”或“操作日志”时极其节省 Gas，因为你不需要移动数组元素，只需要循环利用空间
// 使用场景：
// 1. 喂价机记录：存储过去 10 个区块的价格，用来计算移动平均值。
// 2. 防止闪电贷攻击：记录最近几次操作的地址，防止同一人在极短时间内反复重置状态。
// 3. 治理历史：记录最近 5 次投票的状态变更。
library CircularBuffer {
    /**
     * @dev Error emitted when trying to setup a buffer with a size of 0.
     */
    error InvalidBufferSize();

    /**
     * @dev Counts the number of items that have been pushed to the buffer. The residuo modulo _data.length indicates
     * where the next value should be stored.
     *
     * Struct members have an underscore prefix indicating that they are "private" and should not be read or written to
     * directly. Use the functions provided below instead. Modifying the struct manually may violate assumptions and
     * lead to unexpected behavior.
     *
     * In a full buffer:
     * - The most recently pushed item (last) is at data[(index - 1) % data.length]
     * - The oldest item (first) is at data[index % data.length]
     */
    // 核心数据结构
    struct Bytes32CircularBuffer {
        // 记录总共 push 了多少次（会持续增长，不封顶）
        // 设计巧妙之处：_count 并不是当前缓冲区里的元素个数，而是历史累计存入的总数。通过 _count % _data.length 就能永远计算出下一个该存入的位置
        uint256 _count;
        // 实际存储数据的固定长度数组
        bytes32[] _data;
    }

    /**
     * @dev Initialize a new CircularBuffer of a given size.
     *
     * If the CircularBuffer was already setup and used, calling that function again will reset it to a blank state.
     *
     * NOTE: The size of the buffer will affect the execution of {includes} function, as it has a complexity of O(N).
     * Consider a large buffer size may render the function unusable.
     */
    // 初始化，size为环形缓冲区长度
    function setup(Bytes32CircularBuffer storage self, uint256 size) internal {
        // 缓冲区长度不能为0
        if (size == 0) revert InvalidBufferSize();
        // 历史累计存入的总数清0
        clear(self);
        // 强制设置底层数组长度，避免手动 push 导致的 Gas 消耗
        // 注：这比普通的 new bytes32[](size) 更高效，因为它直接修改存储槽里的长度字段
        Arrays.unsafeSetLength(self._data, size);
    }

    /**
     * @dev Clear all data in the buffer without resetting memory, keeping the existing size.
     */
    // 重置计数器
    // 注：只会将历史总存入数量清零，但是并不会清除之前存入的具体数据
    function clear(Bytes32CircularBuffer storage self) internal {
        self._count = 0;
    }

    /**
     * @dev Push a new value to the buffer. If the buffer is already full, the new value replaces the oldest value in
     * the buffer.
     */
    // 存入数据
    function push(Bytes32CircularBuffer storage self, bytes32 value) internal {
        // 获取当前序号，然后自增
        uint256 index = self._count++;
        // // 缓冲区总容量
        uint256 modulus = self._data.length;
        // 通过取模运算（%）实现“环形”效果（取模后的值即为在数组中的index）
        // 然后在对应slot处写入数据value
        Arrays.unsafeAccess(self._data, index % modulus).value = value;
    }

    /**
     * @dev Number of values currently in the buffer. This value is 0 for an empty buffer, and cannot exceed the size of
     * the buffer.
     */
    // 获取当前有效元素数
    function count(Bytes32CircularBuffer storage self) internal view returns (uint256) {
        // 如果存入数据还不够环形缓冲区长度，返回历史总存入次数；如果够了，返回环形缓冲区长度
        return Math.min(self._count, self._data.length);
    }

    /**
     * @dev Length of the buffer. This is the maximum number of elements kept in the buffer.
     */
    // 返回环形缓冲区长度
    function length(Bytes32CircularBuffer storage self) internal view returns (uint256) {
        return self._data.length;
    }

    /**
     * @dev Getter for the i-th value in the buffer, from the end.
     *
     * Reverts with {Panic-ARRAY_OUT_OF_BOUNDS} if trying to access an element that was not pushed, or that was
     * dropped to make room for newer elements.
     */
    // 这是最常用的功能：获取“倒数第i次”存入的数据。
    // 注：要查最近一次存入的数据，i为0
    function last(Bytes32CircularBuffer storage self, uint256 i) internal view returns (bytes32) {
        // 历史总添加次数
        uint256 index = self._count;
        // 环形缓冲区长度
        uint256 modulus = self._data.length;
        // 以上二者取最小值，即环形缓冲区内当前有效元素数
        uint256 total = Math.min(index, modulus); // count(self)
        // i要做索引，所以必须小于total
        if (i >= total) {
            Panic.panic(Panic.ARRAY_OUT_OF_BOUNDS);
        }
        // 从底层数组取索引为(index - i - 1) % modulus的值
        return Arrays.unsafeAccess(self._data, (index - i - 1) % modulus).value;
    }

    /**
     * @dev Check if a given value is in the buffer.
     */
    // 检查数据值value是否存在于环形缓冲区中
    function includes(Bytes32CircularBuffer storage self, bytes32 value) internal view returns (bool) {
        // 历史总添加次数
        uint256 index = self._count;
        // 环形缓冲区长度
        uint256 modulus = self._data.length;
        // 以上二者取最小值，即环形缓冲区内当前有效元素数
        uint256 total = Math.min(index, modulus); // count(self)
        // 遍历底层的数组，如果发现有value值，直接return true
        for (uint256 i = 0; i < total; ++i) {
            if (Arrays.unsafeAccess(self._data, (index - i - 1) % modulus).value == value) {
                return true;
            }
        }
        // 循环正常结束，说明value值不在数组内，返回false
        return false;
    }
}
