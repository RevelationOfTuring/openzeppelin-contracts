// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/Errors.sol)

pragma solidity ^0.8.20;

/**
 * @dev Collection of common custom errors used in multiple contracts
 *
 * IMPORTANT: Backwards compatibility is not guaranteed in future versions of the library.
 * It is recommended to avoid relying on the error API for critical functionality.
 *
 * _Available since v5.1._
 */
// Errors.sol是一个实用工具库。虽然代码看起来非常简洁，但它体现了现代 Solidity 开发（0.8.4 版本以后）中 Custom Errors 的最佳实践。
// 版本警告：注释中提到 “Backwards compatibility is not guaranteed”（不保证向后兼容）。这意味着 OpenZeppelin 可能会在未来的次要版本中修改这些错误的名称或参数。
// 建议：如果你的项目对稳定性要求极高，可以考虑将这些错误定义直接复制到你的项目基类合约中。
library Errors {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */

    // 资金不足错误
    // 用途：通常用于转账（如 Address.sendValue）或低级调用前。
    // 信息量：它不仅告诉你“钱不够”，还通过参数告诉你当前余额是多少以及缺口是多少。这对于 DApp 前端给用户提示非常友好。
    error InsufficientBalance(uint256 balance, uint256 needed);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    // 调用失败错误
    // 用途：用于底层的 call 操作。当 target.call{value: val}(data) 返回 success == false 时抛出。
    // 背景：相比于直接 revert()，使用这个特定的错误能让开发者一眼看出是外部合约调用出故障了。
    error FailedCall();

    /**
     * @dev The deployment failed.
     */
    // 部署失败错误
    // 用途：在使用 create 或 create2 指令部署新合约时，如果返回的地址为 address(0)，则抛出此错误。
    error FailedDeployment();

    /**
     * @dev A necessary precompile is missing.
     */
    // 预编译合约缺失
    // 用途：这是一个相对高级的错误。某些二层网络（L2）或侧链可能没有实现以太坊主网所有的预编译合约（例如身份验证相关的 ecrecover 或模幂运算）。如果代码依赖某个预编译地址但该地址不存在，则触发此错误。
    error MissingPrecompile(address);
}
