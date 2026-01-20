// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (utils/LowLevelCall.sol)

pragma solidity ^0.8.20;

/**
 * @dev Library of low level call functions that implement different calling strategies to deal with the return data.
 *
 * WARNING: Using this library requires an advanced understanding of Solidity and how the EVM works. It is recommended
 * to use the {Address} library instead.
 */
// 本库是OpenZeppelin提供的一个高性能底层库。它的存在是为了压榨 Gas 效率。在标准 Solidity 中，处理外部调用的返回数据（尤其是 bytes）会涉及多次内存拷贝，非常昂贵。本库通过直接操作汇编，实现了“原地”处理数据。
// 使用本库从以下方面极值地节省gas：
// 1. 避免了 Solidity 默认将 bytes 从 returndata 缓冲区拷贝到内存，然后再从内存解码的繁琐过程；
// 2. 利用内存的前 64 字节（Scratch Space），不触发内存扩展费用（Memory Expansion Cost）；
// 3. 可以在不确定返回类型的情况下，通过 returnDataSize() 判断逻辑。
library LowLevelCall {
    /// @dev Performs a Solidity function call using a low level `call` and ignoring the return data.
    // 不携带eth的call目标合约target，但是忽略返回值
    function callNoReturn(address target, bytes memory data) internal returns (bool success) {
        return callNoReturn(target, 0, data);
    }

    /// @dev Same as {callNoReturn}, but allows to specify the value to be sent in the call.
    // 允许携带eth的call目标合约target，但是忽略返回值
    // 注：如果call的过程中出现revert，该方法也无法获取revert信息。
    function callNoReturn(address target, uint256 value, bytes memory data) internal returns (bool success) {
        assembly ("memory-safe") {
            // 这里将输出位置和长度设为0，彻底不拷贝返回数据，节省大量Gas
            // 这告诉EVM：“无论对方返回了什么（即使返回了 10KB 的数据），请直接丢弃，一个字节都不要写进我的内存。” 这避免了内存扩展费用，在大规模批量调用时能省下显著的Gas。
            success := call(gas(), target, value, add(data, 0x20), mload(data), 0x00, 0x00)
        }
    }

    /// @dev Performs a Solidity function call using a low level `call` and returns the first 64 bytes of the result
    /// in the scratch space of memory. Useful for functions that return a tuple of single-word values.
    ///
    /// WARNING: Do not assume that the results are zero if `success` is false. Memory can be already allocated
    /// and this function doesn't zero it out.
    // 不携带eth的call目标合约target，专门用于返回两个256位类型值的函数。
    // 注：如果call返回false，evm是不会向0x00~0x40的内存中写入任何数据的，那么拿到的result1和result2很有可能是之前的脏数据
    function callReturn64Bytes(
        address target,
        bytes memory data
    ) internal returns (bool success, bytes32 result1, bytes32 result2) {
        return callReturn64Bytes(target, 0, data);
    }

    /// @dev Same as {callReturnBytes32Pair}, but allows to specify the value to be sent in the call.
    // 携带eth的call目标合约target，专门用于返回两个256位类型值的函数。
    // 注：如果call返回false，evm是不会向0x00~0x40的内存中写入任何数据的，那么拿到的result1和result2很有可能是之前的脏数据
    function callReturn64Bytes(
        address target,
        uint256 value,
        bytes memory data
    ) internal returns (bool success, bytes32 result1, bytes32 result2) {
        assembly ("memory-safe") {
            // 将返回结果直接写向内存地址 0x00 (Scratch Space)，长度为0x40（64字节）
            success := call(gas(), target, value, add(data, 0x20), mload(data), 0x00, 0x40)
            // 从内存 0x00 和 0x20 分别读出这两个 32 字节的值
            result1 := mload(0x00)
            result2 := mload(0x20)
        }
    }

    /// @dev Performs a Solidity function call using a low level `staticcall` and ignoring the return data.
    // staticcall且忽略返回值
    function staticcallNoReturn(address target, bytes memory data) internal view returns (bool success) {
        assembly ("memory-safe") {
            success := staticcall(gas(), target, add(data, 0x20), mload(data), 0x00, 0x00)
        }
    }

    /// @dev Performs a Solidity function call using a low level `staticcall` and returns the first 64 bytes of the result
    /// in the scratch space of memory. Useful for functions that return a tuple of single-word values.
    ///
    /// WARNING: Do not assume that the results are zero if `success` is false. Memory can be already allocated
    /// and this function doesn't zero it out.
    // staticcall且返回两个256位类型值的函数
    // 注：如果staticcall返回false，evm是不会向0x00~0x40的内存中写入任何数据的，那么拿到的result1和result2很有可能是之前的脏数据
    function staticcallReturn64Bytes(
        address target,
        bytes memory data
    ) internal view returns (bool success, bytes32 result1, bytes32 result2) {
        assembly ("memory-safe") {
            success := staticcall(gas(), target, add(data, 0x20), mload(data), 0x00, 0x40)
            result1 := mload(0x00)
            result2 := mload(0x20)
        }
    }

    /// @dev Performs a Solidity function call using a low level `delegatecall` and ignoring the return data.
    // delegatecall但忽略返回值
    function delegatecallNoReturn(address target, bytes memory data) internal returns (bool success) {
        assembly ("memory-safe") {
            success := delegatecall(gas(), target, add(data, 0x20), mload(data), 0x00, 0x00)
        }
    }

    /// @dev Performs a Solidity function call using a low level `delegatecall` and returns the first 64 bytes of the result
    /// in the scratch space of memory. Useful for functions that return a tuple of single-word values.
    ///
    /// WARNING: Do not assume that the results are zero if `success` is false. Memory can be already allocated
    /// and this function doesn't zero it out.

    // delegatecall且返回两个256位类型值的函数
    // 注：如果delegatecall返回false，evm是不会向0x00~0x40的内存中写入任何数据的，那么拿到的result1和result2很有可能是之前的脏数据
    function delegatecallReturn64Bytes(
        address target,
        bytes memory data
    ) internal returns (bool success, bytes32 result1, bytes32 result2) {
        assembly ("memory-safe") {
            success := delegatecall(gas(), target, add(data, 0x20), mload(data), 0x00, 0x40)
            result1 := mload(0x00)
            result2 := mload(0x20)
        }
    }

    /// @dev Returns the size of the return data buffer.
    // 获取上一次调用返回的数据字节长度
    // 注：
    //  1. 无论上一次调用是 call、staticcall 还是 delegatecall，returnDataSize() 都能拿到返回数据的字节长度
    //  2. 只有当执行一次外部调用（以上三种call），返回缓冲区的数据才会被清空和更新
    //  3. call一个eoa地址，success永远为true且returndatasize为0
    // 什么时候使用该函数？
    // 在 Solidity 原生代码中，获取返回数据通常需要 (bool success, bytes memory data) = target.call(data)。
    // 此时会产生性能损耗——它强制将缓冲区的数据拷贝到内存中。如果你其实只需要知道“返回了多少字节”来决定下一步逻辑，这种拷贝就是浪费Gas
    // 该函数可以先获取返回数据长度，发现符合预期之后再将返回数据拷贝到内存中。
    function returnDataSize() internal pure returns (uint256 size) {
        assembly ("memory-safe") {
            size := returndatasize()
        }
    }

    /// @dev Returns a buffer containing the return data from the last call.
    // 将返回数据手动封装进 bytes 内存对象
    // 注：在 EVM 中，当我们进行外部调用后，返回的数据并不会直接出现在内存里，而是存放在Return Data Buffer（返回数据缓冲区） 中。
    // returndatacopy(destOffset, offset, size) 就是唯一能够将这些数据从缓冲区搬运到内存中的“搬运工”，其中：
    // destOffset: 目标内存地址（你想把数据存到内存的哪里）；
    // offset: 返回数据缓冲区中的起始偏移量（你想从返回数据的第几个字节开始拷贝）；
    // size: 要拷贝的字节长度。
    // 该opcode可以按需拷贝：你可以只拷贝你感兴趣的部分。比如，如果你知道返回的是一个 uint256，你只需要拷贝前 32 字节，而不必理会后面可能存在的其他数据
    function returnData() internal pure returns (bytes memory result) {
        assembly ("memory-safe") {
            // 获取当前的空闲内存指针
            result := mload(0x40)
            // 从返回缓冲区获取上一次外部调用的返回数据长度并写入result
            mstore(result, returndatasize())
            // 将返回缓冲区的数据拷贝到result+0x20开始的地址上
            returndatacopy(add(result, 0x20), 0x00, returndatasize())
            // 更新空闲内存指针
            mstore(0x40, add(result, add(0x20, returndatasize())))
        }
    }

    /// @dev Revert with the return data from the last call.
    // 当外部调用发生revert时，把失败的原始原因（错误字符串或 Selector）抛给用户使用
    // 即自动抓取上一个外部调用的错误原因并抛出
    function bubbleRevert() internal pure {
        assembly ("memory-safe") {
            // 找到空闲地址
            let fmp := mload(0x40)
            // 从返回缓冲区拷贝错误信息到内存
            returndatacopy(fmp, 0x00, returndatasize())
            // 原样抛出
            revert(fmp, returndatasize())
        }
    }

    // 将内存中已有的bytes作为数据进行revert抛出
    function bubbleRevert(bytes memory returndata) internal pure {
        assembly ("memory-safe") {
            // mload(returndata)是内存中bytes的实际数据长度
            // add(returndata, 0x20)是bytes中实际数据开始的地址
            revert(add(returndata, 0x20), mload(returndata))
        }
    }
}
