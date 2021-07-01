const { ethers } = require("hardhat");
const { expect } = require("chai");
const SuperfluidSDK = require("@superfluid-finance/js-sdk");

const DAI_WHALE = "0x00000035bB78d26D67f9246350ACaEc232cAb3E3";
const WHALE_DEPOSIT_AMOUNT = "500000";
const DELEGATE_AMOUNTS = ["50000", "100000", "200000"];

const DELAY_ONE_DAY = 86400;
const YEAR_BLOCKS = 2300000;
const DAYS_ITERATION = 1;

let delegateCreditManager;
let delegateFund;
let strategy;
let daiToken, wmaticToken, crvToken, daix;

// --- AAVE contracts ---
let lendingPool, dataProvider, debtToken;

let first_delegator, second_delegator, third_delegator;

const addresses = {
  polygon: {
    erc20Tokens: {
      DAI: "0x8f3cf7ad23cd3cadbd9735aff958023239c6a063",
      WMATIC: "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270",
      CRV: "0x172370d5Cd63279eFa6d502DAB29171933a610AF",
    },
    aave: {
      lendingPool: "0x8dff5e27ea6b7ac08ebfdf9eb090f32ee9a30fcf",
      dataProvider: "0x7551b5D2763519d4e37e8B81929D336De671d46d",
      debtToken: "0x75c4d1Fb84429023170086f06E682DcbBF537b7d",
    },
  },
  ethereum: {
    erc20Tokens: {
      DAI: "0x6b175474e89094c44da98b954eedeac495271d0f",
    },
    aave: {
      lendingPool: "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9",
      dataProvider: "0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d",
      debtToken: "0x6C3c78838c761c6Ac7bE9F59fe808ea2A6E4379d",
    },
  },
};

const chain = "polygon";

before(async () => {
  [admin] = await ethers.getSigners();

  sf = new SuperfluidSDK.Framework({
    ethers: ethers.provider,
    resolverAddress: "0xE0cc76334405EE8b39213E620587d815967af39C",
    tokens: ["DAI"],
  });
  await sf.initialize();

  daix = sf.tokens.DAIx;

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

  wmaticToken = await ethers.getContractAt(
    "TestErc20",
    addresses[chain].erc20Tokens.WMATIC
  );

  crvToken = await ethers.getContractAt(
    "TestErc20",
    addresses[chain].erc20Tokens.CRV
  );

  debtToken = await ethers.getContractAt(
    "IDebtToken",
    addresses[chain].aave.debtToken
  );

  const DRTFactory = await ethers.getContractFactory("DividendRightsToken");

  const drtArgs = [
    "Dividend Rights Token",
    "DRT",
    sf.tokens.DAIx.address,
    sf.host.address,
    sf.agreements.ida.address,
  ];
  drt = await DRTFactory.deploy(...drtArgs);

  const DelegateCreditManager = await ethers.getContractFactory(
    "DelegateCreditManager"
  );

  delegateCreditManager = await DelegateCreditManager.deploy(
    lendingPool.address,
    dataProvider.address,
    drt.address
  );

  await drt.transferOwnership(delegateCreditManager.address);

  const DelegateFund = await ethers.getContractFactory("DelegateFund");

  delegateFund = await DelegateFund.deploy();

  const Strategy = await ethers.getContractFactory("Strategy");

  strategy = await Strategy.deploy(
    [
      delegateFund.address,
      addresses[chain].erc20Tokens.DAI,
      delegateCreditManager.address,
      drt.address
    ],
    ethers.utils.parseEther("500000") // Cap deposits up to 500k
  );
});

describe("DelegateCreditManager", function () {
  it("Add strategy for DAI asset", async () => {
    console.log("Strategy deployed at address: ", strategy.address);
    await delegateCreditManager.setNewStrategy(
      addresses[chain].erc20Tokens.DAI,
      strategy.address
    );
  });

  it(`Delegating credit - triggers delegateCreditLine & harvest after ${DELAY_ONE_DAY} secs`, async () => {
    console.log(
      `Delegator ${DAI_WHALE} Balance of DAI: `,
      ethers.utils.formatEther(await daiToken.balanceOf(DAI_WHALE))
    );

    await daiToken
      .connect(first_delegator)
      .approve(
        lendingPool.address,
        ethers.utils.parseEther(WHALE_DEPOSIT_AMOUNT)
      );

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

    console.log(
      `Collateral of  ${DAI_WHALE} in Aave: `,
      ethers.utils.formatEther(delegatorAaveData.totalCollateralETH)
    );

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
        ethers.utils.parseEther(DELEGATE_AMOUNTS[2])
      );

    await delegateCreditManager
      .connect(first_delegator)
      .delegateCreditLine(
        addresses[chain].erc20Tokens.DAI,
        ethers.utils.parseEther(DELEGATE_AMOUNTS[2])
      );

    // in theory after executing the above method, now it should exist debt
    const delegatorAaveDataPostDelegating = await lendingPool.getUserAccountData(
      DAI_WHALE
    );

    console.log(
      `Current delegators ${DAI_WHALE} debt: `,
      ethers.utils.formatEther(delegatorAaveDataPostDelegating.totalDebtETH)
    );

    expect(delegatorAaveDataPostDelegating.totalDebtETH).to.be.gt(
      ethers.utils.parseEther("3")
    );

    // should output 0, as we max out the allowance, by borrowing I guess via `approveDelegation`
    const currentBorrowAllowance = await debtToken.borrowAllowance(
      DAI_WHALE,
      delegateCreditManager.address
    );

    console.log(
      "DelegateCreditManager allowance: ",
      ethers.utils.formatEther(currentBorrowAllowance)
    );

    expect(currentBorrowAllowance).to.eq(0);

    const amountDelegated = await delegateCreditManager.delegators(
      DAI_WHALE,
      addresses[chain].erc20Tokens.DAI
    );

    console.log(
      `Amount delegated by ${DAI_WHALE} to manager: `,
      ethers.utils.formatEther(amountDelegated.amountDelegated)
    );

    const StrategyAaaveStatusAfterFirstDeposit = await lendingPool.getUserAccountData(
      strategy.address
    );

    console.log(
      "Current collateral deposited in Aave by the strategy: ",
      ethers.utils.formatEther(
        StrategyAaaveStatusAfterFirstDeposit.totalCollateralETH
      )
    );

    expect(StrategyAaaveStatusAfterFirstDeposit.totalCollateralETH).to.be.gt(3);

    const present = Math.floor(new Date().getTime() / 1000);

    for (let i = 0; i < DAYS_ITERATION; i++) {
      await ethers.provider.send("evm_setNextBlockTimestamp", [
        present + DELAY_ONE_DAY * (i + 1),
      ]);
      await ethers.provider.send("evm_mine", []);

      const totalAssets = await strategy.totalAssets();

      console.log(
        `After ${DELAY_ONE_DAY * (i + 1)} secs, the strategy at ${
          strategy.address
        } with a total AUM of ${ethers.utils.formatEther(
          totalAssets
        )} triggers HARVEST() iteration ${i + 1}...`
      );

      const txHarvest = await strategy.harvest();

      const receiptHarvest = await txHarvest.wait();

      const eventHarvestArgs = receiptHarvest.events?.filter((x) => {
        return x.event == "Harvest";
      })[0].args;

      console.log(
        `wantConverted: ${ethers.utils.formatEther(
          eventHarvestArgs.wantConverted
        )}`
      );
      console.log(
        `wmaticHarvested: ${ethers.utils.formatEther(
          eventHarvestArgs.wmaticHarvested
        )}`
      );
      console.log(
        `curveHarvested: ${ethers.utils.formatEther(
          eventHarvestArgs.curveHarvested
        )}`
      );

      const wmaticRevenue = await wmaticToken.balanceOf(delegateFund.address);
      console.log(
        `Revenue of WMATIC in DelegateFund after ${DELAY_ONE_DAY} secs: ${ethers.utils.formatEther(
          wmaticRevenue
        )}`
      );

      expect(wmaticRevenue).to.be.gt(ethers.utils.parseEther("0.1"));

      const crvRevenue = await crvToken.balanceOf(delegateFund.address);
      console.log(
        `Revenue of CRV in DelegateFund after ${DELAY_ONE_DAY} secs: ${ethers.utils.formatEther(
          crvRevenue
        )}`
      );

      expect(crvRevenue).to.be.gt(ethers.utils.parseEther("0.01"));
    }
    
    const DAIX_DRT_BALANCE = await daix.balanceOf(drt.address);

    console.log(`Current DAIx balance in DRT: ${ethers.utils.formatEther(DAIX_DRT_BALANCE)}`);

    expect(DAIX_DRT_BALANCE).to.be.gte(0);

    const aprox_day_blocks = 7200;

    const totalAssetsPostHarvest = await strategy.totalAssets();

    console.log(
      `totalAssetsPostHarvest: ${ethers.utils.formatEther(
        totalAssetsPostHarvest
      )}`
    );

    const apy =
      (totalAssetsPostHarvest / amountDelegated.amountDelegated) *
      (YEAR_BLOCKS / aprox_day_blocks);

    console.log(`Aprox APY: ${(apy / 100).toFixed(3)}%`);
  }).timeout(180000);

  it("Delegating credit - stop allowance & withdraw from strategy", async () => {
    await delegateCreditManager
      .connect(first_delegator)
      .freeDelegatedCapital(
        addresses[chain].erc20Tokens.DAI,
        ethers.utils.parseEther(DELEGATE_AMOUNTS[2])
      );

    expect(await daiToken.balanceOf(strategy.address)).to.eq(
      ethers.utils.parseEther("0")
    );

    await debtToken
      .connect(first_delegator)
      .approveDelegation(
        delegateCreditManager.address,
        ethers.utils.parseEther("0")
      );

    expect(
      await debtToken.borrowAllowance(DAI_WHALE, delegateCreditManager.address)
    ).to.eq(0);

    const delegatorAaveDataPostUnwinding = await lendingPool.getUserAccountData(
      DAI_WHALE
    );

    // it should leave some dust, i.e, minimal interest, depending on the size of delegator ofc
    console.log(
      `Current delegator ${DAI_WHALE} debt post -> unwinding action: `,
      ethers.utils.formatEther(delegatorAaveDataPostUnwinding.totalDebtETH)
    );

    expect(delegatorAaveDataPostUnwinding.totalDebtETH).to.be.lt(
      ethers.utils.parseEther("0.09")
    );

    const totalAssets = await strategy.totalAssets();

    console.log(
      `After withdrawing from strat amount delegated AUM ${ethers.utils.formatEther(
        totalAssets
      )}`
    );
  });

  xit("Delegating credit - deposit in Aave via our contract and delegate", async () => {
    await lendingPool
      .connect(first_delegator)
      .withdraw(
        addresses[chain].erc20Tokens.DAI,
        ethers.utils.parseEther(WHALE_DEPOSIT_AMOUNT),
        DAI_WHALE
      );

    const delegatorAaveData = await lendingPool.getUserAccountData(DAI_WHALE);

    expect(delegatorAaveData.totalCollateralETH).to.lt(
      ethers.utils.parseEther("0.1")
    );

    await daiToken
      .connect(first_delegator)
      .approve(
        delegateCreditManager.address,
        ethers.utils.parseEther(WHALE_DEPOSIT_AMOUNT)
      );

    await debtToken
      .connect(first_delegator)
      .approveDelegation(
        delegateCreditManager.address,
        ethers.utils.parseEther(DELEGATE_AMOUNTS[2])
      );

    await delegateCreditManager
      .connect(first_delegator)
      .depositAaveAndDelegate(
        addresses[chain].erc20Tokens.DAI,
        addresses[chain].erc20Tokens.DAI,
        ethers.utils.parseEther(WHALE_DEPOSIT_AMOUNT)
      );

    const delegatorAaveDataPostDeposit = await lendingPool.getUserAccountData(
      DAI_WHALE
    );

    console.log(
      `Current debt of ${DAI_WHALE} after interacting via -> depositAaveAndDelegate: `,
      ethers.utils.formatEther(delegatorAaveDataPostDeposit.totalDebtETH)
    );

    expect(delegatorAaveDataPostDeposit.totalDebtETH).to.be.gt(
      ethers.utils.parseEther("70")
    );
  });
});
