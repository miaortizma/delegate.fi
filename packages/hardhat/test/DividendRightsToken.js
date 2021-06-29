const { ethers } = require("hardhat");
const { expect } = require("chai");
const SuperfluidSDK = require("@superfluid-finance/js-sdk");

const DAI_WHALE = "0x00000035bB78d26D67f9246350ACaEc232cAb3E3";
const WHALE_DEPOSIT_AMOUNT = "500000";
const DELEGATE_AMOUNTS = ["50000", "100000", "200000"];

const DELAY_ONE_DAY = 86400;
const YEAR_BLOCKS = 2300000;

let delegateCreditManager;
let delegateFund;
let strategy;
let daiToken, wmaticToken, crvToken;

let sf;
let owner;
let addr1;
let addr2;
let addrs;
let daix;
let drt;

// --- AAVE contracts ---
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
  [owner, addr1, addr2, addrs] = await ethers.getSigners();

  sf = new SuperfluidSDK.Framework({
    ethers: ethers.provider,
    resolverAddress: "0xE0cc76334405EE8b39213E620587d815967af39C",
    tokens: ["DAI"],
  });
  await sf.initialize();

  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [DAI_WHALE],
  });
  first_delegator = ethers.provider.getSigner(DAI_WHALE);

  daiToken = await ethers.getContractAt(
    "TestErc20",
    addresses[chain].erc20Tokens.DAI
  );

  //daiX = await ethers.getContractAt()

  wmaticToken = await ethers.getContractAt(
    "TestErc20",
    addresses[chain].erc20Tokens.WMATIC
  );

  const DRT = await ethers.getContractFactory("DividendRightsToken");

  daix = await ethers.getContractAt("ISuperToken", sf.tokens.DAIx.address);

  const drtArgs = [
    "Dividend Rights Token",
    "DRT",
    sf.tokens.DAIx.address,
    sf.host.address,
    sf.agreements.ida.address,
  ];
  drt = await DRT.deploy(...drtArgs);
});

describe("Deployment", function () {
  it("Should set the right owner and have initial supply of 0", async () => {
    expect(await drt.owner()).to.equal(owner.address);
    expect(await drt.totalSupply()).to.equal(0);
  });
});

describe("Transactions", function () {
  it("Should upgrade DAI to DAIx", async () => {
    let daix = sf.tokens.DAIx;
    let dai = sf.tokens.DAI;

    //const bob = sf.user({ address: DAI_WHALE, token: daix.address });
    await dai
      .connect(first_delegator)
      .approve(daix.address, "1" + "0".repeat(42));
    await daix.connect(first_delegator).upgrade(100);
    expect(await daix.balanceOf(first_delegator._address)).to.be.gt(0);
  });
  it("Issue DRT tokens", async () => {
    console.log("DRT deployed at address: ", drt.address);
    expect(await drt.balanceOf(addr1.address)).to.eq(0);
    drt.issue(addr1.address, 50);
    drt.issue(addr2.address, 50);
    expect(await drt.totalSupply()).to.equal(100);
  });
});
