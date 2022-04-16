require("@nomiclabs/hardhat-waffle");
const { expect } = require("chai");
// const { ethers } = require("hardhat");
const toWei = (value) => ethers.utils.parseEther(value.toString());

const fromWei = (value) =>
  ethers.utils.formatEther(
    typeof value === "string" ? value : value.toString()
  );

const getBalance = ethers.provider.getBalance;
describe("Liquidity staking contract", function () {

    let zampTokenOwner;//one who deploys the tokenContract
    let stakingTokenOwner;//one who deploys the staking contract
    let user1;//A general user Bob
    let user2;//A general user Alice
    let zampToken;
    let stakingToken;


    before(async()=>{
        [zampTokenOwner,stakingTokenOwner] = await ethers.getSigners();
        const Token = await ethers.getContractFactory("ZampToken");
        zampToken = await Token.deploy("ZampToken", "ZMPTKN", toWei(1000000));
        await zampToken.deployed();
    })

    beforeEach(async()=>{

        const stakingContract = await ethers.getContractFactory("LiquidityStakingContract");
        stakingToken = await stakingContract.connect(stakingTokenOwner).deploy(zampToken.address);
        await stakingToken.deployed();
    })

    describe("Checking the details of the deployed contracts",async function(){
        it("Should returns the details of the deployed zamp token", async function () {
            expect(await zampToken.name()).to.equal("ZampToken");
            expect(await zampToken.symbol()).to.equal("ZMPTKN");
            expect(await zampToken.totalSupply()).to.equal(toWei(1000000));
            expect(await zampToken.balanceOf(zampTokenOwner.address)).to.equal(toWei(1000000));
          });
        
          it("should check the deployment of the staking contract",async function(){
            expect(await stakingToken.zampToken()).to.equal(zampToken.address);
          })
    })

    describe("Checking the initial values of Staking contract",async()=>{
        it("initial rate should be 1",async()=>{
            expect(await stakingToken.getRate()).to.equal(1);
        })
        it("initial deposits value should be 0",async()=>{
           expect(await stakingToken.getTotalDeposit()).to.equal(0);
        })
        it("claim function should return error",async()=>{
           await  expect(stakingToken.claim()).to.be.revertedWith('No tokens redeemed for claiming');
        })

        it("Redeem function should return error",async()=>{
            await  expect(stakingToken.redeem(toWei(10))).to.be.revertedWith('not enough stkTokens to redeem');
         })
    })

  
});