pragma solidity ^0.8.0;

// import "openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Inheritance
import "./interfaces/IStakingContract.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


contract StakingContract is IStakingContract,ERC20,ReentrancyGuard, Pausable {
    
    using SafeERC20 for IERC20;
    using SafeERC20 for ERC20;
    /* ========== STATE VARIABLES ========== */

    struct ReedemableTokens{
        uint256 amountRedeemable;
        uint256 coolDownTime;
    }

    
    IERC20 public stakingToken;
    
    uint256 public rewardRate = 1;
    
    uint256 public lastUpdateBlockNumber;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => ReedemableTokens) public userToRedeemTokensMapping; 

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    /* ========== CONSTRUCTOR ========== */

    constructor( 
        address _stakingToken
    ) ERC20("STAKE-ZAMP-TOKENS", "stkZAMP") {
        require(_stakingToken != address(0), "invalid staking token address");
        stakingToken = IERC20(_stakingToken); 
    }

    /* ========== VIEWS ========== */

    function getTotalDeposit() external view returns (uint256 totalDeposit) {
        totalDeposit =  _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    

    function getRate() external view returns (uint256 rate) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        rate = 
            rewardPerTokenStored +
            (((block.number - lastUpdateBlockNumber) * rewardRate * 1e18) / _totalSupply);
    }


    

    function deposit(uint256 amount) external nonReentrant notPaused updateReward(msg.sender)returns (uint256 stakedTokenOut) {
        require(amount > 0, "Cannot stake 0");
         _totalSupply += amount;
        _balances[msg.sender] += amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        _mint(msg.sender,amount);
        stakedTokenOut = amount;
        emit Staked(msg.sender, amount);
    }

    function redeem(uint256 amount) external nonReentrant updateReward(msg.sender) returns (uint256 tokenAmountOut){
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply -= amount;
        _balances[msg.sender] -= amount;
        // _burn(msg.sender,amount);
        // stakingToken.safeTransfer(msg.sender, amount);
        userToRedeemTokensMapping[msg.sender].amountRedeemable = amount;
        userToRedeemTokensMapping[msg.sender].coolDownTime = block.timestamp + 3600;
        tokenAmountOut = amount+rewards[msg.sender];
        // emit Withdrawn(msg.sender, amount);
    }

    function claim() external nonReentrant updateReward(msg.sender) returns (uint256 claimedTokenAmount) {
        uint256 tokensToRedeem = userToRedeemTokensMapping[msg.sender].amountRedeemable;
        unit256 cooldownTime = userToRedeemTokensMapping[msg.sender].coolDownTime;
        
        require(tokensToRedeem> 0,"Not found any redeemable tokens");
        require(cooldownTime < block.timestamp,"Cooldown period is not over");
        uint256 reward = rewards[msg.sender];
        
        if (reward > 0) {
            rewards[msg.sender] = 0;
            _burn(msg.sender,tokensToRedeem);
            claimedTokenAmount = reward + tokensToRedeem;
            stakingToken.safeTransfer(msg.sender, claimedTokenAmount);
            emit Claimed(msg.sender, claimedTokenAmount);
        }
    }

   

    /* ========== MODIFIERS ========== */

   function rewardPerToken() public view returns (uint) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            (((block.number - lastUpdateBlockNumber) * rewardRate * 1e18) / _totalSupply);
    }

    function earned(address account) public view returns (uint) {
        return
            ((_balances[account] *
                (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
            rewards[account];
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.number;

        rewards[account] = earned(account);
        userRewardPerTokenPaid[account] = rewardPerTokenStored;
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Deposited(address indexed user, uint256 amount);
    event Redeemed(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
   
}