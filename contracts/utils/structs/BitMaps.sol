// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/structs/BitMaps.sol)
pragma solidity ^0.8.20;

/**
 * @dev Library for managing uint256 to bool mapping in a compact and efficient way, provided the keys are sequential.
 * Largely inspired by Uniswap's https://github.com/Uniswap/merkle-distributor/blob/master/contracts/MerkleDistributor.sol[merkle-distributor].
 *
 * BitMaps pack 256 booleans across each bit of a single 256-bit slot of `uint256` type.
 * Hence booleans corresponding to 256 _sequential_ indices would only consume a single slot,
 * unlike the regular `bool` which would consume an entire slot for a single value.
 *
 * This results in gas savings in two ways:
 *
 * - Setting a zero value to non-zero only once every 256 times
 * - Accessing the same warm slot for every 256 _sequential_ indices
 */
// 背景：在 Solidity 中，一个标准的 mapping(uint256 => bool) 虽然逻辑简单，但每个 bool 都会占用一个完整的 32 字节（256 位）存储槽。
// 而 BitMap 利用位运算，将 256 个布尔值挤进同一个 uint256 槽位中，存储效率直接提升了 256 倍。
// BitMaps库就是一个省钱（Gas优化）高效的mapping(uint256 => bool)，如果你的业务逻辑经常需要批量处理连续的 ID（如：检查空投领取状态、检查 NFT 是否被使用），BitMap 的性能优势是压倒性的
// 为什么BitMap能大幅度节省Gas？
// 答：在以太坊存储中，“写操作”是最贵的，尤其是将一个值从 0 变为非 0（SSTORE 需要 20,000 Gas）。当你使用 mapping(uint256 => bool) 设置 256 个值时，你需要支付 256 * 20,000 Gas。
// 使用 BitMap 时，只有在设置该桶的第一个值时需要 20,000 Gas。接下来的 255 次设置，因为是在修改同一个已经变成非 0 的“热槽位”（Warm Slot），每次只需约 5,000 Gas 甚至更少（取决于 EIP-2929 的缓存机制）。
library BitMaps {
    struct BitMap {
        // 每个bucket是一个 uint256，它内部有 256 个“位”（bit），每一位代表一个布尔值
        // 映射关系：索引 0-255 在桶 0，256-511 在桶 1，以此类推
        mapping(uint256 bucket => uint256) _data;
    }

    /**
     * @dev Returns whether the bit at `index` is set.
     */
    // 查询某一位的状态
    function get(BitMap storage bitmap, uint256 index) internal view returns (bool) {
        // 先确定index在哪个桶：index / 256（右移 8 位等于除以 256）
        uint256 bucket = index >> 8;
        // index & 0xff是 index % 256的极速写法，得到桶里的哪一位
        // 1 << (index & 0xff)即得到了该位的掩码
        uint256 mask = 1 << (index & 0xff);
        // 提取出该一位的值，如果不等于 0，说明该位是 1 (true)
        return bitmap._data[bucket] & mask != 0;
    }

    /**
     * @dev Sets the bit at `index` to the boolean `value`.
     */
    // 将index对应在BitMap中的位设为value
    function setTo(BitMap storage bitmap, uint256 index, bool value) internal {
        if (value) {
            // 如果value为true，执行set()
            set(bitmap, index);
        } else {
            // 如果value为false，执行unset()
            unset(bitmap, index);
        }
    }

    /**
     * @dev Sets the bit at `index`.
     */
    // 将index对应在BitMap中的位设为1（true）
    function set(BitMap storage bitmap, uint256 index) internal {
        // 先确定index在哪个桶
        uint256 bucket = index >> 8;
        // 后确定index是在该桶中的第几位并得到掩码
        uint256 mask = 1 << (index & 0xff);
        // 使用“位或”赋值 (|=)：
        // 无论原来的位是 0 还是 1，与 1 进行“或”运算后都会变成 1
        bitmap._data[bucket] |= mask;
    }

    /**
     * @dev Unsets the bit at `index`.
     */
    // 将index对应在BitMap中的位设为0（false）
    function unset(BitMap storage bitmap, uint256 index) internal {
        // 先确定index在哪个桶
        uint256 bucket = index >> 8;
        // 后确定index是在该桶中的第几位并得到掩码
        uint256 mask = 1 << (index & 0xff);
        // 使用“位与”赋值 (&=)：
        // 无论原来的位是 0 还是 1，与 0 进行“与”运算后都会变成 0
        bitmap._data[bucket] &= ~mask;
    }
}
