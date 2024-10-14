// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interface/IIDOPool.sol";
import "./TGPool.sol";

contract TGFactory is OwnableUpgradeable {
    address[] public pools;
    // pool creater mapping
    mapping(address => bool) public withdrawUsers;
    mapping(address => bool) public poolcreateUsers;
    mapping(bytes32 => address) public poolMap;
    event PoolCreated(address indexed pool);
    event WithdrawUserAdded(address indexed user);
    event WithdrawUserDeleted(address indexed user);
    event CreatePoolUserAdded(address indexed user);
    event CreatePoolUserDeleted(address indexed user);
    event Withdraw(address token, uint256 amount);
    event Received(address sender, uint256 amount);

    modifier onlyValidAddress(address addr) {
        require(addr != address(0), "Illegal address");
        _;
    }

    modifier onlyPoolCreate() {
        require(
            poolcreateUsers[msg.sender] == true,
            "LDO Factory::onlyPoolCreateUser: Not PoolCreateUser"
        );
        _;
    }
    modifier onlyWithdraw() {
        require(
            withdrawUsers[msg.sender] == true,
            "LDO Factory::onlyWithdrawUser: Not WithdrawUser"
        );
        _;
    }

    function initialize(address _initialOwner) public initializer {
        __Ownable_init(_initialOwner);
        withdrawUsers[_initialOwner] = true;
        poolcreateUsers[_initialOwner] = true;
    }

    function createPool(
        address _idoTokenA,
        uint256 _idoTokenAPrice,
        uint256 _idoTokenAMaxAmount,
        uint256 _idoTokenAMinAmount,
        uint256 _idoMaxAmountPerAddress,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _idoStartTime,
        uint256 _idoEndTime
    ) public onlyPoolCreate returns (address) {
        bytes32 salt = keccak256(
            abi.encodePacked(
                _tokenSymbol,
                _idoStartTime,
                _idoEndTime,
                block.timestamp
            )
        );
        bytes32 key = keccak256(
            abi.encodePacked(_tokenSymbol, _idoStartTime, _idoEndTime)
        );
        TGPool pool = new TGPool{salt: salt}(
            _idoTokenA,
            _idoTokenAPrice,
            _idoTokenAMaxAmount,
            _idoTokenAMinAmount,
            _idoMaxAmountPerAddress,
            _tokenName,
            _tokenSymbol,
            _idoStartTime,
            _idoEndTime,
            owner()
        );
        address poolAddress = address(pool);
        pools.push(poolAddress);
        poolMap[key] = poolAddress;

        emit PoolCreated(poolAddress);
        return poolAddress;
    }

    /**
     * @dev key get pool address
     */
    function getPoolAddress(
        string memory _tokenSymbol,
        uint256 _idoStartTime,
        uint256 _idoEndTime
    ) public view returns (address) {
        bytes32 key = keccak256(
            abi.encodePacked(_tokenSymbol, _idoStartTime, _idoEndTime)
        );
        return poolMap[key];
    }

    /**
     * @dev Set Super User
     */
    function setPoolCreateUser(
        address _user
    ) public onlyOwner onlyValidAddress(_user) {
        poolcreateUsers[_user] = true;
        emit CreatePoolUserAdded(_user);
    }

    /**
     * @dev Detele Super User
     */
    function deletePoolCreateUser(
        address _user
    ) public onlyOwner onlyValidAddress(_user) {
        poolcreateUsers[_user] = false;
        emit CreatePoolUserDeleted(_user);
    }

    /**
     * @dev Set Withdraw User
     */

    function setWithdrawUser(
        address _user
    ) public onlyOwner onlyValidAddress(_user) {
        withdrawUsers[_user] = true;
        emit WithdrawUserAdded(_user);
    }

    /**
     * @dev Detele Withdraw User
     */
    function deleteWithdrawUser(
        address _user
    ) public onlyOwner onlyValidAddress(_user) {
        withdrawUsers[_user] = false;
        emit WithdrawUserDeleted(_user);
    }

    /**
     * @dev mint tokenB from pool
     */
    function mintTokenB(address _pool) public onlyPoolCreate {
        ITGPool(_pool).mintTokenB();
    }

    /**
     * @dev withliquidity 19% token B + 99% MNT
     */
    function withdrawLiquidity(address _pool, address _to) public onlyWithdraw {
        ITGPool(_pool).withdrawLiquidity(_to);
    }

    /**
     * @dev withdrawFee
     */
    function withdrawFee(address _pool, address _to) public onlyWithdraw {
        ITGPool(_pool).withdrawFee(_to);
    }

    /**
     * @dev withdrawERC20
     */
    function withdrawERC20(
        address _pool,
        address _token,
        address _to
    ) public onlyWithdraw {
        ITGPool(_pool).withdrawERC20(_token, _to);
    }

    /**
     * @dev withdrawMNTAfterOverTime
     */
    function withdrawMNTAfterOverTime(
        address _pool,
        address _to
    ) public onlyWithdraw {
        ITGPool(_pool).withdrawMNTAfterOverTime(_to);
    }

    /**
     * @dev updateMerkleRoot
     */
    function updateMerkleRoot(
        address _pool,
        bytes32 _merkleRoot,
        uint256 amount
    ) public onlyPoolCreate {
        ITGPool(_pool).updateMerkleRoot(_merkleRoot, amount);
    }

    /**
     * @dev pause pool
     */

    function pausePool(address _pool) public onlyOwner {
        ITGPool(_pool).pause();
    }

    function unpausePool(address _pool) public onlyOwner {
        ITGPool(_pool).unpause();
    }

    /**
     * @dev factory withdraw MNT
     */
    function withdrawMNT() public onlyWithdraw {
        require(address(this).balance > 0, "No MNT to withdraw");
        payable(owner()).transfer(address(this).balance);
        emit Withdraw(address(0), address(this).balance);
    }

    // /**
    //  * @dev factory withdraw ERC20 token
    //  */
    function withdrawERC20(
        address _token,
        uint256 _amount
    ) public onlyWithdraw {
        IERC20(_token).transfer(owner(), _amount);
        emit Withdraw(_token, _amount);
    }

    /**
     * @dev Returns the pools.
     */
    function getPools() public view returns (address[] memory) {
        return pools;
    }

    // Function to receive ETH
    receive() external payable {
        emit Received(_msgSender(), msg.value);
    }
}
