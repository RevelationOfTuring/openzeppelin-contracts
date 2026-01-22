// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (utils/ReentrancyGuardTransient.sol)

pragma solidity ^0.8.24;

import {TransientSlot} from "./TransientSlot.sol";

/**
 * @dev Variant of {ReentrancyGuard} that uses transient storage.
 *
 * NOTE: This variant only works on networks where EIP-1153 is available.
 *
 * _Available since v5.1._
 *
 * @custom:stateless
 */

// 该库提供了基于 EIP-1153 瞬时存储（非storage存储）的防重入锁，gas消耗更低
// 注：
// - 0.8.24+ 才能支持 EIP-1153 操作码 TSTORE 和 TLOAD;
// - 代码顶部的 @custom:stateless 标签意味着这个合约本身不改变区块链的“永久状态”，它只是一把“临时的门栓”;
// - 传统版本ReentrancyGuard使用 1 和 2 来避免 0 变 1 的高额开销。但在瞬时存储中，false 变 true 本身就非常便宜，所以代码回归到了最直观的布尔值逻辑；
// - 如果合约是部署在不支持 EIP-1153 的链（比如一些较旧的侧链）上，这段代码会直接报错（无效操作码）。
abstract contract ReentrancyGuardTransient {
    using TransientSlot for *;

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ReentrancyGuard")) - 1)) & ~bytes32(uint256(0xff))
    // 虽然瞬时存储不占用永久槽位，但它仍然需要一个 bytes32 的key来定位。这个值与普通 ReentrancyGuard 的槽位一致，保证了逻辑的统一性。
    bytes32 private constant REENTRANCY_GUARD_STORAGE =
        0x9b779b17422d0df92223018b32b4d1fa46e071723d6817e2486d003becc55f00;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
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
        // On the first call to nonReentrant, REENTRANCY_GUARD_STORAGE.asBoolean().tload() will be false
        // 验证当前合约状态为非锁状态
        _nonReentrantBeforeView();

        // Any calls to nonReentrant after this point will fail
        // 将瞬时存储中对应的锁状态置为true
        _reentrancyGuardStorageSlot().asBoolean().tstore(true);
    }

    // 防重入锁解锁
    function _nonReentrantAfter() private {
        // 将瞬时存储中对应的锁状态置为false
        _reentrancyGuardStorageSlot().asBoolean().tstore(false);
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    // 内部函数，判断当前被调用函数是否处于锁状态。如果是，返回true，否则返回false。
    function _reentrancyGuardEntered() internal view returns (bool) {
        // 读取瞬时存储中对应的锁状态
        return _reentrancyGuardStorageSlot().asBoolean().tload();
    }

    // 返回在瞬时存储中锁状态对应的key
    function _reentrancyGuardStorageSlot() internal pure virtual returns (bytes32) {
        return REENTRANCY_GUARD_STORAGE;
    }
}
