// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/Panic.sol)

pragma solidity ^0.8.20;

/**
 * @dev Helper library for emitting standardized panic codes.
 *
 * ```solidity
 * contract Example {
 *      using Panic for uint256;
 *
 *      // Use any of the declared internal constants
 *      function foo() { Panic.GENERIC.panic(); }
 *
 *      // Alternatively
 *      function foo() { Panic.panic(Panic.GENERIC); }
 * }
 * ```
 *
 * Follows the list from https://github.com/ethereum/solidity/blob/v0.8.24/libsolutil/ErrorCodes.h[libsolutil].
 *
 * _Available since v5.1._
 */
// slither-disable-next-line unused-state

// Panic库旨在以一种底层且符合Solidity编译器规范的方式触发Panic错误
// 设计意图：
// 当代码进入一个逻辑上不可能的状态（例如数组越界、除以零）时，Solidity 会抛出 Panic 。这个库通过预定义的常量，让开发者能够手动触发与编译器行为一致的标准化错误代码，从而提高代码的可读性和调试效率。
// 该库是底层开发者和审计人员的利器。它不使用普通的 revert("message")，而是生成与 EVM 原生行为高度一致的错误反馈，有助于前端工具和集成开发环境（IDE）更精准地捕获异常原因。
// 当你查看以太坊浏览器（如 Etherscan）上的失败交易时：如果是普通的 require 失败，你会看到 "Reverted: Insufficient allowance" 。如果触发了 Panic.sol 里的逻辑，浏览器通常会直接解析显示 "Panic: Arithmetic overflow or underflow" 。

// 使用方法：
// 1. 直接调用：Panic.panic(Panic.DIVISION_BY_ZERO);
// 2. Using 指令：using Panic for uint256; 之后调用 Panic.GENERIC.panic();

library Panic {
    // 注：以下这些常量遵循了Solidity官方编译器的错误代码定义

    /// @dev generic / unspecified error
    // 通用或未指定的错误
    uint256 internal constant GENERIC = 0x00;
    /// @dev used by the assert() builtin
    // 由 assert() 内置函数触发的错误
    uint256 internal constant ASSERT = 0x01;
    /// @dev arithmetic underflow or overflow
    // 算术溢出（上溢或下溢）
    uint256 internal constant UNDER_OVERFLOW = 0x11;
    /// @dev division or modulo by zero
    // 除法或取模运算中除数为零
    uint256 internal constant DIVISION_BY_ZERO = 0x12;
    /// @dev enum conversion error
    // 枚举（Enum）转换错误
    uint256 internal constant ENUM_CONVERSION_ERROR = 0x21;
    /// @dev invalid encoding in storage
    // 存储中的编码格式无效
    uint256 internal constant STORAGE_ENCODING_ERROR = 0x22;
    /// @dev empty array pop
    // 对空数组执行 pop() 操作
    uint256 internal constant EMPTY_ARRAY_POP = 0x31;
    /// @dev array out of bounds access
    // 数组访问越界
    uint256 internal constant ARRAY_OUT_OF_BOUNDS = 0x32;
    /// @dev resource error (too large allocation or too large array)
    // 资源错误（如分配空间过大）
    uint256 internal constant RESOURCE_ERROR = 0x41;
    /// @dev calling invalid internal function
    // 调用了无效的内部函数指针
    uint256 internal constant INVALID_INTERNAL_FUNCTION = 0x51;

    /// @dev Reverts with a panic code. Recommended to use with
    /// the internal constants with predefined codes.
    function panic(uint256 code) internal pure {
        assembly ("memory-safe") {
            // 内存写入Panic(uint256) 的函数选择器，4个字节
            mstore(0x00, 0x4e487b71)
            // 内存写入错误代码code
            mstore(0x20, code)
            // 从 0x1c（选择器开始处）回滚数据，长度为 4 + 32 = 36 字节
            revert(0x1c, 0x24)
        }
    }
}
