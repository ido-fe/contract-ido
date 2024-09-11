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

    /**
     * @dev Initializes the contract.
     * @param _initialOwner The initial owner.
     */
    function initialize(address _initialOwner) public initializer {
        __Ownable_init(_initialOwner);
        withdrawUsers[_initialOwner] = true;
        poolcreateUsers[_initialOwner] = true;
    }

    /*
     * @dev
        * @param _idoTokenA IDO Token A address.
        * @param _idoTokenAPrice IDO Token A price.
        * @param _idoTokenAAmount IDO Token A amount.
        * @param _idoMaxAmountPerAddress IDO max amount per address.
        * @param _tokenName Token B name.
        * @param _tokenSymbol Token B symbol.
     
     */

    function createPool(
        address _idoTokenA,
        uint256 _idoTokenAPrice,
        uint256 _idoTokenAAmount,
        uint256 _idoMaxAmountPerAddress,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _idoStartTime,
        uint256 _idoEndTime
    ) public onlyPoolCreate returns (address) {
        require(
            _idoStartTime < _idoEndTime,
            "Start time must be before end time "
        );
        require(
            block.timestamp < _idoStartTime,
            "Start time must be greater than now "
        );

        bytes32 salt = keccak256(
            abi.encodePacked(
                _idoTokenA,
                _idoTokenAPrice,
                _idoTokenAAmount,
                _idoMaxAmountPerAddress,
                _tokenName,
                _tokenSymbol,
                _idoStartTime,
                _idoEndTime,
                block.timestamp
            )
        );
        TGPool pool = new TGPool{salt: salt}(
            _idoTokenA,
            _idoTokenAPrice,
            _idoTokenAAmount,
            _idoMaxAmountPerAddress,
            _tokenName,
            _tokenSymbol,
            _idoStartTime,
            _idoEndTime
        );
        pools.push(address(pool));
        emit PoolCreated(address(pool));
        return address(pool);
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
        delete poolcreateUsers[_user];
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
        delete withdrawUsers[_user];
        emit WithdrawUserDeleted(_user);
    }

    /**
     * @dev mint tokenB from pool
     */
    function mintTokenB(address _pool) public onlyPoolCreate {
        ITGPool(_pool).mintTokenB();
    }

    /**
     * @dev add liquidity
     */
    function addLiquidity(address _pool) public onlyPoolCreate {
        ITGPool(_pool).addLiquidity();
    }

    /**
     * @dev remove liquidity
     */
    function removeLiquidity(address _pool) public onlyPoolCreate {
        ITGPool(_pool).removeLiquidity();
    }

    /**
     * @dev withdrawFee
     */
    function withdrawFee(address _pool) public onlyWithdraw {
        ITGPool(_pool).withdrawFee();
    }

    /**
     * @dev withdrawERC20
     */
    function withdrawERC20(address _pool, address _token) public onlyWithdraw {
        ITGPool(_pool).withdrawERC20(_token);
    }

    /**
     * @dev withdrawMNTAfterOverTime
     */
    function withdrawMNTAfterOverTime(address _pool) public onlyWithdraw {
        ITGPool(_pool).withdrawMNTAfterOverTime();
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
