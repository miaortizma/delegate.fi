const { ethers } = require("hardhat");
const { expect } = require("chai");

const DAI_WHALE = "0x16463c0fdB6BA9618909F5b120ea1581618C1b9E";

let daiToken;
let delegateFund;
let whale;

const DELAY_PLUS_TINY_TIME = 2 * 24 * 3600 + 20;

before(async () => {
  [admin] = await ethers.getSigners();

  // Accounts with lots of DAI
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [DAI_WHALE],
  });
  whale = ethers.provider.getSigner(DAI_WHALE);

  daiToken = await ethers.getContractAt(
    "TestErc20",
    "0x6b175474e89094c44da98b954eedeac495271d0f"
  );
});

describe("DelegateFund", function () {
  beforeEach(async () => {
    const DelegateFund = await ethers.getContractFactory("DelegateFund");
    delegateFund = await DelegateFund.deploy();
  });

  it("Withdrawal - check timelock logic", async () => {
    // whale sends to the DelegateFund a bit of funds for testing
    await daiToken
      .connect(whale)
      .transfer(delegateFund.address, ethers.utils.parseEther("5000"));

    expect(await daiToken.balanceOf(delegateFund.address)).to.eq(
      ethers.utils.parseEther("5000")
    );

    await expect(delegateFund.withdraw(daiToken.address)).to.be.revertedWith(
      "destination!"
    );

    await delegateFund.withdrawInit(
      admin.address,
      ethers.utils.parseEther("1500")
    );

    await expect(delegateFund.withdraw(daiToken.address)).to.be.revertedWith(
      "locked!"
    );

    const present = Math.floor(new Date().getTime() / 1000);

    // Moving forward on time for the 2 days delay + a bit of time, so it is not reverted
    await ethers.provider.send("evm_setNextBlockTimestamp", [
      present + DELAY_PLUS_TINY_TIME,
    ]);
    await ethers.provider.send("evm_mine", []);

    await delegateFund.withdraw(daiToken.address);

    expect(await daiToken.balanceOf(admin.address)).to.eq(
      ethers.utils.parseEther("1500")
    );
    expect(await daiToken.balanceOf(delegateFund.address)).to.eq(
      ethers.utils.parseEther("3500")
    );

    await expect(delegateFund.withdraw(daiToken.address)).to.be.revertedWith(
      "destination!"
    );
  });
});