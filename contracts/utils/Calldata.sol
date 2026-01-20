// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.3.0) (utils/Calldata.sol)

pragma solidity ^0.8.20;

/**
 * @dev Helper library for manipulating objects in calldata.
 */
// 在 Solidity 中，变量的存储位置（Data Location）有三种：storage、memory 和 calldata。其中，Calldata 是一个只读、不可变的临时存储区域，专门用于存放函数参数。
// 相比 memory，使用 calldata 可以节省大量 Gas，因为它避免了将数据从输入流拷贝到内存的过程
// 底层结构：对于 bytes 或 string 这种动态类型，calldata 变量在底层实际上是一个“偏移量（offset）+ 长度（length）”的结构体

// 使用场景：它解决了 Solidity 强类型系统下，calldata 类型变量无法在链上自由创建的痛点。
// 1. 如果一个函数定义了 bytes calldata data 参数，但你希望在某些情况下传入一个“空值”且不产生内存分配开销，这个库就派上用场了。
//    尤其是在多级调用（Internal Calls）中，如果你需要透传 calldata：
//      function executeTask(bytes calldata extraData) internal {
//          // 逻辑代码
//      }
//
//      function handle(uint256 mode) external {
//          if (mode == 0) {
//              // 直接传递一个空的 calldata 指针，而不是 new bytes(0) 这种内存变量
//              executeTask(Calldata.emptyBytes());
//          }
//      }
// 2. 在某些复杂的架构（如 意图交易 Intent-based architecture）中，合约需要根据条件返回一段指令。
//    如果某个分支不需要执行任何指令：
//    常规做法：return "";（这会在内存中创建一个 32 字节的长度字段）。
//    极客做法：return Calldata.emptyBytes();（直接修改寄存器，几乎 0 Gas）
// 3. 在处理 multicall时，有时需要构建一个包含可选数据的数组。
//    如果数组中的某个元素是空的，使用 Calldata.emptyBytes() 可以确保你的代码逻辑在处理 calldata 时始终保持一致的类型，而不需要在 memory 和 calldata 之间来回转换（转换会触发昂贵的 mstore 指令）。
// 4. 在汇编代码块中，如果你需要定义一个 bytes calldata 类型的变量供后面使用，Solidity 编译器通常不允许你声明但不初始化它。
//      function complexLogic(bool flag) external pure {
//          bytes calldata data;
//
//          if (flag) {
//              data = msg.data[4:];
//          } else {
//              // 如果没有这个库，你无法给 data 赋一个“空”的 calldata 值
//              data = Calldata.emptyBytes();
//          }
//
//          // 之后可以统一处理 data
//          _process(data);
//      }
library Calldata {
    // slither-disable-next-line write-after-write
    // 在不消耗额外 Gas 的情况下（在汇编层面直接操作栈上的两个字——offset 和 length，完全不触碰内存），创建一个指向空字节的 calldata 引用
    function emptyBytes() internal pure returns (bytes calldata result) {
        // 由于 calldata 引用不能在 Solidity 高级语言层面直接赋值（它是只读的），我们必须动用 assembly
        assembly ("memory-safe") {
            // 将该字节数组的起始指针指向 calldata 的 0 字节位置
            result.offset := 0
            // 将长度设置为0
            result.length := 0
            // 注：此时，得到了一个合法的 bytes calldata 对象，但它不指向任何实际数据
        }
    }

    // slither-disable-next-line write-after-write
    // 在不消耗额外 Gas 的情况下（在汇编层面直接操作栈上的两个字——offset 和 length，完全不触碰内存），创建一个指向空字符串的 calldata 引用
    function emptyString() internal pure returns (string calldata result) {
        // 由于 calldata 引用不能在 Solidity 高级语言层面直接赋值（它是只读的），我们必须动用 assembly
        assembly ("memory-safe") {
            // 其原理与 emptyBytes 完全一致。
            // 在底层，string 和 bytes 的表现形式是相同的，只是语义不同
            result.offset := 0
            result.length := 0
        }
    }
}
