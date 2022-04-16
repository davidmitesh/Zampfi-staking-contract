require("@nomiclabs/hardhat-waffle");
const { expect } = require("chai");
const hre = require("hardhat");
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
    let bob;//A general user Bob
    let ravi;//A genera user ravi
    let alice;//A general user Alice
    let zampToken;
    let stakingToken;


    before(async()=>{
        [zampTokenOwner,stakingTokenOwner,bob,alice,ravi] = await ethers.getSigners();
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
            expect(await stakingToken.getRate()).to.equal(toWei(1));
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

    describe("Checking the core functionalities",async()=>{
        it("Checking the deposit and redeem functionality",async()=>{
            //transferring the funds from the zampToken Contract to the staking contract
            //will be used to provide rewards per block
            await zampToken.connect(zampTokenOwner).transfer(stakingToken.address,toWei(1000));
            expect(await zampToken.balanceOf(stakingToken.address)).equal(toWei(1000));

            //transferring funds to bob and alice
            await zampToken.connect(zampTokenOwner).transfer(bob.address,toWei(100));
            await zampToken.connect(zampTokenOwner).transfer(alice.address,toWei(100));
            await zampToken.connect(zampTokenOwner).transfer(ravi.address,toWei(100));

            expect(await zampToken.balanceOf(bob.address)).equal(toWei(100));
            expect(await zampToken.balanceOf(alice.address)).equal(toWei(100));


            //making first deposit in the staking contract
            await zampToken.connect(bob).approve(stakingToken.address,toWei(10));

            await stakingToken.connect(bob).deposit(toWei(10));//in first deposit, as rate is 1:1
            expect(await stakingToken.getTotalDeposit()).equal(toWei(10));
            expect(await stakingToken.balanceOf(bob.address)).equal(toWei(10));

            
            // await hre.network.provider.send("hardhat_mine", ["0x100"]);

            //after 2 block rewards
            await zampToken.connect(alice).approve(stakingToken.address,toWei(10));
            await stakingToken.connect(alice).deposit(toWei(10));

            expect(fromWei(await stakingToken.getRate())).to.equal("1.2");
            // console.log(await stakingToken.totalSupply());

            //after 2 block rewards
            await zampToken.connect(ravi).approve(stakingToken.address,toWei(10));
            await stakingToken.connect(ravi).deposit(toWei(10));
            
            expect(fromWei(await stakingToken.getRate())).to.equal("1.30909090909090909");

            //checking the total zamp token balance of the staking token contract
            expect(await zampToken.balanceOf(stakingToken.address)).equal(toWei(1030));//1000 was originally minted to distribute as staking rewards per block and 30 from 3 different users

            //checking the redeem functionality
            expect(fromWei(await stakingToken.balanceOf(bob.address))).to.equal("10.0");//stkTokens possesed by bob - 10 stkTokens 
            expect(fromWei(await stakingToken.getRate())).to.equal('1.30909090909090909');//getting the current rate - 1.309
            await stakingToken.connect(bob).redeem(toWei(10));

            //because redeem only burns the stkTokens and issues a receipt with cooldown period of 1 hour
            expect(fromWei(await zampToken.balanceOf(bob.address))).to.equal("90.0");

            //stkTokens should be 0 for bob because it is burned by calling redeem
            expect(fromWei(await stakingToken.balanceOf(bob.address))).to.equal("0.0");

            //checking the claiming functionality

            await expect(stakingToken.connect(bob).claim()).to.be.revertedWith('An hour cooldown period not over');

            // mine 1000 blocks with an interval of 1 minute means 1000 minutes
            await hre.network.provider.send("hardhat_mine", ["0x3e8", "0x3c"]);

            //Now the 1 hour cooldown period has already passed and we should be able to claim zamp tokens
            await stakingToken.connect(bob).claim();

            //Checking if the rewards of about 13 zampTokens is added or not
           expect(Number(fromWei(await zampToken.balanceOf(bob.address)))).greaterThan(103);
            
        })


        it("Should check the pausable and ownable functionality",async()=>{
            //checking the owner of staking contract
            expect(await stakingToken.owner()).equal(stakingTokenOwner.address);

            //The contract should be in unpaused state initially
            expect(await stakingToken.paused()).equal(false);

            //Should throw an error if user other than owner tries to pause
            await expect(stakingToken.connect(bob).pause()).to.be.revertedWith('Ownable: caller is not the owner');
            await expect(stakingToken.connect(alice).pause()).to.be.revertedWith('Ownable: caller is not the owner');
            
            //Pausing the contract using the owner
            await stakingToken.connect(stakingTokenOwner).pause();
            expect(await stakingToken.paused()).equal(true);

        })

        
    })

  
});