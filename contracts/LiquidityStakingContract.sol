// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IStakingContract.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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

    function deposit(uint256 amountToDeposit) external 
    override
    whenNotPaused
        returns (uint256 stakedTokenOut){
            require(amountToDeposit>0,"Not valid Zamp amount");
            zampToken.safeTransferFrom(msg.sender,address(this),amountToDeposit);
            if (lastUpdatedBlockNumber == 0)//first deposit
            {
                lastUpdatedBlockNumber = block.number;
                startBlockNumber = block.number;
            }

            stakedTokenOut = (amountToDeposit*1e18)/getRate();//getting the amount of stakeZamp tokens to be minted to depositer

            //Adding the deposited zamp amount to reflect in totalDeposits and also rewards to that point is reflected
            totalDeposits += (block.number - lastUpdatedBlockNumber)*1e18 + amountToDeposit;
            lastUpdatedBlockNumber = block.number;//lastUpdatedBlockNumber updated here

            
            _mint(msg.sender,stakedTokenOut);

            //emit an event
            emit Deposited(msg.sender, amountToDeposit);
        }

    
    function redeem(uint256 stakedTokenAmountToRedeem)
    external
    override
    whenNotPaused
    returns (uint256 tokenAmountOut){
        
        require(stakedTokenAmountToRedeem>0,"Invalid Amount");
        require(balanceOf(msg.sender) >= stakedTokenAmountToRedeem,"not enough stkTokens to redeem");
        require(Receipts[msg.sender].zampAmount == 0,"First claim the already redeemed amount to redeem further");

        tokenAmountOut = (stakedTokenAmountToRedeem * getRate())/1e18;//getting the equivalent amount of zamp tokens that are equivalent to the stkZamp tokens submitted for burning

         //Subtracting the equivalent zamp amount to reflect in totalDeposits and also rewards to that point is reflected
        totalDeposits = totalDeposits - tokenAmountOut + (block.number - lastUpdatedBlockNumber)*1e18;
        lastUpdatedBlockNumber = block.number;

        //buring the stkZamp tokens
        _burn(msg.sender,stakedTokenAmountToRedeem);

        //instead of transferring the zampTokens immediately,setting up a payment receipt and setting cooldown period
        Receipts[msg.sender].zampAmount = tokenAmountOut;
        Receipts[msg.sender].coolDownInstant = block.timestamp + 3600;

        //emit an event
        emit Redeemed(msg.sender, stakedTokenAmountToRedeem);
    }


    

    function getTotalDeposit() 
    external 
    override
    view 
    returns (uint256 totalDeposit){
        totalDeposit = totalDeposits - (lastUpdatedBlockNumber - startBlockNumber)*1e18;//this returns only the deposits in the totalDeposits which does not include the reward
    }

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
