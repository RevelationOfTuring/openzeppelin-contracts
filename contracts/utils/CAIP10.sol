// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.2.0) (utils/CAIP10.sol)

pragma solidity ^0.8.24;

import {Bytes} from "./Bytes.sol";
import {Strings} from "./Strings.sol";
import {CAIP2} from "./CAIP2.sol";

/**
 * @dev Helper library to format and parse CAIP-10 identifiers
 *
 * https://github.com/ChainAgnostic/CAIPs/blob/main/CAIPs/caip-10.md[CAIP-10] defines account identifiers as:
 * account_id:        chain_id + ":" + account_address
 * chain_id:          [-a-z0-9]{3,8}:[-_a-zA-Z0-9]{1,32} (See {CAIP2})
 * account_address:   [-.%a-zA-Z0-9]{1,128}
 *
 * WARNING: According to [CAIP-10's canonicalization section](https://github.com/ChainAgnostic/CAIPs/blob/main/CAIPs/caip-10.md#canonicalization),
 * the implementation remains at the developer's discretion. Please note that case variations may introduce ambiguity.
 * For example, when building hashes to identify accounts or data associated to them, multiple representations of the
 * same account would derive to different hashes. For EVM chains, we recommend using checksummed addresses for the
 * "account_address" part. They can be generated onchain using {Strings-toChecksumHexString}.
 */
// 如果说 CAIP2 解决了“你在哪条链”的问题，那么 CAIP10 解决的就是“你是谁，且你在哪条链”的问题。在全链（Omnichain）和意图导向（Intent-centric）的架构中，这是定义一个“全球账户”的终极标准。
// CAIP-10 定义了如何唯一地标识一个跨链账户。
// 格式：chain_id + : + account_address
// 完整结构：namespace + : + reference + : + account_address。示例：以太坊主网上的某个地址标识为 eip155:1:0x1234...abcd
// 注：CAIP10 建立在 CAIP2 之上。它直接调用 CAIP2.local() 来获取当前的链环境
library CAIP10 {
    using Strings for address;
    using Bytes for bytes;

    /// @dev Return the CAIP-10 identifier for an account on the current (local) chain.
    // 获取当前链的账户标识，即"[当前链的caip2]:[account校验和地址]""
    function local(address account) internal view returns (string memory) {
        return format(CAIP2.local(), account.toChecksumHexString());
    }

    /**
     * @dev Return the CAIP-10 identifier for a given caip2 chain and account.
     *
     * NOTE: This function does not verify that the inputs are properly formatted.
     */
    // 拼接标识符，即"[caip2]:[account]"
    function format(string memory caip2, string memory account) internal pure returns (string memory) {
        return string.concat(caip2, ":", account);
    }

    /**
     * @dev Parse a CAIP-10 identifier into its components.
     *
     * NOTE: This function does not verify that the CAIP-10 input is properly formatted. The `caip2` return can be
     * parsed using the {CAIP2} library.
     */
    // 解析标识符
    function parse(string memory caip10) internal pure returns (string memory caip2, string memory account) {
        // 将string变成bytes
        // 注：：在 Solidity 中，将 string memory 转换为 bytes memory 是“零开销”的。因为在EVM的内存布局中，string 和 bytes 的结构完全相同。
        bytes memory buffer = bytes(caip10);
        // 获取caip10中最后一个冒号的index
        uint256 pos = buffer.lastIndexOf(":");
        // 按照最后一个冒号做分割，前面部分为caip2字符串，后面部分为account校验和地址字符串
        return (string(buffer.slice(0, pos)), string(buffer.slice(pos + 1)));
    }
}
