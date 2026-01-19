// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (utils/Multicall.sol)

pragma solidity ^0.8.20;

import {Address} from "./Address.sol";
import {Context} from "./Context.sol";

/**
 * @dev Provides a function to batch together multiple calls in a single external call.
 *
 * Consider any assumption about calldata validation performed by the sender may be violated if it's not especially
 * careful about sending transactions invoking {multicall}. For example, a relay address that filters function
 * selectors won't filter calls nested within a {multicall} operation.
 *
 * NOTE: Since 5.0.1 and 4.9.4, this contract identifies non-canonical contexts (i.e. `msg.sender` is not {Context-_msgSender}).
 * If a non-canonical context is identified, the following self `delegatecall` appends the last bytes of `msg.data`
 * to the subcall. This makes it safe to use with {ERC2771Context}. Contexts that don't affect the resolution of
 * {Context-_msgSender} are not propagated to subcalls.
 */
// Multicall是一个非常经典且强大的工具合约。它的核心功能是：允许客户端在一个单一的外部交易中，批量调用当前合约的多个函数
// 注：本合约完美兼容ERC2771，确保 _msgSender() 在批量调用中依然有效
abstract contract Multicall is Context {
    /**
     * @dev Receives and executes a batch of function calls on this contract.
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */

    //
    // 参数data：这是一个 bytes 数组，每个元素都是一段已经编码好的函数调用数据（即 abi.encodeWithSelector 生成的内容）
    // 返回值 results：一个 bytes 数组，按顺序存储每个子调用执行后的返回结果
    function multicall(bytes[] calldata data) public virtual returns (bytes[] memory results) {
        // 如果你使用了ERC2771Context（元交易/受信任的转发器），真实的发送者地址是被附加在msg.data末尾的。
        // 如果msg.sender 不是 _msgSender()，说明这次调用是通过转发器来的。从当前msg.data尾部解析出真实发送者地址，即context
        // 如果msg.sender 是_msgSender()，context为空
        bytes memory context = msg.sender == _msgSender()
            ? new bytes(0)
            : msg.data[msg.data.length - _contextSuffixLength():];

        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            // delegatecall本合约，从而能够触发合约内定义的其他 public 或 external 函数
            // 将真实发送者地址（context）拼接到calldata尾部。这确保了在批量调用中，每一个子函数通过 _msgSender() 获取到的依然是最初发起交易的用户地址
            results[i] = Address.functionDelegateCall(address(this), bytes.concat(data[i], context));
        }
        return results;
    }
}
