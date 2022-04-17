// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IStakingContract.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/**
 * @title Model ZampFi Staking Contract
 * @notice Contract to stake Zamp tokens, and 1 zamp token is added to totalSupply each block.
 *         The Liquidity tokens that are minted, are given out based on the current conversion 
 *          rate between Zamp tokens and stkZamp tokens. Additional 1 hour cooldown period is 
 *          added between the redeeming and the claiming phase.
 * @author Mitesh Pandey (https://github.com/davidmitesh) (excelrock_mitesh@yahoo.com)
 */

contract LiquidityStakingContract is IStakingContract,ERC20,Ownable, Pausable{
    using SafeERC20 for IERC20;
    using SafeERC20 for ERC20;

    //This struct is used to keep the record of the zampAmount that is scheduled to be claimed
    struct ClaimReceipt{
        uint256 zampAmount;
        uint256 coolDownInstant;
    }

    uint256 lastUpdatedBlockNumber;//stores the last blocknumber upto which the rewards are reflected in the totalDeposits
    uint256 startBlockNumber;//Initial starting block number from which the first deposit happens in contract
    uint256 totalDeposits;//Total zamp tokens deposits  in the contract with rewards added upto lastUpdatedBlockNumber
    IERC20 public zampToken;//The erc20 Zamp token
    mapping(address => ClaimReceipt) Receipts;

    constructor(address tokenAddress) ERC20("ZampStakeTokens","stkZamp"){
        zampToken = IERC20(tokenAddress);
    }


    /* ========== NON MUTATIVE FUNCTIONS ========== */

    function getRate() 
    public
    override
    view	
    returns (uint256 rate){
        // console.log("The current block number is %s",block.number);
        // console.log("the last updated block number is %s",lastUpdatedBlockNumber);
        // console.log("the total supply of stake tokens here is %s",totalSupply());
        // console.log("The zamp token deposit is %s",totalDeposits);
        if (totalSupply() == 0 || lastUpdatedBlockNumber == 0){//initially when no deposit is there or when all the tokens are taken out
            // console.log("Current rate is 1");
            return 1e18;//1 stkZamp Token is equal to 1 Zamp token
        }else{
            // console.log("hey from here");
            rate = (totalDeposits + (block.number - lastUpdatedBlockNumber)*1e18)*1e18/totalSupply();//muliplication by 1e18 is done to handle decimal points accurately
            // console.log("Current rate is %s",rate);
            return rate;// (Total Zamp Tokens / Total stkZamp tokens) -> gives value of how many zamp tokens are equal to 1 stkZamp token
        }
        
    }


    function getTotalDeposit() 
    external 
    override
    view 
    returns (uint256 totalDeposit){
        totalDeposit = totalDeposits - (lastUpdatedBlockNumber - startBlockNumber)*1e18;//this returns only the deposits in the totalDeposits which does not include the reward
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
   * @dev Deposits zamp tokens and mints equivalent stkZamp tokens
   * @param amountToDeposit uint256 Amount of zamp tokens to deposit
   * @return stakedTokenOut uint256 Amount of stkZamp tokens minted to msg.sender
   **/
    function deposit(uint256 amountToDeposit) external 
    override
    whenNotPaused
        returns (uint256 stakedTokenOut){
            require(amountToDeposit>0,"Not valid Zamp amount");
            uint256 lastBlockNumber = lastUpdatedBlockNumber;//for gas optimization
            uint256 currentBlockNumber = block.number;//for gas optimization
            zampToken.safeTransferFrom(msg.sender,address(this),amountToDeposit);
            if (lastBlockNumber == 0)//first deposit
            {
                lastBlockNumber = currentBlockNumber;
                startBlockNumber = currentBlockNumber;
            }

            stakedTokenOut = (amountToDeposit*1e18)/getRate();//getting the amount of stakeZamp tokens to be minted to depositer

            //Adding the deposited zamp amount to reflect in totalDeposits and also rewards to that point is reflected
            totalDeposits += (currentBlockNumber - lastBlockNumber)*1e18 + amountToDeposit;
            lastUpdatedBlockNumber = currentBlockNumber;//lastUpdatedBlockNumber updated here

            
            _mint(msg.sender,stakedTokenOut);

            //emit an event
            emit Deposited(msg.sender, amountToDeposit);
        }

    /**
   * @dev Redeems zamp tokens  equivalent to stkZamp tokens decided by the rate and puts it up on receipt which is claimable after the 1 hr cooldown
   * @param stakedTokenAmountToRedeem uint256 Amount of stkZamp tokens to burn
   * @return tokenAmountOut uint256 Amount of Zamp tokens put up for cooldown
   **/
    function redeem(uint256 stakedTokenAmountToRedeem)
    external
    override
    whenNotPaused
    returns (uint256 tokenAmountOut){
        
        require(stakedTokenAmountToRedeem>0,"Invalid Amount");
        require(balanceOf(msg.sender) >= stakedTokenAmountToRedeem,"not enough stkTokens to redeem");
        require(Receipts[msg.sender].zampAmount == 0,"First claim the already redeemed amount to redeem further");
        uint256 blockNumber = block.number;
        tokenAmountOut = (stakedTokenAmountToRedeem * getRate())/1e18;//getting the equivalent amount of zamp tokens that are equivalent to the stkZamp tokens submitted for burning

         //Subtracting the equivalent zamp amount to reflect in totalDeposits and also rewards to that point is reflected
        totalDeposits = totalDeposits - tokenAmountOut + (blockNumber - lastUpdatedBlockNumber)*1e18;
        lastUpdatedBlockNumber = blockNumber;

        //buring the stkZamp tokens
        _burn(msg.sender,stakedTokenAmountToRedeem);

        //instead of transferring the zampTokens immediately,setting up a payment receipt and setting cooldown period
        Receipts[msg.sender].zampAmount = tokenAmountOut;
        Receipts[msg.sender].coolDownInstant = block.timestamp + 3600;

        //emit an event
        emit Redeemed(msg.sender, stakedTokenAmountToRedeem);
    }

    /**
   * @dev For claiming the zamp tokens after 1 hour cooldown period
   * @return claimedTokenAmount uint256 Amount of Zamp tokens transferred 
   **/
    function claim() 
    external
    override 
    whenNotPaused
    returns (uint256 claimedTokenAmount){
        claimedTokenAmount = Receipts[msg.sender].zampAmount;
        require(claimedTokenAmount > 0,"No tokens redeemed for claiming");
        require(Receipts[msg.sender].coolDownInstant < block.timestamp,"An hour cooldown period not over");
        zampToken.safeTransfer(msg.sender,claimedTokenAmount);//executing the receipt details
        Receipts[msg.sender].zampAmount = 0;
        Receipts[msg.sender].coolDownInstant = 0;
        emit Claimed(msg.sender, claimedTokenAmount);
    }

    /* ========== SECURITY RELATED FUNCTIONS ========== */

    //To pause or unpause the contract in case of emergency
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }


    /* ========== EVENTS ========== */

    
    event Deposited(address indexed user, uint256 amountToDeposit);
    event Redeemed(address indexed user, uint256 stakedTokenAmountToRedeem);
    event Claimed(address indexed user, uint256 claimedTokenAmount);

}
