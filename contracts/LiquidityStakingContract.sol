// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IStakingContract.sol";


contract LiquidityStakingContract is IStakingContract,ERC20{
    using SafeERC20 for IERC20;
    using SafeERC20 for ERC20;

    struct ClaimReceipt{
        uint256 zampAmount;
        uint256 coolDownInstant;
    }

    uint256 lastUpdatedBlockNumber;
    uint256 startBlockNumber;
    uint256 totalDeposits;
    IERC20 public zampToken;
    mapping(address => ClaimReceipt) Receipts;

    constructor(address tokenAddress) ERC20("ZampStakeTokens","stkZamp"){
        zampToken = IERC20(tokenAddress);
    }

    function getRate() 
    public
    override
    view	
    returns (uint256 rate){
        if (totalSupply() == 0 || lastUpdatedBlockNumber == 0){
            rate = 1;//1 stkZamp Token is equal to 1 Zamp token
        }else{
            rate = (totalDeposits + (block.number - lastUpdatedBlockNumber))/totalSupply();
        }
    }

    function deposit(uint256 amountToDeposit) external
    override
        returns (uint256 stakedTokenOut){
            require(amountToDeposit>0,"Not valid Zamp amount");
            zampToken.safeTransferFrom(msg.sender,address(this),amountToDeposit);
            if (lastUpdatedBlockNumber == 0)//first deposit
            {
                lastUpdatedBlockNumber = block.number;
                startBlockNumber = block.number;
            }

            totalDeposits += (block.number - lastUpdatedBlockNumber) + amountToDeposit;
            lastUpdatedBlockNumber = block.number;
            stakedTokenOut = amountToDeposit/getRate();
            _mint(msg.sender,stakedTokenOut);

            //execute an event
        }

    
    function redeem(uint256 stakedTokenAmountToRedeem)
    external
    override
    returns (uint256 tokenAmountOut){
        require(stakedTokenAmountToRedeem>0,"Invalid Amount");
        require(balanceOf(msg.sender) >= stakedTokenAmountToRedeem,"not enough stkTokens to redeem");
        require(Receipts[msg.sender].zampAmount == 0,"First claim the already redeemed amount to redeem further");
        tokenAmountOut = stakedTokenAmountToRedeem * getRate();
        totalDeposits = totalDeposits - tokenAmountOut + (block.number - lastUpdatedBlockNumber);
        lastUpdatedBlockNumber = block.number;
        _burn(msg.sender,stakedTokenAmountToRedeem);
        Receipts[msg.sender].zampAmount = tokenAmountOut;
        Receipts[msg.sender].coolDownInstant = block.timestamp + 3600;

        //emit and event
    }


    

    function getTotalDeposit() 
    external 
    override
    view 
    returns (uint256 totalDeposit){
        totalDeposit = totalDeposits - (lastUpdatedBlockNumber - startBlockNumber);
    }

    function claim() 
    external
    override 
    returns (uint256 claimedTokenAmount){
        claimedTokenAmount = Receipts[msg.sender].zampAmount;
        require(claimedTokenAmount > 0,"No tokens redeemed for claiming");
        require(Receipts[msg.sender].coolDownInstant < block.timestamp,"An hour cooldown period not over");
        zampToken.safeTransfer(msg.sender,claimedTokenAmount);
        Receipts[msg.sender].zampAmount = 0;
        Receipts[msg.sender].coolDownInstant = 0;
    }

}
