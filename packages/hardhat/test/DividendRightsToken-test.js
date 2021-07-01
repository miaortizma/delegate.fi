const { ethers } = require("hardhat");
const { expect } = require("chai");
const SuperfluidSDK = require("@superfluid-finance/js-sdk");

const DAI_WHALE = "0x00000035bB78d26D67f9246350ACaEc232cAb3E3";
const WHALE_DEPOSIT_AMOUNT = "500000";
const DELEGATE_AMOUNTS = ["50000", "100000", "200000"];

const DELAY_ONE_DAY = 86400;
const YEAR_BLOCKS = 2300000;

let sf;
let owner;
let addr1;
let addr2;
let addrs;
let daix;
let drt;
let distributorRole;
let adminRole;

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
  daix = sf.tokens.DAIx;
  dai = sf.tokens.DAI;

  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [DAI_WHALE],
  });
  first_delegator = ethers.provider.getSigner(DAI_WHALE);

  const DRTFactory = await ethers.getContractFactory("DividendRightsToken");
  //daix = await ethers.getContractAt("ISuperToken", sf.tokens.DAIx.address);

  const drtArgs = [
    "Dividend Rights Token",
    "DRT",
    sf.tokens.DAIx.address,
    sf.host.address,
    sf.agreements.ida.address,
  ];
  drt = await DRTFactory.deploy(...drtArgs);
  distributorRole = await drt.DISTRIBUTOR_ROLE();
  adminRole = await drt.DEFAULT_ADMIN_ROLE();
});

describe("Deployment", function () {
  it("Should set the right owner and have initial supply of 0", async () => {
    expect(await drt.hasRole(adminRole, owner.address));
    expect(await drt.totalSupply()).to.equal(0);
  });
});

describe("Transactions", function () {
  it("Should revert without approval", async () => {
    await expect(daix.connect(first_delegator).upgrade(100)).to.be.reverted;
  });
  it("Should upgrade DAI to DAIx", async () => {
    //const bob = sf.user({ address: DAI_WHALE, token: daix.address });
    await dai
      .connect(first_delegator)
      .approve(daix.address, "1" + "0".repeat(42));
    expect(await daix.balanceOf(first_delegator._address)).to.be.eq(0);
    await daix.connect(first_delegator).upgrade(100);
    expect(await daix.balanceOf(first_delegator._address)).to.be.eq(100);
  });
  it("Issue DRT tokens", async () => {
    // Issue DRT tokens
    expect(await drt.totalSupply()).to.equal(0);
    expect(await drt.balanceOf(addr1.address)).to.eq(0);
    expect(await drt.balanceOf(addr2.address)).to.eq(0);

    await drt.issue(addr1.address, 50);
    await drt.issue(addr2.address, 50);
    expect(await drt.totalSupply()).to.equal(100);

    await drt.burn(addr1.address, 50);
    await drt.burn(addr2.address, 50);

    expect(await drt.totalSupply()).to.equal(0);
    expect(await drt.balanceOf(addr1.address)).to.eq(0);
    expect(await drt.balanceOf(addr1.address)).to.eq(0);
  });

  it("Should distribute cash token", async () => {
    // give DAI to owner
    // note: first_delegator address is accessed as _address, not address
    await dai
      .connect(first_delegator)
      .approve(owner.address, "1" + "0".repeat(42));
    await dai.connect(first_delegator).transfer(owner.address, 2000);

    // owner approves and upgrades DAI to DAIx, also approves drt contract.
    await dai.approve(daix.address, "1" + "0".repeat(42));
    await daix.upgrade(2000);

    // issue DRT and update distribution

    await drt.issue(addr1.address, 50);
    await drt.issue(addr2.address, 50);

    await sf.host.connect(addr1).callAgreement(
      sf.agreements.ida.address,
      sf.agreements.ida.contract.methods
        .approveSubscription(daix.address, drt.address, 0, "0x")
        .encodeABI(),
      "0x" // user data
    );
    await sf.host.connect(addr2).callAgreement(
      sf.agreements.ida.address,
      sf.agreements.ida.contract.methods
        .approveSubscription(daix.address, drt.address, 0, "0x")
        .encodeABI(),
      "0x" // user data
    );

    // approve allowance of DAIx and distribute
    await daix.approve(drt.address, "1" + "0".repeat(42));
    await drt.grantRole(distributorRole, owner.address);
    await drt.distribute(1000);

    expect(await daix.balanceOf(addr1.address)).to.be.eq(500);
    expect(await daix.balanceOf(addr2.address)).to.be.eq(500);

    await drt.burn(addr2.address, 50);
    await drt.distribute(1000);

    expect(await daix.balanceOf(addr1.address)).to.be.eq(1500);
    expect(await daix.balanceOf(addr2.address)).to.be.eq(500);
  });

  it("Should distribute with a transferred ownership", async () => {
    await drt.transferOwnership(first_delegator._address);
    expect(await daix.balanceOf(first_delegator._address)).to.be.eq(100);

    await daix
      .connect(first_delegator)
      .approve(drt.address, "1" + "0".repeat(42));
    await drt
      .connect(first_delegator)
      .grantRole(distributorRole, first_delegator._address);
    await drt.connect(first_delegator).distribute(100);

    expect(await daix.balanceOf(first_delegator._address)).to.be.eq(0);
    expect(await daix.balanceOf(addr1.address)).to.be.eq(1600);
  });
  it("Should transfer ownership to contract", async () => {
    let lendingPool = await ethers.getContractAt(
      "ILendingPool",
      addresses[chain].aave.lendingPool
    );
    let dataProvider = await ethers.getContractAt(
      "IProtocolDataProvider",
      addresses[chain].aave.dataProvider
    );

    const DelegateCreditManager = await ethers.getContractFactory(
      "DelegateCreditManager"
    );

    let delegateCreditManager = await DelegateCreditManager.deploy(
      lendingPool.address,
      dataProvider.address,
      drt.address
    );
    await drt
      .connect(first_delegator)
      .transferOwnership(delegateCreditManager.address);
  });
});
