// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (utils/Create2.sol)

pragma solidity ^0.8.20;

import {Errors} from "./Errors.sol";
import {LowLevelCall} from "./LowLevelCall.sol";

/**
 * @dev Helper to make usage of the `CREATE2` EVM opcode easier and safer.
 * `CREATE2` can be used to compute in advance the address where a smart
 * contract will be deployed, which allows for interesting new mechanisms known
 * as 'counterfactual interactions'.
 *
 * See the https://eips.ethereum.org/EIPS/eip-1014#motivation[EIP] for more
 * information.
 */

// Create2库是对 EVM 操作码 CREATE2 的高级封装，旨在在合约部署前就确定其合约地址——变得简单且安全
// CREATE2的地址计算公式：address = keccak256(0xff·deployer·salt·keccak256(bytecode))
library Create2 {
    /**
     * @dev There's no code to deploy.
     */
    error Create2EmptyBytecode();

    /**
     * @dev Deploys a contract using `CREATE2`. The address where the contract
     * will be deployed can be known in advance via {computeAddress}.
     *
     * The bytecode for a contract can be obtained from Solidity with
     * `type(contractName).creationCode`.
     *
     * Requirements:
     *
     * - `bytecode` must not be empty.
     * - `salt` must have not been used for `bytecode` already.
     * - the factory must have a balance of at least `amount`.
     * - if `amount` is non-zero, `bytecode` must have a `payable` constructor.
     */
    // 核心函数，使用CREATE2部署合约
    // 注：往往工厂合约会使用该库
    function deploy(uint256 amount, bytes32 salt, bytes memory bytecode) internal returns (address addr) {
        // 检查：如果部署时要给新合约转eth(amount)，先确认当前工厂合约钱够不够
        if (address(this).balance < amount) {
            revert Errors.InsufficientBalance(address(this).balance, amount);
        }
        // 检查：字节码不能为空
        if (bytecode.length == 0) {
            revert Create2EmptyBytecode();
        }
        // 核心汇编块
        assembly ("memory-safe") {
            // create2(value, offset, size, salt)
            // 向部署的合约转入eth数量为amount
            // 部署字节码在内存中的起始地址bytecode+32（跳过字节长度）
            // 部署字节码长度为mload(bytecode)
            // 使用的salt为传入的salt值
            addr := create2(amount, add(bytecode, 0x20), mload(bytecode), salt)
        }

        // 部署后检查
        if (addr == address(0)) {
            // 如果得到的部署合约地址为0，说明部署失败（可能是salt冲突或constructor函数发生revert）
            if (LowLevelCall.returnDataSize() == 0) {
                // 如果返回值缓冲区无内容，说明是salt值冲突导致部署失败
                revert Errors.FailedDeployment();
            } else {
                // 如果返回值缓冲区有东西，说明是部署时候的constructor函数中发生revert。缓冲区内部就是其revert的信息，原封不动地将revert抛出。
                LowLevelCall.bubbleRevert();
            }
        }
    }

    /**
     * @dev Returns the address where a contract will be stored if deployed via {deploy}. Any change in the
     * `bytecodeHash` or `salt` will result in a new destination address.
     */
    // 计算本合约通过CREATE2部署出的合约地址
    function computeAddress(bytes32 salt, bytes32 bytecodeHash) internal view returns (address) {
        return computeAddress(salt, bytecodeHash, address(this));
    }

    /**
     * @dev Returns the address where a contract will be stored if deployed via {deploy} from a contract located at
     * `deployer`. If `deployer` is this contract's address, returns the same value as {computeAddress}.
     */
    // 计算deployer地址通过CREATE2部署出的合约地址
    // 注：在以太坊历史上，EOA 是无法直接调用 CREATE2 的（EOA 只能通过普通交易触发 CREATE）
    function computeAddress(bytes32 salt, bytes32 bytecodeHash, address deployer) internal pure returns (address addr) {
        assembly ("memory-safe") {
            // 获取空闲内存指针
            let ptr := mload(0x40) // Get free memory pointer

            // |                     | ↓ ptr ...  ↓ ptr + 0x0B (start) ...  ↓ ptr + 0x20 ...  ↓ ptr + 0x40 ...   |
            // |---------------------|---------------------------------------------------------------------------|
            // | bytecodeHash        |                                                        CCCCCCCCCCCCC...CC |
            // | salt                |                                      BBBBBBBBBBBBB...BB                   |
            // | deployer            | 000000...0000AAAAAAAAAAAAAAAAAAA...AA                                     |
            // | 0xFF                |            FF                                                             |
            // |---------------------|---------------------------------------------------------------------------|
            // | memory              | 000000...00FFAAAAAAAAAAAAAAAAAAA...AABBBBBBBBBBBBB...BBCCCCCCCCCCCCC...CC |
            // | keccak(start, 0x55) |            ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ |
            // ptr后第二个字的内存中，存入bytecode的hash
            mstore(add(ptr, 0x40), bytecodeHash)
            // ptr后第一个字的内存中，存入salt
            mstore(add(ptr, 0x20), salt)
            // ptr的内存中，存入deployer地址（由于address是160位，所以ptr内存中高96位是0，即前96/8=12个字节）
            mstore(ptr, deployer) // Right-aligned with 12 preceding garbage bytes
            // 为了deployer前面追加0xff，获取ptr+11个字节的地址
            let start := add(ptr, 0x0b) // The hashed data starts at the final garbage byte which we will set to 0xff
            // 向start位置写入一字节，内容为0xff
            mstore8(start, 0xff)
            // 内存中，[start: start+85)的内容求hash
            // 即对以下内容求hash：[0xff (1字节)] + [deployer (20字节)] + [salt (32字节)] + [bytecodeHash (32字节)]
            // 最后保留hash的低160位作为合约地址
            addr := and(keccak256(start, 0x55), 0xffffffffffffffffffffffffffffffffffffffff)
        }
    }
}
