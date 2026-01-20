// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.2.0) (utils/CAIP2.sol)

pragma solidity ^0.8.24;

import {Bytes} from "./Bytes.sol";
import {Strings} from "./Strings.sol";

/**
 * @dev Helper library to format and parse CAIP-2 identifiers
 *
 * https://github.com/ChainAgnostic/CAIPs/blob/main/CAIPs/caip-2.md[CAIP-2] defines chain identifiers as:
 * chain_id:    namespace + ":" + reference
 * namespace:   [-a-z0-9]{3,8}
 * reference:   [-_a-zA-Z0-9]{1,32}
 *
 * WARNING: In some cases, multiple CAIP-2 identifiers may all be valid representation of a single chain.
 * For EVM chains, it is recommended to use `eip155:xxx` as the canonical representation (where `xxx` is
 * the EIP-155 chain id). Consider the possible ambiguity when processing CAIP-2 identifiers or when using them
 * in the context of hashes.
 */

// CAIP 代表 Chain Agnostic Improvement Proposals（链无关改进提案）。
// 每个区块链都有自己的 ID 体系（比如以太坊主网是 1，Polygon 是 137）。但在跨链场景下，单纯一个数字 1 可能会产生混淆——是以太坊体系中的chainid 1还是cosmos体系中的chainid1。
// CAIP-2 定义了一个标准字符串格式：namespace:reference。
// - namespace：生态系统（如 eip155 代表以太坊系，bip122 代表比特币系）。长度 3-8 位。
// - reference：具体的网络标识（如以太坊主网就是 eip155:1）。长度 1-32 位。
// 本库是在处理跨链互操作性（Interoperability）。它是为了让智能合约能够以标准化的方式识别“它是哪条链”。
library CAIP2 {
    using Strings for uint256;
    using Bytes for bytes;

    /// @dev Return the CAIP-2 identifier for the current (local) chain.
    // 获取当前链标识，即"eip155:[chainid]"
    function local() internal view returns (string memory) {
        return format("eip155", block.chainid.toString());
    }

    /**
     * @dev Return the CAIP-2 identifier for a given namespace and reference.
     *
     * NOTE: This function does not verify that the inputs are properly formatted.
     */
    // 构造标识符，即"[namespace]:[ref]"
    function format(string memory namespace, string memory ref) internal pure returns (string memory) {
        return string.concat(namespace, ":", ref);
    }

    /**
     * @dev Parse a CAIP-2 identifier into its components.
     *
     * NOTE: This function does not verify that the CAIP-2 input is properly formatted.
     */
    // 解析标识符
    function parse(string memory caip2) internal pure returns (string memory namespace, string memory ref) {
        // 将string变成bytes
        // 注：：在 Solidity 中，将 string memory 转换为 bytes memory 是“零开销”的。因为在EVM的内存布局中，string 和 bytes 的结构完全相同。
        bytes memory buffer = bytes(caip2);
        // 寻找caip2中冒号的index
        uint256 pos = buffer.indexOf(":");
        // 按照冒号做分割，前面部分为namespace，后面部分为ref
        return (string(buffer.slice(0, pos)), string(buffer.slice(pos + 1)));
    }
}
