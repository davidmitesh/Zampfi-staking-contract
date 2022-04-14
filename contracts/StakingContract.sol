pragma solidity ^0.8.0;

// import "openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Inheritance
import "./interfaces/IStakingContract.sol";
import "./RewardsDistributionRecipient.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

// https://docs.synthetix.io/contracts/source/contracts/stakingrewards
contract StakingContract is IStakingContract,ERC20,ReentrancyGuard, Pausable {
    
    using SafeERC20 for IERC20;
    using SafeERC20 for ERC20;
    /* ========== STATE VARIABLES ========== */

    IERC20 public rewardsToken;
    IERC20 public stakingToken;
    // uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    // uint256 public rewardsDuration = 7 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _owner,
        
        address _rewardsToken,
        address _stakingToken
    ) public Owned(_owner) {
        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC20(_stakingToken);
        
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    

    function getRate() public view returns (uint) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            (((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / _totalSupply);
    }


    // function earned(address account) public view returns (uint) {
    //     return
    //         ((_balances[account] *
    //             (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
    //         rewards[account];
    // }

    // function getRewardForDuration() external view returns (uint256) {
    //     return rewardRate.mul(rewardsDuration);
    // }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function deposit(uint256 amount) external nonReentrant notPaused updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
         _totalSupply += _amount;
        _balances[msg.sender] += _amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function redeem(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply -= _amount;
        _balances[msg.sender] -= _amount;
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    // function exit() external {
    //     withdraw(_balances[msg.sender]);
    //     getReward();
    // }

    /* ========== RESTRICTED FUNCTIONS ========== */

    // function notifyRewardAmount(uint256 reward) external onlyRewardsDistribution updateReward(address(0)) {
    //     if (block.timestamp >= periodFinish) {
    //         rewardRate = reward.div(rewardsDuration);
    //     } else {
    //         uint256 remaining = periodFinish.sub(block.timestamp);
    //         uint256 leftover = remaining.mul(rewardRate);
    //         rewardRate = reward.add(leftover).div(rewardsDuration);
    //     }

    //     // Ensure the provided reward amount is not more than the balance in the contract.
    //     // This keeps the reward rate in the right range, preventing overflows due to
    //     // very high values of rewardRate in the earned and rewardsPerToken functions;
    //     // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
    //     uint balance = rewardsToken.balanceOf(address(this));
    //     require(rewardRate <= balance.div(rewardsDuration), "Provided reward too high");

    //     lastUpdateTime = block.timestamp;
    //     periodFinish = block.timestamp.add(rewardsDuration);
    //     emit RewardAdded(reward);
    // }

 

    // function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
    //     require(
    //         block.timestamp > periodFinish,
    //         "Previous rewards period must be complete before changing the duration for the new period"
    //     );
    //     rewardsDuration = _rewardsDuration;
    //     emit RewardsDurationUpdated(rewardsDuration);
    // }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Deposited(address indexed user, uint256 amount);
    event Redeemed(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
   
}