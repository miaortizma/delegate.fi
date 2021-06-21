const { ethers } = require("hardhat");
const { expect } = require("chai");

let testToken;
let degateFund;

const DELAY_PLUS_TINY_TIME =  2 * 24 * 3600 + 20

describe("DelegateFund", function () {
    beforeEach(async () => {
        [admin] = await ethers.getSigners();
        
        const TestToken = await ethers.getContractFactory("TestErc20");
        testToken = await TestToken.deploy(18); // for testing we keep 18 decimals

        const DelegateFund = await ethers.getContractFactory("DelegateFund");
        degateFund = await DelegateFund.deploy();
        
        // mint some to ourselves
        await testToken.mint(degateFund.address, ethers.utils.parseEther('5000'));
    });

    it('Withdrawal - check timelock logic', async () => {
      expect(await testToken.balanceOf(degateFund.address)).to.eq(ethers.utils.parseEther('5000'));

      await expect(degateFund.withdraw(testToken.address)).to.be.revertedWith(
        'destination!',
      );

      await degateFund.withdrawInit(admin.address, ethers.utils.parseEther('1500'));

      await expect(degateFund.withdraw(testToken.address)).to.be.revertedWith(
        'locked!',
      );
      
      const present = Math.floor(new Date().getTime() / 1000);
      
      // Moving forward on time for the 2 days delay + a bit of time, so it is not reverted
      await ethers.provider.send('evm_setNextBlockTimestamp', [present + DELAY_PLUS_TINY_TIME]);
      await ethers.provider.send('evm_mine', []);
      
      await degateFund.withdraw(testToken.address);

      expect(await testToken.balanceOf(admin.address)).to.eq(ethers.utils.parseEther('1500'));
      expect(await testToken.balanceOf(degateFund.address)).to.eq(ethers.utils.parseEther('3500'));

      await expect(degateFund.withdraw(testToken.address)).to.be.revertedWith(
        'destination!!',
      );
    });
});