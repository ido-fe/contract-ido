// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ERC20TokenWrapped.sol";
import "./interface/IToken.sol";
import "./interface/IUniswap.sol";

contract TGPool is Ownable, Pausable, ReentrancyGuard {
    // IDO Token A :MNT
    address public idoTokenA;
    // 1MNT = 200000 TokenB
    uint256 public idoTokenAPrice;
    // IDO Token A hardcore 50000 MNT
    uint256 public idoTokenAAmount;
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

    // IDO
    mapping(address => uint256) public idoAddressAmount;
    // Claim last time
    mapping(address => uint256) public lastClaimTime;

    //claim amount
    uint256 public claimedAmount;

    // owner withdrawed
    bool public OwnerWithdrawed;

    bool public isAddLiquidity;

    bool public isMintTokenB;

    ERC20TokenWrapped token;
    address private constant FACTORY =
        0x211b74591166485c73c473572220D7D01b2219Cb;
    address private constant ROUTER =
        0x44D7966fc0b9f4d521b83964f13Db9F48875d213;
    address private constant WMNT = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8;

    using SafeERC20 for IERC20;

    event Deposit(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event Withdraw(address token, uint256 amount);
    event Received(address sender, uint256 amount);
    event TokenCreate(address token, uint256 amount);
    event TokenMint(address to, uint256 amount);

    modifier onlyValidAddress(address addr) {
        require(addr != address(0), "Illegal address");
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

    //constructor中定义上面的public变量，自动生成代码
    constructor(
        address _idoTokenA,
        uint256 _idoTokenAPrice,
        uint256 _idoTokenAAmount,
        uint256 _idoMaxAmountPerAddress,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _idoStartTime,
        uint256 _idoEndTime
    ) Ownable(msg.sender) {
        idoTokenA = _idoTokenA;
        idoTokenAPrice = _idoTokenAPrice;
        idoTokenAAmount = _idoTokenAAmount;
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
    }

    /**
     * @dev Deposit for the IDO.
     */
    function _deposit(uint256 amount) private whenNotPaused nonReentrant {
        require(
            idoAddressAmount[_msgSender()] + amount <= idoMaxAmountPerAddress,
            "Exceeds the max amount per address"
        );
        require(idoAmount + amount <= idoTokenAAmount, "IDO amount is full");

        idoAddressAmount[_msgSender()] += amount;
        idoAmount += amount;

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
        require(idoAmount != idoTokenAAmount, "ido not full,failed");

        uint256 amount = idoAddressAmount[_msgSender()];
        require(amount > 0, "No deposit amount");
        idoAddressAmount[_msgSender()] = 0;
        idoAmount -= amount;
        (bool success, ) = payable(_msgSender()).call{value: amount}("");
        require(success, "Native Token Transfer Failed");
        emit Withdraw(address(0), amount);
    }

    // idoendtime mint token B
    function mintTokenB() public onlyOwner {
        require(
            block.timestamp >= idoEndTime,
            "Claim time must be after ido end time"
        );
        require(tokenCap == 0, "Token B has been minted");
        require(idoAmount == idoTokenAAmount, "IDO amount is not full");

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

    // add liquidity

    function addLiquidity() public onlyOwner {
        require(!isAddLiquidity, "");
        safeApprove(tokenB, ROUTER, tokenDexAmount);
        uint256 mntAmount = idoAmount - tokenFeeAmountMNT;
        IUniswapV2Router(ROUTER).addLiquidityETH{value: mntAmount}(
            tokenBAddress,
            tokenDexAmount,
            1, // slippage is unavoidable
            1, // slippage is unavoidable
            owner(),
            block.timestamp
        );

        isAddLiquidity = true;
    }

    function removeLiquidity() public onlyOwner {
        require(isAddLiquidity, "");
        address pair = IUniswapV2Factory(FACTORY).getPair(WMNT, tokenBAddress);

        uint256 liquidity = IERC20(pair).balanceOf(address(this));
        safeApprove(IERC20(pair), ROUTER, liquidity);
        IUniswapV2Router(ROUTER).removeLiquidityETH(
            tokenBAddress,
            liquidity,
            1, // slippage is unavoidable
            1, // slippage is unavoidable
            owner(),
            block.timestamp
        );

        isAddLiquidity = false;
    }

    function safeApprove(
        IERC20 _token,
        address spender,
        uint256 amount
    ) internal {
        (bool success, bytes memory returnData) = address(_token).call(
            abi.encodeCall(IERC20.approve, (spender, amount))
        );
        require(
            success &&
                (returnData.length == 0 || abi.decode(returnData, (bool))),
            "Approve fail"
        );
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
        uint256 amount = (_now - _start) * rewardPerSecond;
        IERC20(tokenBAddress).transfer(_msgSender(), amount);
        emit Claimed(_msgSender(), amount);

        lastClaimTime[_msgSender()] = block.timestamp;
        claimedAmount += amount;
    }

    /**
     * @dev Withdraws the token.
     * 1% MNT +1%的tokenB 给平台， 1%的tokenB给MEME创建者
     *
     */
    function withdrawFee() public onlyOwner {
        require(!OwnerWithdrawed, "Owner has withdrawed");
        require(
            block.timestamp >= idoEndTime,
            "Claim time must be after ido end time"
        );
        // for platform  1% tokenB + 1% MNT

        IERC20(tokenBAddress).transfer(owner(), tokenFeeAmount);

        (bool success, ) = payable(owner()).call{value: tokenFeeAmountMNT}("");
        require(success, "Native Token Transfer Failed");
        emit Withdraw(address(0), tokenFeeAmountMNT);

        // for meme creator
        IERC20(tokenBAddress).transfer(owner(), tokenRewardCreaterAmount);

        OwnerWithdrawed = true;
    }

    /**
     * @dev Withdraw token After claimOverTime.
     *
     */
    function withdrawERC20(address _token) public onlyOwner {
        require(
            block.timestamp >= claimOverTime,
            "Claim time must be after ido end time"
        );
        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(owner(), amount);
        emit Withdraw(_token, amount);
    }

    /**
     * @dev Withdraw MNT After claimOverTime.
     *
     */

    function withdrawMNTAfterOverTime() public onlyOwner {
        require(
            block.timestamp >= claimOverTime,
            "Claim time must be after ido end time"
        );

        uint256 balance = address(this).balance;
        require(balance > 0, "No native token to withdraw");
        // Use call method for safer Ether transfer
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawable: Native Token transfer failed");
        emit Withdraw(address(0), balance);
    }

    /**
     * @dev Pauses the contract.
     */
    function pause() public onlyOwner {
        _pause();
        emit Paused(_msgSender());
    }

    /**
     * @dev Unpauses the contract.
     */
    function unpause() public onlyOwner {
        _unpause();
        emit Unpaused(_msgSender());
    }

    // Function to receive MNT
    receive() external payable {
        emit Received(_msgSender(), msg.value);
    }
}
