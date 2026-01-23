// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (utils/types/Time.sol)

pragma solidity ^0.8.20;

import {Math} from "../math/Math.sol";
import {SafeCast} from "../math/SafeCast.sol";

/**
 * @dev This library provides helpers for manipulating time-related objects.
 *
 * It uses the following types:
 * - `uint48` for timepoints
 * - `uint32` for durations
 *
 * While the library doesn't provide specific types for timepoints and duration, it does provide:
 * - a `Delay` type to represent duration that can be programmed to change value automatically at a given point
 * - additional helper functions
 */
// Time库是一个非常实用的时间管理库。它的核心亮点在于提供了一种名为 Delay 的复杂数据类型，专门用于解决 “延迟参数修改” 的安全问题（例如防止管理员突然将提款延迟从 7 天改为 0 天）。
// 使用场景：主要用于那些“一旦规则改变，必须给用户留出逃生时间”的高安全性场景：
// 1. 资金锁定期，提款锁定期；
// 2. 系统升级观察期；
// 3. 治理中的参数，比如“清算线”或“手续费率”。例子：如果管理员突然把手续费从 1% 改到 50%，用户在交易确认前根本无法撤出资金。如果希望实现费率增加越多，生效越慢的效果（确保用户有时间在昂贵的费率生效前关闭仓位），但是需要反转withUpdate()中关于setback计算的逻辑。
library Time {
    using Time for *;

    /**
     * @dev Get the block timestamp as a Timepoint.
     */
    // 将block.timestamp从uint256安全转换成uint48
    // 注：uint48 足以支撑到公元 8,921,556 年，而在结构体中使用 uint48 可以极大地优化内存对齐，节省存储成本（Gas）
    function timestamp() internal view returns (uint48) {
        return SafeCast.toUint48(block.timestamp);
    }

    /**
     * @dev Get the block number as a Timepoint.
     */
    // 将block.number从uint256安全转换成uint48
    function blockNumber() internal view returns (uint48) {
        return SafeCast.toUint48(block.number);
    }

    // ==================================================== Delay =====================================================
    /**
     * @dev A `Delay` is a uint32 duration that can be programmed to change value automatically at a given point in the
     * future. The "effect" timepoint describes when the transition happens from the "old" value to the "new" value.
     * This allows updating the delay applied to some operation while keeping some guarantees.
     *
     * In particular, the {update} function guarantees that if the delay is reduced, the old delay still applies for
     * some time. For example if the delay is currently 7 days to do an upgrade, the admin should not be able to set
     * the delay to 0 and upgrade immediately. If the admin wants to reduce the delay, the old delay (7 days) should
     * still apply for some time.
     *
     *
     * The `Delay` type is 112 bits long, and packs the following:
     *
     * ```
     *   | [uint48]: effect date (timepoint)
     *   |           | [uint32]: value before (duration)
     *   ↓           ↓       ↓ [uint32]: value after (duration)
     * 0xAAAAAAAAAAAABBBBBBBBCCCCCCCC
     * ```
     *
     * NOTE: The {get} and {withUpdate} functions operate using timestamps. Block number based delays are not currently
     * supported.
     */
    // Delay 不是一个简单的数值，而是一个平滑过渡器。 为了节省 Gas，它把三个字段打包进了一个 uint112（占用不到一个 Slot），字段依次为：
    // - effect：uint48，新配置生效的时间点
    // - valueBefore：uint32，达到生效点之前的旧值
    // - valueAfter：uint32，达到生效点之后的新值
    // uint112中从高位到低位：effect + valueBefore + valueAfter
    type Delay is uint112;

    /**
     * @dev Wrap a duration into a Delay to add the one-step "update in the future" feature
     */
    // 将一个uint32是时间长度包租航程一个Delay对象，其中，生效时间点effect和旧值都是0，但是新值是duration。
    // 即创建了一个已经生效的、没有挂起更新的初始状态。
    // 当你第一次部署合约，需要设置一个初始的延迟（比如 3 天）时，你还没有任何“旧值”或“待生效的新值”。这时候就用该函数。
    // 可以理解为该函数创建了一个启动器。
    function toDelay(uint32 duration) internal pure returns (Delay) {
        return Delay.wrap(duration);
    }

    /**
     * @dev Get the value at a given timepoint plus the pending value and effect timepoint if there is a scheduled
     * change after this timepoint. If the effect timepoint is 0, then the pending value should not be considered.
     */
    // 获取Delay表示的有效值。timepoint为作为基准的时间戳。
    // 如果timepoint还没到 effect 时间点，读取到的就是 valueBefore；如果到了或超过，自动切换到 valueAfter。不需要手动触发更新
    function _getFullAt(
        Delay self,
        uint48 timepoint
    ) private pure returns (uint32 valueBefore, uint32 valueAfter, uint48 effect) {
        // Delay拆包成三个字段
        (valueBefore, valueAfter, effect) = self.unpack();
        // 如果生效时间点小于等于timepoint，表明新值已生效，返回新值valueAfter，其余变量是0；
        // 否则表明新值还未生效，返回将三个字段原样返回
        return effect <= timepoint ? (valueAfter, 0, 0) : (valueBefore, valueAfter, effect);
    }

    /**
     * @dev Get the current value plus the pending value and effect timepoint if there is a scheduled change. If the
     * effect timepoint is 0, then the pending value should not be considered.
     */
    // 获取Delay的当前有效值
    // 注：该方法有三个返回值，返回行为同_getFullAt()一致
    function getFull(Delay self) internal view returns (uint32 valueBefore, uint32 valueAfter, uint48 effect) {
        // 去当前区块时间戳作为基准的时间戳
        return _getFullAt(self, timestamp());
    }

    /**
     * @dev Get the current value.
     */
    // 获取Delay的当前有效值
    // 注：该方法只有一个返回值，即当前有效值
    function get(Delay self) internal view returns (uint32) {
        (uint32 delay, , ) = self.getFull();
        return delay;
    }

    /**
     * @dev Update a Delay object so that it takes a new duration after a timepoint that is automatically computed to
     * enforce the old delay at the moment of the update. Returns the updated Delay object and the timestamp when the
     * new delay becomes effective.
     */
    // 安全更新
    // 该函数是这个库中最具博弈论安全设计的函数。它的核心逻辑是为了防止管理员利用“权限”瞬间改变规则来收割用户
    // 参数：
    // - newValue: 想要设置的新值；
    // - minSetback：强制的最小观察期（即使延迟增加也要等的时间）
    function withUpdate(
        Delay self,
        uint32 newValue,
        uint32 minSetback
    ) internal view returns (Delay updatedDelay, uint48 effect) {
        // 获取当前的有效值
        uint32 value = self.get();
        // 计算宽限期
        // 如果要设置的新值比旧值小（例如延迟从 7天 缩短到 1天），则宽限期至少要等于“缩短的那部分差额”，以确保护旧规则在过渡期依然有效
        // 说明：如果要设置的新值比旧值大，那宽限期就是minSetback；如果要设置的新值比旧值小（危险），取max(minSetback，新旧差额)，所以管理员将新值更改的越小，需要等待的时间就越大
        uint32 setback = uint32(Math.max(minSetback, value > newValue ? value - newValue : 0));
        // 确定新值正式生效的时间点
        effect = timestamp() + setback;
        // 构建一个新的Delay返回，其中旧值为当前的有效值，新值为要设置的新值，生效时间点为上面计算出的effect
        return (pack(value, newValue, effect), effect);
    }

    /**
     * @dev Split a delay into its components: valueBefore, valueAfter and effect (transition timepoint).
     */
    // 将Delay类型拆包成三个字段
    function unpack(Delay self) internal pure returns (uint32 valueBefore, uint32 valueAfter, uint48 effect) {
        // 拆包
        uint112 raw = Delay.unwrap(self);
        // 低32位为valueAfter
        valueAfter = uint32(raw);
        // 右移 32 位来取中间的valueBefore
        valueBefore = uint32(raw >> 32);
        // 右移 64 位来取高位的effect
        effect = uint48(raw >> 64);

        return (valueBefore, valueAfter, effect);
    }

    /**
     * @dev pack the components into a Delay object.
     */
    // 将三个字段打包成Delay类型
    function pack(uint32 valueBefore, uint32 valueAfter, uint48 effect) internal pure returns (Delay) {
        // 从高位到低位，以 valueBefore + valueBefore + valueAfter 的方式拼接成Delay
        return Delay.wrap((uint112(effect) << 64) | (uint112(valueBefore) << 32) | uint112(valueAfter));
    }
}
