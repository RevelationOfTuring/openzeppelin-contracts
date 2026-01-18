// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (token/ERC6909/extensions/ERC6909TokenSupply.sol)

pragma solidity ^0.8.20;

import {ERC6909} from "../ERC6909.sol";
import {IERC6909TokenSupply} from "../../../interfaces/IERC6909.sol";

/**
 * @dev Implementation of the Token Supply extension defined in ERC6909.
 * Tracks the total supply of each token id individually.
 */
// ERC6909TokenSupply的核心任务是追踪多代币系统中每一个独立代币id的总供应量
contract ERC6909TokenSupply is ERC6909, IERC6909TokenSupply {
    // 存储每个代币id对应的当前总供应量
    mapping(uint256 id => uint256) private _totalSupplies;

    /// @inheritdoc IERC6909TokenSupply
    // 返回特定代币id的当前存世总量
    function totalSupply(uint256 id) public view virtual override returns (uint256) {
        return _totalSupplies[id];
    }

    /// @dev Override the `_update` function to update the total supply of each token id as necessary.
    // 重写_update内部函数，实现了供应量的自动化管理
    function _update(address from, address to, uint256 id, uint256 amount) internal virtual override {
        // 先执行ERC6909._update()，进行from和to的账户余额变更
        super._update(from, to, id, amount);

        // 如果是mint交易，增加总供应量
        if (from == address(0)) {
            _totalSupplies[id] += amount;
        }
        // 如果是burn交易，较少总供应量
        if (to == address(0)) {
            unchecked {
                // amount <= _balances[from][id] <= _totalSupplies[id]
                // 在super._update()中已经校验了amount <= _balances[from][id]，所以这里必然不会反向溢出
                _totalSupplies[id] -= amount;
            }
        }
    }
}
