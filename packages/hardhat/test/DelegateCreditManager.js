const { ethers } = require("hardhat");
const { expect } = require("chai");

const DAI_WHALE = "0x16463c0fdB6BA9618909F5b120ea1581618C1b9E";

let degateCreditManager;
let daiToken;

// --- AAVE contracts ---
let lendingPool, dataProvider;

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
    },
  },
  ethereum: {
    erc20Tokens: {
      DAI: "0x6b175474e89094c44da98b954eedeac495271d0f",
    },
    aave: {
      lendingPool: "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9",
      dataProvider: "0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d",
    },
  },
};

// can be also polygon, but cannot manage to plug the forking for polygon
const chain = "ethereum";

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

  const DelegateCreditManager = await ethers.getContractFactory(
    "DelegateCreditManager"
  );

  degateCreditManager = await DelegateCreditManager.deploy(
    lendingPool.address,
    dataProvider.address
  );
});

describe("DelegateCreditManager", function () {
  it("Delegating credit - allowance in DelegateCreditManager", async () => {
    console.log("Decimals of DAI, verify: ", await daiToken.decimals());
    console.log(
      "Delegator Balance of DAI: ",
      ethers.utils.formatEther(
        await daiToken.balanceOf("0x16463c0fdB6BA9618909F5b120ea1581618C1b9E")
      )
    );

    await daiToken
      .connect(first_delegator)
      .approve(lendingPool.address, ethers.utils.parseEther("500000"));

    await lendingPool
      .connect(first_delegator)
      .deposit(
        addresses[chain].erc20Tokens.DAI,
        ethers.utils.parseEther("500000"),
        DAI_WHALE,
        0
      );

    const delegatorAaveData = await lendingPool.getUserAccountData(DAI_WHALE);
    
    // at the moment should state roughly ~ 265ETH @1880
    console.log(ethers.utils.formatEther(delegatorAaveData.totalCollateralETH));
  });
});
