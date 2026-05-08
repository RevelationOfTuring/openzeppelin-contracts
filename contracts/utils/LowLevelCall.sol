// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.6.0) (utils/LowLevelCall.sol)

pragma solidity ^0.8.20;

/*
 * 功能总结：
 * 提供一组底层调用函数，按"是否需要返回数据"和"调用类型"组合出不同策略，
 * 让上层合约可以根据业务需要选择最省 gas 的调用方式。
 *
 * 核心功能：
 * - callNoReturn：用 call 调用目标合约，忽略返回数据（最省 gas）
 * - callReturn64Bytes：用 call 调用目标合约，只读取前 64 字节返回值（两个 word）
 * - staticcallNoReturn：用 staticcall 调用目标合约，忽略返回数据（只读调用）
 * - staticcallReturn64Bytes：用 staticcall 调用目标合约，只读取前 64 字节返回值
 * - delegatecallNoReturn：用 delegatecall 调用目标合约，忽略返回数据
 * - delegatecallReturn64Bytes：用 delegatecall 调用目标合约，只读取前 64 字节返回值
 * - returnDataSize：获取上一次调用的返回数据长度
 * - returnData：将上一次调用的返回数据拷贝到 memory 并返回
 * - bubbleRevert：将上一次调用的 revert 数据原样向上抛出
 *
 * 三种调用类型的区别：
 * 1. call：标准外部调用，msg.sender = 当前合约，执行上下文 = 目标合约
 *    - 可以发送 ETH（value 参数）
 *    - 最常用的外部调用方式
 * 2. staticcall：只读调用，不能修改状态（写状态会 revert）
 *    - 不能发送 ETH
 *    - 用于查询操作，编译器对 view/pure 函数自动用 staticcall
 * 3. delegatecall：委托调用，msg.sender = 原始调用者，执行上下文 = 当前合约
 *    - 不能发送 ETH（DELEGATECALL 操作码在 EVM 规范中没有 value 参数）
 *    - 目标合约的代码在当前合约的存储上执行（代理模式的核心）
 *
 * 两种返回数据策略的区别：
 * 1. NoReturn：returnSize = 0，完全不读取返回数据
 *    - 省去 returndatacopy 的 gas 开销
 *    - 适用于：只关心成功/失败，不需要返回值的场景（如 ERC20 transfer 兼容无返回值的代币）
 * 2. Return64Bytes：returnSize = 64，只读取前两个 word 到 scratch space
 *    - 不分配新 memory（写入 0x00-0x3f 的 scratch space），比 abi.decode 更省 gas
 *    - 适用于：返回值是 1-2 个 word 的场景（如 balanceOf 返回 uint256，或返回 (bool, uint256)）
 *
 * EVM 内存布局背景知识（理解本库必需）：
 * - 0x00-0x3f（64 bytes）：scratch space（临时空间），任何 inline assembly 都可自由使用，
 *   Solidity 不保证其内容，适合放临时返回值
 * - 0x40-0x5f（32 bytes）：free memory pointer（空闲内存指针），指向下一个可用内存位置
 * - 0x60-0x7f（32 bytes）：zero slot（零值槽），永远为 0，用作动态数组的初始值
 * - 0x80+：实际可用 memory 区域，由 free memory pointer 管理
 *
 * 典型使用场景：
 * 1. 代理合约（Proxy）：用 delegatecallNoReturn + bubbleRevert 转发所有调用
 * 2. 多重调用（Multicall）：批量执行调用，按需读取返回值
 * 3. 安全的 ERC20 交互：callNoReturn 兼容不返回 bool 的非标准代币（如 USDT）
 * 4. 预言机查询：staticcallReturn64Bytes 高效读取价格数据
 */
library LowLevelCall {
    /*//////////////////////////////////////////////////////////////
                            CALL 系列
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice 用 call 调用目标合约，忽略返回数据（value = 0 的便捷重载）
     * @param target 目标合约地址
     * @param data ABI 编码的调用数据（函数选择器 + 参数）
     * @return success 调用是否成功（目标合约没有 revert）
     */
    function callNoReturn(address target, bytes memory data) internal returns (bool success) {
        return callNoReturn(target, 0, data);
    }

    /**
     * @notice 用 call 调用目标合约，忽略返回数据，可附带 ETH
     * @param target 目标合约地址
     * @param value 随调用发送的 ETH 数量（单位 wei）
     * @param data ABI 编码的调用数据
     * @return success 调用是否成功
     */
    function callNoReturn(address target, uint256 value, bytes memory data) internal returns (bool success) {
        assembly ("memory-safe") {
            // call(gas, addr, value, argsOffset, argsLength, retOffset, retSize)
            // gas(): 转发当前所有剩余 gas
            // target: 目标地址
            // value: 发送的 ETH
            // add(data, 0x20): 跳过 bytes 变量前 32 字节的长度前缀，指向实际数据
            // mload(data): 读取 bytes 的长度（前 32 字节存的就是 length）
            // 0x00: returndata 写入位置（scratch space 起始）
            // 0x00: returndata 读取长度为 0（完全忽略返回数据）
            success := call(gas(), target, value, add(data, 0x20), mload(data), 0x00, 0x00)
        }
    }

    /**
     * @notice 用 call 调用目标合约，读取前 64 字节返回值到 scratch space（value = 0 的便捷重载）
     * @dev 适用于返回值为两个 word 的函数，如返回 (uint256, uint256) 或 (bool, address)
     *      WARNING: 如果 success == false，result1 和 result2 的值不可信！
     *      因为 scratch space 可能已有之前操作遗留的数据，本函数不会清零。
     * @param target 目标合约地址
     * @param data ABI 编码的调用数据
     * @return success 调用是否成功
     * @return result1 返回数据的前 32 字节
     * @return result2 返回数据的第 33-64 字节
     */
    function callReturn64Bytes(
        address target,
        bytes memory data
    ) internal returns (bool success, bytes32 result1, bytes32 result2) {
        return callReturn64Bytes(target, 0, data);
    }

    /**
     * @notice 用 call 调用目标合约，读取前 64 字节返回值到 scratch space，可附带 ETH
     * @dev WARNING: success == false 时返回值不可信（scratch space 不清零）
     *      当 success == false 时，memory[0x00..0x3f] 的写入情况：
     *      1. 目标合约执行 REVERT（带数据）: revert 错误数据的前 64 字节会被写入 scratch space
     *      2. 目标合约执行 REVERT（无数据）: returndatasize = 0，不写入任何内容，旧数据保留
     *      3. 异常中止（out-of-gas、invalid opcode 等）: returndatasize = 0，不写入，旧数据保留
     *      因此 success == false 时 result1/result2 不可信（可能是 revert 数据或残留旧值）
     * @param target 目标合约地址
     * @param value 随调用发送的 ETH 数量
     * @param data ABI 编码的调用数据
     * @return success 调用是否成功
     * @return result1 返回数据的前 32 字节
     * @return result2 返回数据的第 33-64 字节
     */
    function callReturn64Bytes(
        address target,
        uint256 value,
        bytes memory data
    ) internal returns (bool success, bytes32 result1, bytes32 result2) {
        assembly ("memory-safe") {
            // retOffset = 0x00, retSize = 0x40（64 字节）
            // EVM 会将返回数据的前 64 字节写入 memory[0x00..0x3f]（scratch space）
            // 这比分配新 memory + returndatacopy 更省 gas
            success := call(gas(), target, value, add(data, 0x20), mload(data), 0x00, 0x40)
            // 从 scratch space 读取两个 word
            // mload(0x00) = memory[0x00..0x1f]
            result1 := mload(0x00)
            // mload(0x20) = memory[0x20..0x3f]
            result2 := mload(0x20)
        }
    }

    /*//////////////////////////////////////////////////////////////
                         STATICCALL 系列
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice 用 staticcall 调用目标合约，忽略返回数据（只读调用）
     * @param target 目标合约地址
     * @param data ABI 编码的调用数据
     * @return success 调用是否成功
     */
    function staticcallNoReturn(address target, bytes memory data) internal view returns (bool success) {
        assembly ("memory-safe") {
            // staticcall(gas, addr, argsOffset, argsLength, retOffset, retSize)
            // 与 call 类似，但没有 value 参数，且保证不修改状态
            // retOffset=0x00: 返回数据写入内存起始地址为 0（scratch space）
            // retSize=0x00: 不读取任何返回数据，因此实际不会向内存写入任何内容
            success := staticcall(gas(), target, add(data, 0x20), mload(data), 0x00, 0x00)
        }
    }

    /**
     * @notice 用 staticcall 调用目标合约，读取前 64 字节返回值到 scratch space
     * @dev WARNING: success == false 时返回值不可信（scratch space 不清零）
     * @param target 目标合约地址
     * @param data ABI 编码的调用数据
     * @return success 调用是否成功
     * @return result1 返回数据的前 32 字节
     * @return result2 返回数据的第 33-64 字节
     */
    function staticcallReturn64Bytes(
        address target,
        bytes memory data
    ) internal view returns (bool success, bytes32 result1, bytes32 result2) {
        assembly ("memory-safe") {
            // 只读调用目标合约，将返回数据的前 64 字节写入 scratch space（memory[0x00..0x3f]）
            success := staticcall(gas(), target, add(data, 0x20), mload(data), 0x00, 0x40)
            // 从 scratch space 读取两个 word
            // mload(0x00) = memory[0x00..0x1f]
            result1 := mload(0x00)
            // mload(0x20) = memory[0x20..0x3f]
            result2 := mload(0x20)
        }
    }

    /*//////////////////////////////////////////////////////////////
                        DELEGATECALL 系列
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice 用 delegatecall 调用目标合约，忽略返回数据
     * @dev delegatecall 的特殊性：
     *      - msg.sender 和 msg.value 保持不变（是原始调用者，不是当前合约）
     *      - 目标合约的代码在当前合约的存储（storage）和余额（balance）上执行
     *      - 这是代理模式（Proxy Pattern）的核心机制
     *      - 没有 value 参数（delegatecall 不能发送 ETH，它继承原始调用的 msg.value）
     * @param target 目标合约地址（通常是逻辑合约/实现合约）
     * @param data ABI 编码的调用数据
     * @return success 调用是否成功
     */
    function delegatecallNoReturn(address target, bytes memory data) internal returns (bool success) {
        assembly ("memory-safe") {
            // delegatecall(gas, addr, argsOffset, argsLength, retOffset, retSize)
            // 与 call 类似，但没有 value 参数
            // retOffset=0x00: 返回数据写入内存起始地址为 0（scratch space）
            // retSize=0x00: 不读取任何返回数据，因此实际不会向内存写入任何内容
            success := delegatecall(gas(), target, add(data, 0x20), mload(data), 0x00, 0x00)
        }
    }

    /**
     * @notice 用 delegatecall 调用目标合约，读取前 64 字节返回值到 scratch space
     * @dev WARNING: success == false 时返回值不可信（scratch space 不清零）
     * @param target 目标合约地址
     * @param data ABI 编码的调用数据
     * @return success 调用是否成功
     * @return result1 返回数据的前 32 字节
     * @return result2 返回数据的第 33-64 字节
     */
    function delegatecallReturn64Bytes(
        address target,
        bytes memory data
    ) internal returns (bool success, bytes32 result1, bytes32 result2) {
        assembly ("memory-safe") {
            // 委托调用目标合约，将返回数据的前 64 字节写入 scratch space（memory[0x00..0x3f]）
            success := delegatecall(gas(), target, add(data, 0x20), mload(data), 0x00, 0x40)
            // 从 scratch space 读取两个 word
            // mload(0x00) = memory[0x00..0x1f]
            result1 := mload(0x00)
            // mload(0x20) = memory[0x20..0x3f]
            result2 := mload(0x20)
        }
    }

    /*//////////////////////////////////////////////////////////////
                       RETURNDATA 辅助函数
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice 获取上一次外部调用的返回数据长度（字节数）
     * @dev returndatasize 是 EVM 操作码，返回最近一次 call/staticcall/delegatecall 的返回数据大小。
     *      如果没有外部调用或在合约创建阶段，returndatasize = 0。
     *      注：returndatacopy 不会改变 returndatasize，它只是把缓冲区内容拷贝到 memory。
     *      只有发起新的外部调用（call/staticcall/delegatecall/create）才会重置缓冲区并更新该值。
     * @return size 返回数据的字节长度
     */
    function returnDataSize() internal pure returns (uint256 size) {
        assembly ("memory-safe") {
            size := returndatasize()
        }
    }

    /**
     * @notice 将上一次外部调用的完整返回数据拷贝到 memory 并返回 bytes
     * @dev 手动管理 memory 分配：
     *      1. 读取 free memory pointer 确定写入位置
     *      2. 写入 bytes 长度前缀
     *      3. 用 returndatacopy 拷贝实际数据
     *      4. 更新 free memory pointer
     *      这比 Solidity 自动处理更高效（省去了 ABI 解码的额外开销）
     * @return result 完整的返回数据（ABI 编码的 bytes）
     */
    function returnData() internal pure returns (bytes memory result) {
        assembly ("memory-safe") {
            // 读取 free memory pointer: 下一个可用的 memory 位置
            result := mload(0x40)
            // 在 result 位置写入 bytes 长度前缀
            // bytes 在 memory 中的布局: [32 bytes 长度][实际数据...]
            mstore(result, returndatasize())
            // 将返回数据拷贝到 result + 32 的位置（跳过长度前缀）
            // returndatacopy(destOffset, srcOffset, length)
            // destOffset = add(result, 0x20): 写到长度前缀之后
            // srcOffset = 0x00: 从返回数据缓冲区的开头开始拷贝
            // length = returndatasize(): 拷贝全部返回数据
            returndatacopy(add(result, 0x20), 0x00, returndatasize())
            // 更新 free memory pointer: result + 32(长度前缀) + returndatasize(数据)
            // 这样后续的 memory 分配不会覆盖刚写入的数据
            mstore(0x40, add(result, add(0x20, returndatasize())))
        }
    }

    /**
     * @notice 将上一次外部调用的 revert 数据原样向上抛出（冒泡 revert）
     * @dev 典型用途：代理合约转发调用失败时，把目标合约的错误信息原样返回给调用者
     *      流程：
     *      1. 从 free memory pointer 获取写入位置（不修改 fmp，因为马上就要 revert 了）
     *      2. returndatacopy 将 revert 数据拷贝到该位置
     *      3. revert(offset, size) 用该数据执行 revert
     *      为什么不用修改 free memory pointer？因为 revert 后当前执行帧直接终止，memory 不会再被使用
     */
    function bubbleRevert() internal pure {
        assembly ("memory-safe") {
            // 读取 free memory pointer 作为临时写入位置
            let fmp := mload(0x40)
            // 将上一次调用的 revert 数据拷贝到 fmp 位置
            returndatacopy(fmp, 0x00, returndatasize())
            // 用拷贝的数据执行 revert，将错误信息原样传递给上层调用者
            revert(fmp, returndatasize())
        }
    }

    /**
     * @notice 用给定的 bytes 数据执行 revert（不依赖 returndatasize）
     * @dev 与上面的无参版本不同：这里 revert 的数据来源是传入的 returndata 参数，
     *      而不是 EVM 的 returndata buffer。
     *      适用于：已经将返回数据存储到变量中（如通过 returnData() 获取后），稍后再 revert
     * @param returndata 要作为 revert 数据抛出的 bytes
     */
    function bubbleRevert(bytes memory returndata) internal pure {
        assembly ("memory-safe") {
            // add(returndata, 0x20): 跳过 bytes 的 32 字节长度前缀，指向实际数据
            // mload(returndata): 读取 bytes 的长度
            // revert(offset, size): 用该数据执行 revert
            revert(add(returndata, 0x20), mload(returndata))
        }
    }
}
