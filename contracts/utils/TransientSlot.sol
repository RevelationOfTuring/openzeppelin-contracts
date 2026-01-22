// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (utils/TransientSlot.sol)
// This file was procedurally generated from scripts/generate/templates/TransientSlot.js.

pragma solidity ^0.8.24;

/**
 * @dev Library for reading and writing value-types to specific transient storage slots.
 *
 * Transient slots are often used to store temporary values that are removed after the current transaction.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 *  * Example reading and writing values using transient storage:
 * ```solidity
 * contract Lock {
 *     using TransientSlot for *;
 *
 *     // Define the slot. Alternatively, use the SlotDerivation library to derive the slot.
 *     bytes32 internal constant _LOCK_SLOT = 0xf4678858b2b588224636b8522b729e7722d32fc491da849ed75b3fdf3c84f542;
 *
 *     modifier locked() {
 *         require(!_LOCK_SLOT.asBoolean().tload());
 *
 *         _LOCK_SLOT.asBoolean().tstore(true);
 *         _;
 *         _LOCK_SLOT.asBoolean().tstore(false);
 *     }
 * }
 * ```
 *
 * TIP: Consider using this library along with {SlotDerivation}.
 */

// 核心背景：在传统的以太坊开发中，数据要么存放在 Storage（昂贵，永久保存），要么在 Memory（便宜，函数调用结束即销毁）。 瞬时存储 (TSTORE/TLOAD) 开辟了第三条路：
// - 寿命：贯穿整笔交易（Transaction）。交易开始时清零，交易结束时自动销毁。
// -成本：单次操作仅需 100 Gas，远低于普通 SSTORE（至少 2100 Gas）。
// - 用途：最经典的用途是 重入锁（Reentrancy Lock）。
// TransientSlot库是针对以太坊 Cancun (坎昆) 升级推出的工具库。它封装了 EIP-1153 引入的新特性：瞬时存储（Transient Storage）。
// 注：必须使用 0.8.24+ 版本。这是第一个正式支持 tstore 和 tload 操作码的编译器版本。
library TransientSlot {
    /**
     * @dev UDVT that represents a slot holding an address.
     */
    // AddressSlot是用户定义值类型，底层就是一个bytes32。
    // 为什么要不直接用bytes32?
    // 答：通过这种方式，可以确保 AddressSlot 只能用来存放address类型变量（不能用来存uint256等其他类型），防止在底层汇编操作时传错数据类型
    type AddressSlot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a AddressSlot.
     */
    // 将bytes32类型的slot包装成AddressSlot
    function asAddress(bytes32 slot) internal pure returns (AddressSlot) {
        return AddressSlot.wrap(slot);
    }

    /**
     * @dev UDVT that represents a slot holding a bool.
     */
    // 同AddressSlot，只不过 BooleanSlot 只能用来存放bool类型变量
    type BooleanSlot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a BooleanSlot.
     */
    // 将bytes32类型的slot包装成BooleanSlot
    function asBoolean(bytes32 slot) internal pure returns (BooleanSlot) {
        return BooleanSlot.wrap(slot);
    }

    /**
     * @dev UDVT that represents a slot holding a bytes32.
     */
    // 同AddressSlot，只不过 Bytes32Slot 只能用来存放bytes32类型变量
    type Bytes32Slot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a Bytes32Slot.
     */
    // 将bytes32类型的slot包装成Bytes32Slot
    function asBytes32(bytes32 slot) internal pure returns (Bytes32Slot) {
        return Bytes32Slot.wrap(slot);
    }

    /**
     * @dev UDVT that represents a slot holding a uint256.
     */
    // 同AddressSlot，只不过 Uint256Slot 只能用来存放uint256类型变量
    type Uint256Slot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a Uint256Slot.
     */
    // 将bytes32类型的slot包装成Uint256Slot
    function asUint256(bytes32 slot) internal pure returns (Uint256Slot) {
        return Uint256Slot.wrap(slot);
    }

    /**
     * @dev UDVT that represents a slot holding a int256.
     */
    // 同AddressSlot，只不过 Int256Slot 只能用来存放int256类型变量
    type Int256Slot is bytes32;

    /**
     * @dev Cast an arbitrary slot to a Int256Slot.
     */
    // 将bytes32类型的slot包装成Int256Slot
    function asInt256(bytes32 slot) internal pure returns (Int256Slot) {
        return Int256Slot.wrap(slot);
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    // 针对AddressSlot类型的读函数
    function tload(AddressSlot slot) internal view returns (address value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    // 针对AddressSlot类型的写函数
    function tstore(AddressSlot slot, address value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    // 针对BooleanSlot类型的读函数
    function tload(BooleanSlot slot) internal view returns (bool value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    // 针对BooleanSlot类型的写函数
    function tstore(BooleanSlot slot, bool value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    // 针对Bytes32Slot类型的读函数
    function tload(Bytes32Slot slot) internal view returns (bytes32 value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    // 针对Bytes32Slot类型的写函数
    function tstore(Bytes32Slot slot, bytes32 value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    // 针对Uint256Slot类型的读函数
    function tload(Uint256Slot slot) internal view returns (uint256 value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    // 针对Uint256Slot类型的写函数
    function tstore(Uint256Slot slot, uint256 value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }

    /**
     * @dev Load the value held at location `slot` in transient storage.
     */
    // 针对Int256Slot类型的读函数
    function tload(Int256Slot slot) internal view returns (int256 value) {
        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /**
     * @dev Store `value` at location `slot` in transient storage.
     */
    // 针对Int256Slot类型的写函数
    function tstore(Int256Slot slot, int256 value) internal {
        assembly ("memory-safe") {
            tstore(slot, value)
        }
    }
}
