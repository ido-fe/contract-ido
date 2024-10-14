// SPDX-License-Identifier: GPL-3.0
// Implementation of permit based on https://github.com/WETH10/WETH10/blob/main/contracts/WETH10.sol
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20TokenWrapped is ERC20Permit, ERC20Capped, Ownable, ERC20Burnable {
    // Decimals
    uint8 private immutable _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 __decimals,
        uint256 __cap
    )
        ERC20(name, symbol)
        ERC20Permit(name)
        ERC20Capped(__cap)
        Ownable(msg.sender)
    {
        _decimals = __decimals;
    }

    function mint(address to, uint256 value) external onlyOwner {
        _mint(to, value);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    // Blacklist restrict from-address, contains(burn's from-address)
    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override(ERC20, ERC20Capped) {
        ERC20Capped._update(from, to, value);
    }
}
