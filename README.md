# Liquidity Staking Contract

A [simple staking contract](https://github.com/davidmitesh/Zampfi-staking-contract/blob/main/contracts/LiquidityStakingContract.sol) that is intended to incentivize the investors to hold the ERC20 tokens by providing them interest rate(reward) based on the amount of stake they put in the contract.

An upgradeable version of this contract is found [here](https://github.com/davidmitesh/Zampfi-staking-contract/blob/upgradable-staking-contract/contracts/UpgradableLiquidityStakingContract.sol)

## Features

- Staking contract can be implemented for any ERC20 token(mostly done for new tokens to increase its holding and sales)
- Upon staking tokens,LP tokens are issued to staker, which opens new world of Defi possibilities
- Rewards are minted per blocks and distributed in accordance to the amount of LP tokens a staker holds
- No loopings are used, and functions are kept as simple as possible to make the functions gas efficient
- safeERC20 is utilized which reverts in case of failure
- In between the redeeming and claiming phase, an hour cooldown period is added
- Gas profiler added to view the gas cost of each function
- A succinct test is written which is available [here](https://github.com/davidmitesh/Zampfi-staking-contract/blob/main/test/liquidity-staking-test.js)
- Upgradeable version of contract is also available


## Try on your own

```shell
git clone https://github.com/davidmitesh/Zampfi-staking-contract.git
npm install
npx hardhat compile
npx hardhat test
```

##

