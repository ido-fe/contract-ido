// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface ITGPool {
    // Events
    event Deposit(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event Withdraw(address token, uint256 amount);
    event Received(address sender, uint256 amount);
    event TokenCreate(address token, uint256 amount);
    event TokenMint(address to, uint256 amount);
    event Paused(address account);
    event Unpaused(address account);

    // Public/External Functions

    function mintTokenB() external;

    function addLiquidity() external;

    function removeLiquidity() external;

    function withdrawFee() external;

    function withdrawERC20(address _token) external;

    function withdrawMNTAfterOverTime() external;

    function pause() external;

    function unpause() external;
}
