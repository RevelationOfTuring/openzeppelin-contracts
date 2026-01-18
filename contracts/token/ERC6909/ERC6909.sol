// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (token/ERC6909/ERC6909.sol)

pragma solidity ^0.8.20;

import {IERC6909} from "../../interfaces/IERC6909.sol";
import {Context} from "../../utils/Context.sol";
import {IERC165, ERC165} from "../../utils/introspection/ERC165.sol";

// ERC-6909 是一种多代币标准（Multi-Token Standard），
// 其目标与 ERC-1155 类似，但它在设计上更加简洁，特别是在处理授权（Allowance）机制时更接近 ERC-20 的风格 。
// 即它结合了ERC-20的allowance和ERC-721/1155 的operator概念。一旦一个spender成为了某owner的operator，那么他的转账金额将不受allowance的限制。

/**
 * @dev Implementation of ERC-6909.
 * See https://eips.ethereum.org/EIPS/eip-6909
 */
contract ERC6909 is Context, ERC165, IERC6909 {
    // 存储每个地址在特定代币 ID 下的余额
    mapping(address owner => mapping(uint256 id => uint256)) private _balances;
    // 全局操作员授权。如果设置为 true，则操作员可以管理拥有者名下的所有代币
    mapping(address owner => mapping(address operator => bool)) private _operatorApprovals;
    // 细粒度的代币授权。允许为特定的代币 ID 设置特定的支出限额
    mapping(address owner => mapping(address spender => mapping(uint256 id => uint256))) private _allowances;

    // 余额不足
    error ERC6909InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 id);
    // 授权额度不足
    error ERC6909InsufficientAllowance(address spender, uint256 allowance, uint256 needed, uint256 id);
    // 以下为无效的地址操作（如指向零地址）
    error ERC6909InvalidApprover(address approver);
    error ERC6909InvalidReceiver(address receiver);
    error ERC6909InvalidSender(address sender);
    error ERC6909InvalidSpender(address spender);

    /// @inheritdoc IERC165
    // IERC165的接口支持检查，即实现了IERC6909
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        // type(IERC6909).interfaceId 的底层本质是IERC6909接口中定义的所有函数选择器的异或运算结果
        return interfaceId == type(IERC6909).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IERC6909
    // 查询特定账户owner拥有的特定代币id的余额
    function balanceOf(address owner, uint256 id) public view virtual override returns (uint256) {
        return _balances[owner][id];
    }

    /// @inheritdoc IERC6909
    // 查询spender被授权可以从owner账户中支取的特定代币id的数量
    function allowance(address owner, address spender, uint256 id) public view virtual override returns (uint256) {
        return _allowances[owner][spender][id];
    }

    /// @inheritdoc IERC6909
    // 查询spender是否被设置为owner的全局操作员。如果是，则可操作该owner的所有代币，不受allowance限制
    function isOperator(address owner, address spender) public view virtual override returns (bool) {
        return _operatorApprovals[owner][spender];
    }

    /// @inheritdoc IERC6909
    // 允许spender支取当前调用者名下特定id的代币，数量为amount
    function approve(address spender, uint256 id, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, id, amount);
        return true;
    }

    /// @inheritdoc IERC6909
    // 授予或撤销spender作为调用者的全局操作员权限
    function setOperator(address spender, bool approved) public virtual override returns (bool) {
        _setOperator(_msgSender(), spender, approved);
        return true;
    }

    /// @inheritdoc IERC6909
    // 直接转账函数，调用者将自己拥有的代币发送给receiver
    function transfer(address receiver, uint256 id, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), receiver, id, amount);
        return true;
    }

    /// @inheritdoc IERC6909
    // 代理转账函数 。如果调用者不是sender本人且不是全局操作员，则必须检查并扣减allowance
    function transferFrom(
        address sender,
        address receiver,
        uint256 id,
        uint256 amount
    ) public virtual override returns (bool) {
        address caller = _msgSender();
        // 如果调用者不是sender本人且不是全局操作员，则必须检查并扣减allowance
        if (sender != caller && !isOperator(sender, caller)) {
            _spendAllowance(sender, caller, id, amount);
        }
        // 转账
        _transfer(sender, receiver, id, amount);
        return true;
    }

    /**
     * @dev Creates `amount` of token `id` and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    // 内部铸造函数，将代币从0地址发送给to
    function _mint(address to, uint256 id, uint256 amount) internal {
        // 不能给0地址mint
        if (to == address(0)) {
            revert ERC6909InvalidReceiver(address(0));
        }
        _update(address(0), to, id, amount);
    }

    /**
     * @dev Moves `amount` of token `id` from `from` to `to` without checking for approvals. This function verifies
     * that neither the sender nor the receiver are address(0), which means it cannot mint or burn tokens.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */

    // 内部转账逻辑，强制检查from和to不能为零地址，以确保这不是Mint或Burn操作
    function _transfer(address from, address to, uint256 id, uint256 amount) internal {
        if (from == address(0)) {
            revert ERC6909InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC6909InvalidReceiver(address(0));
        }
        _update(from, to, id, amount);
    }

    /**
     * @dev Destroys a `amount` of token `id` from `account`.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    // 内部销毁函数，将代币从from发送到零地址
    function _burn(address from, uint256 id, uint256 amount) internal {
        if (from == address(0)) {
            revert ERC6909InvalidSender(address(0));
        }
        _update(from, address(0), id, amount);
    }

    /**
     * @dev Transfers `amount` of token `id` from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */

    // 这是 OpenZeppelin v5 架构中的核心设计模式。无论是转账、铸造还是销毁，最终都会汇聚到 _update 函数中
    // 该函数负责实际的余额变更
    function _update(address from, address to, uint256 id, uint256 amount) internal virtual {
        address caller = _msgSender();

        // from为0地址的操作为Mint操作，如果不是该操作需要从from地址中扣钱
        if (from != address(0)) {
            uint256 fromBalance = _balances[from][id];
            if (fromBalance < amount) {
                revert ERC6909InsufficientBalance(from, fromBalance, amount, id);
            }
            unchecked {
                // Overflow not possible: amount <= fromBalance.
                _balances[from][id] = fromBalance - amount;
            }
        }

        // to为0地址的操作为Burn操作，如果不是该操作需要向to地址中加钱
        if (to != address(0)) {
            _balances[to][id] += amount;
        }

        emit Transfer(caller, from, to, id, amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`'s `id` tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to e.g. set automatic allowances for certain
     * subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */

    // 内部核心授权逻辑，会验证地址合法性并更新_allowances映射，随后触发 Approval 事件
    // 注：该授权额度amount不是累加而是替换
    function _approve(address owner, address spender, uint256 id, uint256 amount) internal virtual {
        // owner和spender不可以为0地址
        if (owner == address(0)) {
            revert ERC6909InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC6909InvalidSpender(address(0));
        }
        // 更新allowances
        _allowances[owner][spender][id] = amount;
        emit Approval(owner, spender, id, amount);
    }

    /**
     * @dev Approve `spender` to operate on all of `owner`'s tokens
     *
     * This internal function is equivalent to `setOperator`, and can be used to e.g. set automatic allowances for
     * certain subsystems, etc.
     *
     * Emits an {OperatorSet} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */

    // 内部核心操作员逻辑，更新_operatorApprovals映射并触发OperatorSet 事件
    function _setOperator(address owner, address spender, bool approved) internal virtual {
        // owner和spender不可以为0地址
        if (owner == address(0)) {
            revert ERC6909InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC6909InvalidSpender(address(0));
        }
        _operatorApprovals[owner][spender] = approved;
        emit OperatorSet(owner, spender, approved);
    }

    /**
     * @dev Updates `owner`'s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */

    // 内部工具函数，用于扣减授权额度 。如果当前授权是type(uint256).max（无限授权），则跳过扣减以节省 Gas
    function _spendAllowance(address owner, address spender, uint256 id, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender, id);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < amount) {
                revert ERC6909InsufficientAllowance(spender, currentAllowance, amount, id);
            }
            unchecked {
                _allowances[owner][spender][id] = currentAllowance - amount;
            }
        }
    }
}
