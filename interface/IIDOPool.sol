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
    event WithdrawLiquidity(address to, uint256 amount);
    event MerkleRootUpdated(bytes32 merkleRoot);
    event MerkleClaimed(address indexed user, uint256 amount);
    event Paused(address account);
    event Unpaused(address account);

    // Public functions
    function DepositMNT() external payable;

    function withdrawMNTByUser() external;

    function updateMerkleRoot(bytes32 _merkleRoot, uint256 amount) external;

    function merkleClaim(bytes32[] calldata proof, uint256 amount) external;

    function mintTokenB() external;

    function withdrawLiquidity(address _to) external;

    function claim() external;

    function withdrawFee(address _to) external;

    function withdrawERC20(address _token, address _to) external;

    function withdrawMNTAfterOverTime(address _to) external;

    function pause() external;

    function unpause() external;

    // Receive function to accept MNT
    // receive() external payable;
}
