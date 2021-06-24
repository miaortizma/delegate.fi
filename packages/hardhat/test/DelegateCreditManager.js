const { ethers } = require("hardhat");
const { expect } = require("chai");

const DAI_WHALE = "0xeA78c186B28c5D75c64bb8eCdBdb38F357157C73";
const WHALE_DEPOSIT_AMOUNT = "500000";

let delegateCreditManager;
let strategy;
let daiToken;

// --- AAVE contracts ---
let lendingPool, dataProvider, debtToken;

let first_delegator, second_delegator, third_delegator;

// --- Polygon addresses ---
const addresses = {
  polygon: {
    erc20Tokens: {
      DAI: "0x8f3cf7ad23cd3cadbd9735aff958023239c6a063",
    },
    aave: {
      lendingPool: "0x8dff5e27ea6b7ac08ebfdf9eb090f32ee9a30fcf",
      dataProvider: "0x7551b5D2763519d4e37e8B81929D336De671d46d",
      debtToken: "0x75c4d1Fb84429023170086f06E682DcbBF537b7d"
    },
  },
  ethereum: {
    erc20Tokens: {
      DAI: "0x6b175474e89094c44da98b954eedeac495271d0f",
    },
    aave: {
      lendingPool: "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9",
      dataProvider: "0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d",
      debtToken: '0x6C3c78838c761c6Ac7bE9F59fe808ea2A6E4379d'
    },
  },
};

// can be also polygon, but cannot manage to plug the forking for polygon
const chain = "polygon";

before(async () => {
  [admin] = await ethers.getSigners();

  // Accounts with lots of DAI
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [DAI_WHALE],
  });
  first_delegator = ethers.provider.getSigner(DAI_WHALE);

  lendingPool = await ethers.getContractAt(
    "ILendingPool",
    addresses[chain].aave.lendingPool
  );
  dataProvider = await ethers.getContractAt(
    "IProtocolDataProvider",
    addresses[chain].aave.dataProvider
  );

  daiToken = await ethers.getContractAt(
    "TestErc20",
    addresses[chain].erc20Tokens.DAI
  );

  debtToken = await ethers.getContractAt(
    "IDebtToken",
    addresses[chain].aave.debtToken
  );

  const DelegateCreditManager = await ethers.getContractFactory(
    "DelegateCreditManager"
  );

  delegateCreditManager = await DelegateCreditManager.deploy(
    lendingPool.address,
    dataProvider.address
  );

  const Strategy = await ethers.getContractFactory("Strategy");

  strategy = await Strategy.deploy(
    [
      "0x0000000000000000000000000000000000000000", // temporarily 0x address for testing 
      addresses[chain].erc20Tokens.DAI,
      delegateCreditManager.address
    ],
    ethers.utils.parseEther("500000"), // we set 500k limit for testing
    ethers.utils.parseEther("0")
  );
});

describe("DelegateCreditManager", function () {

  it("Add strategy for DAI asset", async () => {
    console.log('Strategy deployed at address: ', strategy.address);
    await delegateCreditManager.setNewStrategy(
      addresses[chain].erc20Tokens.DAI,
      strategy.address
    );
  });

  it("Delegating credit - allowance in DelegateCreditManager & deposit in strategy", async () => {
    console.log(
      `Delegator (${DAI_WHALE}) Balance of DAI: `,
      ethers.utils.formatEther(
        await daiToken.balanceOf(DAI_WHALE)
      )
    );

    await daiToken
      .connect(first_delegator)
      .approve(lendingPool.address, ethers.utils.parseEther(WHALE_DEPOSIT_AMOUNT));

    expect(await daiToken.allowance(DAI_WHALE, lendingPool.address)).to.be.gte(
      ethers.utils.parseEther(WHALE_DEPOSIT_AMOUNT)
    );

    await lendingPool
      .connect(first_delegator)
      .deposit(
        addresses[chain].erc20Tokens.DAI,
        ethers.utils.parseEther(WHALE_DEPOSIT_AMOUNT),
        DAI_WHALE,
        0
      );

    const delegatorAaveData = await lendingPool.getUserAccountData(DAI_WHALE);

    // Check that collateral has been deposited succesfully
    expect(delegatorAaveData.totalCollateralETH).to.be.gt(
      ethers.utils.parseEther("200")
    );

    const reserveData = await dataProvider.getReserveTokensAddresses(
      addresses[chain].erc20Tokens.DAI
    );

    console.log(
      "variableDebtTokenAddress: ",
      reserveData.variableDebtTokenAddress
    );

    await debtToken
      .connect(first_delegator)
      .approveDelegation(
        delegateCreditManager.address,
        ethers.utils.parseEther("10000")
      );

    // revert msg: '59' (Borrow allowance not enough), pendant to fix!
    await delegateCreditManager
      .connect(first_delegator)
      .delegateCreditLine(
        addresses[chain].erc20Tokens.DAI,
        ethers.utils.parseEther("10000")
      );

    // in theory after executing the above method, now it should exist debt
    const delegatorAaveDataPostDelegating = await lendingPool.getUserAccountData(DAI_WHALE);

    console.log(
      "Current debt: ",
      ethers.utils.formatEther(delegatorAaveDataPostDelegating.totalDebtETH)
    );

    expect(delegatorAaveDataPostDelegating.totalDebtETH).to.be.gt(
      ethers.utils.parseEther("3")
    );

    // should output 0, as we max out the allowance, by borrowing I guess via `approveDelegation`
    console.log(
      'DelegateCreditManager allowance: ',
      ethers.utils.formatEther(
        await debtToken.borrowAllowance(DAI_WHALE, delegateCreditManager.address)
      )
    );

    expect(await debtToken.borrowAllowance(DAI_WHALE, delegateCreditManager.address)).to.eq(0);

    console.log(
      `Amount delegated by ${DAI_WHALE} to manager: `,
      ethers.utils.formatEther(
        (await delegateCreditManager.delegators(DAI_WHALE)).amountDelegated
      )
    );

    expect(await daiToken.balanceOf(strategy.address)).to.eq(ethers.utils.parseEther("10000"));
  });


  it("Delegating credit - stop allowance & withdraw from strategy", async () => {
    await delegateCreditManager
      .connect(first_delegator)
      .delegateCreditLine(
        addresses[chain].erc20Tokens.DAI,
        ethers.utils.parseEther("0")
      );

    expect(await daiToken.balanceOf(strategy.address)).to.eq(ethers.utils.parseEther("0"));
    expect(await debtToken.borrowAllowance(DAI_WHALE, delegateCreditManager.address)).to.eq(0);

    const delegatorAaveDataPostUnwinding = await lendingPool.getUserAccountData(DAI_WHALE);

    // it should leave some dust, i.e, minimal interest
    console.log(
      "Current debt post unwinding: ",
      ethers.utils.formatEther(delegatorAaveDataPostUnwinding.totalDebtETH)
    );

    expect(delegatorAaveDataPostUnwinding.totalDebtETH).to.be.lt(
      ethers.utils.parseEther("0.000001")
    );
  });
});
