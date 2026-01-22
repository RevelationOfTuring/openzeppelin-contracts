// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;

import {StorageSlot} from "./StorageSlot.sol";

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 *
 * IMPORTANT: Deprecated. This storage-based reentrancy guard will be removed and replaced
 * by the {ReentrancyGuardTransient} variant in v6.0.
 *
 * @custom:stateless
 */
// 本库提供了一种基于storage存储的重入保护锁。
// 在 OpenZeppelin v5.5.0 版本中，这个库引入了一些非常先进的底层优化，特别是 ERC-7201（命名空间存储） 的应用
// 注：现在推荐使用基于Transient Storage的ReentrancyGuardTransient，成本更低
abstract contract ReentrancyGuard {
    using StorageSlot for bytes32;

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    // 存储锁状态的slot号。这是 Openzeppelin v5.x 的重大变化，旧版通过普通的变量定义存储。它不占用合约常规的 slot 0, 1...，而是通过哈希计算将数据存在一个极深、极偏僻的位置。
    // 好处：防止存储冲突（Storage Collision）。当你使用复杂的继承体系或代理模式（Proxy）时，这种设计保证了 ReentrancyGuard 的状态绝不会被子合约的变量覆盖
    bytes32 private constant REENTRANCY_GUARD_STORAGE =
        0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    // 处于未上锁状态的标志
    // 注：
    // 1. 为什么不使用 bool 而是 uint256？
    // 答：为了节约gas。在EVM中，将一个Storage Slot从 0 修改为非 0（脏到净）非常贵（约 20,000 Gas）。而将一个非 0 值修改为另一个非 0 值（净到净）要便宜得多（约 5,000 Gas）
    // 2. EVM的gas refund机制（EIP-2200 && EIP-2929）及 为什么使用1和2，而不是0和1？
    // 答：EVM 有一个原则：如果你在一笔交易中把一个数据改了，最后又改回了原样，你就不应该支付“永久修改”的高额费用。这就是 Gas Refund。举例：
    // 如果一个槽位的值在tx开始时是a，你在中间改成了b，最后在tx结束前又改回了a，这会触发一个高达 4,800 Gas 的退还额度（这个数值会随硬分叉微调）。
    // 但是为了防止攻击者利用退款机制制造“负 Gas 交易”来攻击网络，以太坊规定：退还的 Gas 总额不能超过当前交易总消耗 Gas 的 20%（在某些版本是 50%）
    // 如果标志位使用用 0 和 1，退款额度可能非常高（因为从 0 到 1 贵，退的也多），但由于有 20% 的上限限制，用户可能根本拿不满这些退款。 而使用 1 和 2 产生的退款额度较小，反而更容易触发全额退款，最终对用户更划算。
    uint256 private constant NOT_ENTERED = 1;
    // 处于上锁状态的标志
    uint256 private constant ENTERED = 2;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        // 初始化锁状态为NOT_ENTERED
        _reentrancyGuardStorageSlot().getUint256Slot().value = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    // 最核心的修改器。被其修饰的函数可以防止重入攻击
    // 使用场景：
    // 1. 涉及 call 转账（ETH 或 代币）;
    // 2. 整个tx的执行过程中调用了其他不确定安全性的外部合约；
    modifier nonReentrant() {
        // 进入锁状态
        _nonReentrantBefore();
        _;
        // 解除锁状态
        _nonReentrantAfter();
    }

    /**
     * @dev A `view` only version of {nonReentrant}. Use to block view functions
     * from being called, preventing reading from inconsistent contract state.
     *
     * CAUTION: This is a "view" modifier and does not change the reentrancy
     * status. Use it only on view functions. For payable or non-payable functions,
     * use the standard {nonReentrant} modifier instead.
     */
    // 只读防护修饰器
    // 注：有些极其敏感的view函数不希望在写操作进行中被调用，因为此时状态可能是不一致的（比如余额已扣除但未记录）。这个修饰符允许你在 view 函数中检查是否有重入正在发生，但它本身不改变状态，所以不消耗写 Gas。
    // 即如果一个view函数，你不希望在调用一个本合约带nonReentrant的业务函数期间被调用，可以用该修饰器修饰。
    modifier nonReentrantView() {
        _nonReentrantBeforeView();
        _;
    }

    // 如果当前已处于锁状态，revert
    function _nonReentrantBeforeView() private view {
        if (_reentrancyGuardEntered()) {
            revert ReentrancyGuardReentrantCall();
        }
    }

    // 防重入锁上锁（要求当前状态为非锁状态）
    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        // 验证当前合约状态为非锁状态
        _nonReentrantBeforeView();

        // Any calls to nonReentrant after this point will fail
        // 将锁flag设置为ENTERED
        _reentrancyGuardStorageSlot().getUint256Slot().value = ENTERED;
    }

    // 防重入锁解锁
    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        // 将锁flag设置为NOT_ENTERED
        _reentrancyGuardStorageSlot().getUint256Slot().value = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    // 内部函数，判断当前被调用函数是否处于锁状态。如果是，返回true，否则返回false。
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _reentrancyGuardStorageSlot().getUint256Slot().value == ENTERED;
    }

    // 返回存储锁状态的slot号
    function _reentrancyGuardStorageSlot() internal pure virtual returns (bytes32) {
        return REENTRANCY_GUARD_STORAGE;
    }
}
