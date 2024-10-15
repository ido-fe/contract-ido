// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./ERC20TokenWrapped.sol";
import "./interface/IToken.sol";

contract TGPool is Ownable, Pausable, ReentrancyGuard {
    // IDO Token A :MNT
    address public idoTokenA;
    // 1MNT = 200000 TokenB
    uint256 public idoTokenAPrice;
    // IDO Token A hardcore 50000 MNT
    uint256 public idoTokenAMaxAmount;
    // IDO Token A lower limit 1000 MNT
    uint256 public idoTokenAMinAmount;
    // realAMount IDO 30000 MNT
    uint256 public idoAmount;
    // IDO 500MNT per address
    uint256 public idoMaxAmountPerAddress;

    // IDO Token B
    string public tokenName;
    string public tokenSymbol;
    address public tokenBAddress;
    IToken public tokenB;
    // Token B cap = idoAmount * idoTokenAPrice
    uint256 public tokenCap;
    // token B for user claim  79% = tokenCap % 790/1000
    uint256 public tokenRewardClaimRate;
    uint256 public tokenRewardClaimAmount;

    //token B for meme creater  1% = 10/1000

    uint256 public tokenRewardCreaterRate;
    uint256 public tokenRewardCreaterAmount;

    // Token B for dex  = tokenCap % 190/1000
    uint256 public tokenDexRate;
    uint256 public tokenDexAmount;
    // Token B、MNT platform fee 1% = 10/1000
    uint256 public tokenFeeRate;
    uint256 public tokenFeeAmount;
    uint256 public tokenFeeAmountMNT;

    // IDO start time
    uint256 public idoStartTime;
    // IDO endtime = Claim start time
    uint256 public idoEndTime;
    // claim 6days
    uint256 public claimEndTime;
    // claim over 30 days ,user can't claim
    uint256 public claimOverTime;
    // 79% tken b for user claim
    uint256 public rewardPerSecond;
    // how many address join ido
    //feature 1
    uint256 public idoAddressAmountTotal;
    // merkle root for meme creater and voter
    bytes32 public merkleRoot;

    //merkle claim amount
    uint256 public merkleClaimAmount;
    // merkle claimed
    mapping(address => bool) public merkleClaimed;

    // IDO
    mapping(address => uint256) public idoAddressAmount;
    // Claim last time
    mapping(address => uint256) public lastClaimTime;

    //feature2
    //user claimed amount
    mapping(address => uint256) public userClaimAmount;

    // idoamount < idominamount user withdraw
    mapping(address => bool) public userWithdrawed;

    mapping(address => bool) public Admins;

    //claim amount
    uint256 public claimedAmount;

    // owner withdraw fee
    bool public OwnerWithdrawed;
    // owner mint tokenb
    bool public isMintTokenB;
    // owner update merkle root
    bool public isUpdateMerkleRoot;

    ERC20TokenWrapped token;

    using SafeERC20 for IERC20;

    event Deposit(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event Withdraw(address token, uint256 amount);
    event Received(address sender, uint256 amount);
    event TokenCreate(address token, uint256 amount);
    event TokenMint(address to, uint256 amount);
    event WithdrawLiquidity(address to, uint256 amount);
    event MerkleRootUpdated(bytes32 merkleRoot);
    event MerkleClaimed(address indexed user, uint256 amount);

    modifier onlyValidAddress(address addr) {
        require(addr != address(0), "Illegal address");
        _;
    }
    modifier onlyAdmin() {
        require(
            Admins[_msgSender()] == true,
            "Token Distributor::onlySendUser: Not SendUser"
        );
        _;
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

    constructor(
        address _idoTokenA,
        uint256 _idoTokenAPrice,
        uint256 _idoTokenAMaxAmount,
        uint256 _idoTokenAMinAmount,
        uint256 _idoMaxAmountPerAddress,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _idoStartTime,
        uint256 _idoEndTime,
        address factoryOwner
    ) Ownable(_msgSender()) {
        idoTokenA = _idoTokenA;
        idoTokenAPrice = _idoTokenAPrice;
        idoTokenAMaxAmount = _idoTokenAMaxAmount;
        idoTokenAMinAmount = _idoTokenAMinAmount;
        idoMaxAmountPerAddress = _idoMaxAmountPerAddress;
        tokenName = _tokenName;
        tokenSymbol = _tokenSymbol;
        idoStartTime = _idoStartTime;
        idoEndTime = _idoEndTime;
        tokenRewardClaimRate = 790;
        tokenRewardCreaterRate = 10;
        tokenDexRate = 190;
        tokenFeeRate = 10;
        claimEndTime = idoEndTime + 6 days;
        claimOverTime = idoEndTime + 30 days;
        Admins[_msgSender()] = true;
        Admins[factoryOwner] = true;
    }

    /**
     * @dev Deposit for the IDO.
     */
    function _deposit(uint256 amount) private whenNotPaused nonReentrant {
        require(
            idoAddressAmount[_msgSender()] + amount <= idoMaxAmountPerAddress,
            "Exceeds the max amount per address"
        );
        require(idoAmount + amount <= idoTokenAMaxAmount, "IDO amount is full");

        idoAddressAmount[_msgSender()] += amount;
        idoAmount += amount;
        idoAddressAmountTotal += 1;

        emit Deposit(_msgSender(), amount);
    }

    function DepositMNT() public payable whenNotPaused {
        require(block.timestamp >= idoStartTime, "IDO time is not valid");
        require(block.timestamp <= idoEndTime, "IDO time is not valid");
        require(idoTokenA == address(0), "Cannot deposit with erc20 token");
        _deposit(msg.value);
    }

    // ido failed idoAmount< idoTokenAAmount
    function withdrawMNTByUser() public whenNotPaused nonReentrant {
        require(
            block.timestamp >= idoEndTime,
            "Claim time must be after ido end time"
        );
        require(idoAmount < idoTokenAMinAmount, "ido not full,failed");

        uint256 amount = idoAddressAmount[_msgSender()];
        require(amount > 0, "No deposit amount");
        idoAddressAmount[_msgSender()] = 0;
        idoAmount -= amount;
        (bool success, ) = payable(_msgSender()).call{value: amount}("");
        require(success, "Native Token Transfer Failed");
        userWithdrawed[_msgSender()] = true;
        emit Withdraw(address(0), amount);
    }

    // idoendtime mint token B
    function mintTokenB() public onlyAdmin {
        require(
            block.timestamp >= idoEndTime,
            "Claim time must be after ido end time"
        );
        require(tokenCap == 0, "Token B has been minted");
        require(idoAmount >= idoTokenAMinAmount, "IDO amount is not enough");

        tokenCap = idoAmount * idoTokenAPrice;
        rewardPerSecond =
            (tokenCap * tokenRewardClaimRate) /
            (claimEndTime - idoEndTime);

        token = new ERC20TokenWrapped(
            tokenName,
            tokenSymbol,
            uint8(18),
            tokenCap
        );
        tokenBAddress = address(token);
        emit TokenCreate(address(token), tokenCap);

        tokenB = IToken(tokenBAddress);
        tokenB.mint(address(this), tokenCap);
        emit TokenMint(address(this), tokenCap);

        tokenRewardClaimAmount = (tokenCap * tokenRewardClaimRate) / 1000;
        tokenRewardCreaterAmount = (tokenCap * tokenRewardCreaterRate) / 1000;
        tokenDexAmount = (tokenCap * tokenDexRate) / 1000;
        tokenFeeAmount = (tokenCap * tokenFeeRate) / 1000;
        tokenFeeAmountMNT = (idoAmount * tokenFeeRate) / 1000;

        rewardPerSecond = tokenRewardClaimAmount / (claimEndTime - idoEndTime);
        isMintTokenB = true;
    }

    function updateMerkleRoot(
        bytes32 _merkleRoot,
        uint256 amount
    ) public onlyAdmin {
        require(isMintTokenB, "Token B has not been minted");
        require(
            amount == tokenRewardCreaterAmount,
            "Merkle root Amount : Invalid amount"
        );
        require(!isUpdateMerkleRoot, "Merkle Root has been updated");
        merkleRoot = _merkleRoot;
        isUpdateMerkleRoot = true;
        emit MerkleRootUpdated(_merkleRoot);
    }

    // amount need decimals
    function merkleClaim(
        bytes32[] calldata proof,
        uint256 amount
    ) external whenNotPaused nonReentrant {
        require(isUpdateMerkleRoot, "Merkle Root has not been updated");
        require(
            merkleClaimAmount + amount <= tokenRewardCreaterAmount,
            "Merkle Claim: Invalid amount"
        );

        require(!merkleClaimed[_msgSender()], "Merkle Claim: Already claimed");

        // (1）
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(_msgSender(), amount)))
        );
        // (2)
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid proof");

        require(
            tokenB.transfer(_msgSender(), amount),
            "TokenAirdrop: Transfer failed"
        );
        merkleClaimAmount += amount;
        merkleClaimed[_msgSender()] = true;

        emit MerkleClaimed(_msgSender(), amount);
    }

    function withdrawLiquidity(address _to) public onlyAdmin {
        require(isMintTokenB, "Token B has not been minted");
        //99% MNT
        uint256 mntAmount = idoAmount - tokenFeeAmountMNT;
        require(mntAmount > 0, "No MNT to withdraw");
        (bool success, ) = payable(_to).call{value: mntAmount}("");
        require(success, "Native Token Transfer Failed");
        // 19% tokenB
        tokenB.transfer(_to, tokenDexAmount);
        emit WithdrawLiquidity(_to, mntAmount);
    }

    /**
     * @dev Claims the IDO.
     * 用户参与IDO后，结束时间后可领取IDO Token B 线性解锁
     */
    function claim() public whenNotPaused nonReentrant {
        require(
            block.timestamp >= idoEndTime,
            "Claim time must be after ido end time"
        );
        require(
            block.timestamp <= claimOverTime,
            "Claim time must be before claim over time"
        );
        require(isMintTokenB, "Token B has not been minted");
        uint256 _now = block.timestamp;
        if (block.timestamp > claimEndTime) {
            _now = claimEndTime;
        }
        uint256 _start = lastClaimTime[_msgSender()];
        if (_start == 0) {
            _start = idoEndTime;
        }
        uint256 amount = ((_now - _start) *
            rewardPerSecond *
            idoAddressAmount[_msgSender()]) / idoAmount;
        require(amount > 0, "No claimable amount");
        tokenB.transfer(_msgSender(), amount);
        emit Claimed(_msgSender(), amount);

        lastClaimTime[_msgSender()] = block.timestamp;
        userClaimAmount[_msgSender()] += amount;
        claimedAmount += amount;
    }

    /**
     * @dev Withdraws the token.
     * 1% MNT +1%的tokenB 给平台， 1%的tokenB给MEME创建者
     *
     */
    function withdrawFee(address _to) public onlyAdmin {
        require(!OwnerWithdrawed, "Owner has withdrawed");
        require(
            block.timestamp >= idoEndTime,
            "Claim time must be after ido end time"
        );
        require(isMintTokenB, "Token B has not been minted");
        // for platform  1% tokenB + 1% MNT

        tokenB.transfer(_to, tokenFeeAmount);

        (bool success, ) = payable(_to).call{value: tokenFeeAmountMNT}("");
        require(success, "Native Token Transfer Failed");
        emit Withdraw(address(0), tokenFeeAmountMNT);

        // // for meme creator
        // IERC20(tokenBAddress).transfer(owner(), tokenRewardCreaterAmount);

        OwnerWithdrawed = true;
    }

    /**
     * @dev Withdraw token After claimOverTime.
     *
     */
    function withdrawERC20(address _token, address _to) public onlyAdmin {
        require(
            block.timestamp >= claimOverTime,
            "Claim time must be after ido end time"
        );
        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(_to, amount);
        emit Withdraw(_token, amount);
    }

    /**
     * @dev Withdraw MNT After claimOverTime.
     *
     */

    function withdrawMNTAfterOverTime(address _to) public onlyAdmin {
        require(
            block.timestamp >= claimOverTime,
            "Claim time must be after ido end time"
        );

        uint256 balance = address(this).balance;
        require(balance > 0, "No native token to withdraw");
        // Use call method for safer Ether transfer
        (bool success, ) = payable(_to).call{value: balance}("");
        require(success, "Withdrawable: Native Token transfer failed");
        emit Withdraw(address(0), balance);
    }

    /**
     * @dev Pauses the contract.
     */
    function pause() public onlyAdmin {
        _pause();
        emit Paused(_msgSender());
    }

    /**
     * @dev Unpauses the contract.
     */
    function unpause() public onlyAdmin {
        _unpause();
        emit Unpaused(_msgSender());
    }

    // Function to receive MNT
    receive() external payable {
        emit Received(_msgSender(), msg.value);
    }
}
