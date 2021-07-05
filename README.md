# Delegate.fi

# Overall Idea

Use credit delegation from Aave to maximized returns to users who has idle borrowable power and does not know what to do with it. We handle it smoothly!

# Contracts Architecture

🔏 Edit your smart contracts YourContract.sol in packages/hardhat/contracts

- `DelegateFund.sol` it is where the protocol fee revenue would be sent (should be multisig by all devs), it should not be much complex likely some withdrawal process with X days of timelock will work and another method for cancelling the process of withdrawal if some dev member disagree on the action and some events to track off-chain how much has been withdrawed and where. I think it should be sufficient.

- `DelegatedCreditManager.sol` basically will be the direct contact point between the users and the protocol, where they can assign the borrowing power to (amount agreed), and it will play the role of deploying the capital elsewhere. Basically the options of how much they can delegate would be done via f/e, nothing to worry about at the smart contract level.

- `Strategy.sol` Strategy contract it will be where initially the capital will be deployed. As a target we can look into what the gitcoin described for their bounty. Link shared on the group.

- `DividenRightsToken.sol` DRT contract would be defined using different underlyings, most likely stablecoins, this contract would provide the tracking shares to the user delegating to the protocol credit. This shares would provide right to subcribe to the IDA to receive automatically the revenue from different strategies after harvest has been triggered.

- `RatingOracle.sol` The oracle will provide most recent credit details for the whitelisted address within our protocol. The data provide to each address would be rating, maxLoanAmount, profits, defaulted and initialised. It could be re-used by other protocols to consider the trustworthy of a specific address based on data on-chain.

- `DebtDerivative.sol` ERC1155 contract which will mint the specifications to the borrower depending on the type of uncollateralised loan, it will affect the borrower credit history recorded in the RatingOracle.sol depending if on each operation is defaulting or behaving accordangly. The whitelisted users most likely would be added via governance voting. Ideally this same ERC1155 could create a connection between delegators and borrowers, so the minted ERC1155 with its own specifications could behave as a cash flow or re-sell it on secondary market depending on RatingOracle data. Each ERC1155 could represent an intrinsic value.

---

# Quick Start

required: [Node](https://nodejs.org/dist/latest-v12.x/) plus [Yarn](https://classic.yarnpkg.com/en/docs/install/) and [Git](https://git-scm.com/downloads)

```bash
git clone https://github.com/petrovska-petro/delegate.fi

cd delegate.fi
```

```bash

yarn install

```

## Frontend

```bash

yarn start

```

📱 Open http://localhost:3000 to see the app

## Blockchain

Start an archival fork of mainnet.

```bash
cd delegate.fi
yarn fork

```

To pin a specific block

```
yarn fork --fork-block-number 12688335
```

Change the Alchemy API keys editing `fork` in `/packages/hardhat/package.json`

## Deploy

> in a third terminal window:

```bash
cd delegate.fi
yarn deploy

```

---

# More

📝 Edit your frontend `App.jsx` in `packages/react-app/src`

💼 Edit your deployment script `deploy.js` in `packages/hardhat/scripts`

📱 Open http://localhost:3000 to see the app

🔏 Edit the smart contracts `packages/hardhat/contracts`

✏️ Make small changes to the contracts in and watch the front end auto update the abi!

🔁 You can `yarn deploy` any time and get a fresh new contract in the frontend:

![deploy](https://user-images.githubusercontent.com/2653167/93149199-f8fa8280-f6b2-11ea-9da7-3b26413ec8ab.gif)

💵 Each browser has an account in the top right and you can use the faucet (bottom left) to get ⛽️ testnet eth for gas:

![faucet](https://user-images.githubusercontent.com/2653167/93150077-6c04f880-f6b5-11ea-9ee8-5c646b5b7afc.gif)

---

---

# 📡 Deploy

🛰 Ready to deploy to a testnet? Change the `defaultNetwork` in `packages/hardhat/hardhat.config.js`

🔐 Generate a deploy account with `yarn generate` and view it with `yarn account`

💵 Fund your deployer account (pro tip: use an [instant wallet](https://instantwallet.io) to send funds to the QR code from `yarn account`)

> Deploy your contract:

```bash
yarn deploy
```

---

---

# [Even More....](/FRONTEND_README)
