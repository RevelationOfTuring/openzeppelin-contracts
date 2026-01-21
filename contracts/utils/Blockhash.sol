// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (utils/Blockhash.sol)

pragma solidity ^0.8.20;

/**
 * @dev Library for accessing historical block hashes beyond the standard 256 block limit.
 * Uses EIP-2935's history storage contract which maintains a ring buffer of the last
 * 8191 block hashes in state.
 *
 * For blocks within the last 256 blocks, it uses the native `BLOCKHASH` opcode.
 * For blocks between 257 and 8191 blocks ago, it queries the EIP-2935 history storage.
 * For blocks older than 8191 or future blocks, it returns zero, matching the `BLOCKHASH` behavior.
 *
 * NOTE: After EIP-2935 activation, it takes 8191 blocks to completely fill the history.
 * Before that, only block hashes since the fork block will be available.
 */
// Blockhash.sol是OpenZeppelin 5.5.0 版本中一个非常有分量的更新。它标志着 Solidity 开发进入了 EIP-2935 时代。
// 在以太坊中，原生指令 blockhash(n) 有一个极大的限制：只能获取最近256个区块的哈希值（大约 50 分钟的数据）。一旦超过这个范围，它就会静默返回0。
// EIP-2935 解决了这个问题。它在以太坊主网上引入了一个“系统级合约”（地址为 0x0000...2935），它像一个环形缓冲区（Ring Buffer），自动存储最近8191个区块的哈希。
library Blockhash {
    /// @dev Address of the EIP-2935 history storage contract.
    // 这是 EIP-2935规定的固定地址。注意这个地址的后四位2935，这是一种常见的以太坊系统合约命名规范。
    // 注：0x...2935 对应的正是 EIP-2935。在以太坊中，这种做法被称为 “Vanity System Addresses”（虚荣系统地址）。
    // 他们是通过网络硬分叉注入的，而非发交易部署到链上，但是是在在硬分叉点模拟一笔交易使用create2来部署到链上，实际并没有该交易（所以区块链浏览器上查不到这类合约，因为根本没有部署的交易）。
    // 类似例子：EIP-4788 (信标链根哈希): 地址是 0x000F3df6D7328073e1F139019b70273760454788
    // 以后看到以很多0开头并且以EIP数字结尾的地址，大概率是这种系统合约地址。
    // 地址前缀有很多0在某些场景下可以节省 Gas（因为零字节在 CallData 中更便宜：calldata中一个0字节消耗4gas，非零消耗16gas）
    address internal constant HISTORY_STORAGE_ADDRESS = 0x0000F90827F1C53a10cb7A02335B175320002935;

    /**
     * @dev Retrieves the block hash for any historical block within the supported range.
     *
     * NOTE: The function gracefully handles future blocks and blocks beyond the history window
     * by returning zero, consistent with the EVM's native `BLOCKHASH` behavior.
     */
    // 查询高度为blockNumber的block hash
    // 注：如果查询未来块或者距离当前块高度差>8191的blockhash，会得到0（同原生blockhash()行为一致）。
    function blockHash(uint256 blockNumber) internal view returns (bytes32) {
        // 当前区块高度
        uint256 current = block.number;
        uint256 distance;
        // 计算blockNumber与当前区块高度的差值
        // 注：这里使用unchecked是为了节省 Gas。如果 blockNumber 是未来块，减法会溢出变成一个巨大的数。那么在后面执行_historyStorageCall()会返回0，符合原生blockhash()的行为
        unchecked {
            // Can only wrap around to `current + 1` given `block.number - (2**256 - 1) = block.number + 1`
            distance = current - blockNumber;
        }

        // 如果差值小于257，则直接执行原生的blockhash()进行查询。如果大于，则查询EIP-2935系统级合约
        return distance < 257 ? blockhash(blockNumber) : _historyStorageCall(blockNumber);
    }

    /// @dev Internal function to query the EIP-2935 history storage contract.
    // 查询EIP-2935系统级合约查询高度为blockNumber的blockhash
    function _historyStorageCall(uint256 blockNumber) private view returns (bytes32 hash) {
        assembly ("memory-safe") {
            // Store the blockNumber in scratch space
            // 将blockNumber存入scratch space的第一个字
            mstore(0x00, blockNumber)
            // scratch space的第二个字做清0操作，目的是：一旦下面的staticcall失败了（即返回false），它并不会向内存的0x20处写入任何数据。
            // 清零后保证在以上情况发生后， mload(0x20)读出来的值是0
            mstore(0x20, 0)

            // call history storage address
            // staticcallEIP-2935系统级合约，参数是blockNumber，返回值存入内存0x20，存入长度为一个字
            // 注：staticcall、call 或 delegatecall 执行完毕后，会在栈顶压入一个布尔值（success）。
            // 如果你不关心调用是否成功，或者已经通过其他方式（如预初始化内存）保证了安全性，你就必须使用 pop，这些值会堆积在栈里，最终导致 Stack Too Deep（栈溢出） 错误。
            // 这里就是直接将staticcall()的返回值直接弹出栈（丢弃掉）
            pop(staticcall(gas(), HISTORY_STORAGE_ADDRESS, 0x00, 0x20, 0x20, 0x20))

            // load result
            // 将内存0x20地址下的值载入到栈中
            hash := mload(0x20)
        }
    }
}
