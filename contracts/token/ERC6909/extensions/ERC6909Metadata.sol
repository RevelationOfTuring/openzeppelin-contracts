// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (token/ERC6909/extensions/ERC6909Metadata.sol)

pragma solidity ^0.8.20;

import {ERC6909} from "../ERC6909.sol";
import {IERC6909Metadata} from "../../../interfaces/IERC6909.sol";

/**
 * @dev Implementation of the Metadata extension defined in ERC6909. Exposes the name, symbol, and decimals of each token id.
 */
// ERC6909Metadata是ERC-6909标准的一个重要扩展实现。在多代币系统中，由于一个合约内存在多种不同类型的代币，因此需要为每一个代币ID提供独立的描述性信息。这个合约的主要功能就是管理这些信息。
contract ERC6909Metadata is ERC6909, IERC6909Metadata {
    // 封装了单个代币id的三个核心属性：名称、symbol和 decimals
    struct TokenMetadata {
        string name;
        string symbol;
        uint8 decimals;
    }

    // 将id映射到对应的 TokenMetadata 结构体，实现了按id隔离的元数据存储
    mapping(uint256 id => TokenMetadata) private _tokenMetadata;

    /// @dev The name of the token of type `id` was updated to `newName`.
    event ERC6909NameUpdated(uint256 indexed id, string newName);

    /// @dev The symbol for the token of type `id` was updated to `newSymbol`.
    event ERC6909SymbolUpdated(uint256 indexed id, string newSymbol);

    /// @dev The decimals value for token of type `id` was updated to `newDecimals`.
    event ERC6909DecimalsUpdated(uint256 indexed id, uint8 newDecimals);

    /// @inheritdoc IERC6909Metadata
    // 返回指定代币id的人类可读名称
    function name(uint256 id) public view virtual override returns (string memory) {
        return _tokenMetadata[id].name;
    }

    /// @inheritdoc IERC6909Metadata
    // 返回指定代币id的简写符号
    function symbol(uint256 id) public view virtual override returns (string memory) {
        return _tokenMetadata[id].symbol;
    }

    /// @inheritdoc IERC6909Metadata
    // 返回指定代币的精度
    function decimals(uint256 id) public view virtual override returns (uint8) {
        return _tokenMetadata[id].decimals;
    }

    /**
     * @dev Sets the `name` for a given token of type `id`.
     *
     * Emits an {ERC6909NameUpdated} event.
     */

    // 内部管理函数，更新指定id的名称
    function _setName(uint256 id, string memory newName) internal virtual {
        _tokenMetadata[id].name = newName;

        emit ERC6909NameUpdated(id, newName);
    }

    /**
     * @dev Sets the `symbol` for a given token of type `id`.
     *
     * Emits an {ERC6909SymbolUpdated} event.
     */
    // 内部管理函数，更新指定id的符号
    function _setSymbol(uint256 id, string memory newSymbol) internal virtual {
        _tokenMetadata[id].symbol = newSymbol;

        emit ERC6909SymbolUpdated(id, newSymbol);
    }

    /**
     * @dev Sets the `decimals` for a given token of type `id`.
     *
     * Emits an {ERC6909DecimalsUpdated} event.
     */
    // 内部管理函数，更新指定id的精度
    function _setDecimals(uint256 id, uint8 newDecimals) internal virtual {
        _tokenMetadata[id].decimals = newDecimals;

        emit ERC6909DecimalsUpdated(id, newDecimals);
    }
}
