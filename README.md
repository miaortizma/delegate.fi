# Delegate.fi

## Overall Idea

Use credit delegation from Aave to maximized returns to users who has idle borrowable power and does not know what to do with it. We handle it smoothly!

# Contracts Architecture

🔏 Edit your smart contracts YourContract.sol in packages/hardhat/contracts

- `DelegateFund.sol` it is where the protocol fee revenue would be sent (should be multisig by all devs), it should not be much complex likely some withdrawal process with X days of timelock will work and another method for cancelling the process of withdrawal if some dev member disagree on the action and some events to track off-chain how much has been withdrawed and where. I think it should be sufficient.

- `DelegatedCreditManager.sol` basically will be the direct contact point between the users and the protocol, where they can assign the borrowing power to (amount agreed), and it will play the role of deploying the capital elsewhere. Basically the options of how much they can delegate would be done via f/e, nothing to worry about at the smart contract level.

- `Strategy.sol` Strategy contract it will be where initially the capital will be deployed. As a target we can look into what the gitcoin described for their bounty. Link shared on the group.

- `UserReturns.sol` Tracking User Returns contract maybe here could be sent the returns from the strategy contract and pull out using the Superfluid stream feature somehow directly into the users wallet upon certain condition that makes economical sense. The users are going to be tracked via a mapping type variable within the Delegated Credit Manager, which could be a point to a struct, so it can be given on a pro-rata manner. Otherwise, it will need to be claimable from here.

- `Karma.sol` Dashboard for outsider borrowers contract @ElocRemarc is very much interested in this front. Feel free to dive deeper.

---

---

# Front End

## 🏃‍♀️ Scafold ETH Quick Start

---

required: [Node](https://nodejs.org/dist/latest-v12.x/) plus [Yarn](https://classic.yarnpkg.com/en/docs/install/) and [Git](https://git-scm.com/downloads)

```bash
git clone https://github.com/petrovska-petro/delegate.fi

cd delegate.fi
```

```bash

yarn install

```

```bash

yarn start

```

> in a second terminal window:

```bash
cd delegate.fi
yarn chain

```

> in a third terminal window:

```bash
cd delegate.fi
yarn deploy

```

🔏 Edit your smart contracts `YourContract.sol` in `packages/hardhat/contracts`

📝 Edit your frontend `App.jsx` in `packages/react-app/src`

💼 Edit your deployment script `deploy.js` in `packages/hardhat/scripts`

📱 Open http://localhost:3000 to see the app

✏️ Make small changes to `YourContract.sol` and watch your app auto update!

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

# 📺 Frontend

> Edit your frontend `App.jsx` in `packages/react-app/src`

📡 Make sure your `targetNetwork` is the same as 👷‍♀️ HardHat's `defaultNetwork` (where you deployed your contracts).

![image](https://user-images.githubusercontent.com/2653167/110500412-68778a80-80b6-11eb-91bd-194d47d62771.png)

🤡 Adjust your debugging settings as needed:

![image](https://user-images.githubusercontent.com/2653167/110499550-95776d80-80b5-11eb-8024-287878b180d5.png)

---

## 🔏 Providers:

Providers are your connections to different blockchains.

The frontend has three different providers that provide different levels of access to different chains:

`mainnetProvider`: (read only) [Alchemy](https://alchemyapi.io/) or [Infura](https://infura.io/) connection to main [Ethereum](https://ethereum.org/developers/) network (and contracts already deployed like [DAI](https://etherscan.io/address/0x6b175474e89094c44da98b954eedeac495271d0f#code) or [Uniswap](https://etherscan.io/address/0x2a1530c4c41db0b0b2bb646cb5eb1a67b7158667)).

`localProvider`: local [HardHat](https://hardhat.org) accounts, used to read from _your_ contracts (`.env` file points you at testnet or mainnet)

`injectedProvider`: your personal [MetaMask](https://metamask.io/download.html), [WalletConnect](https://walletconnect.org/apps) via [Argent](https://www.argent.xyz/), or other injected wallet (generates [burner-provider](https://www.npmjs.com/package/burner-provider) on page load)

![image](https://user-images.githubusercontent.com/2653167/110499705-bc35a400-80b5-11eb-826d-44815b89296c.png)

---

## 🖇 Hooks:

![image](https://user-images.githubusercontent.com/2653167/110499834-dcfdf980-80b5-11eb-9d2d-de7046bf5c2b.png)

Commonly used Ethereum hooks located in `packages/react-app/src/`:

`usePoller(fn, delay)`: runs a function on app load and then on a custom interval

```jsx
usePoller(() => {
  //do something cool at start and then every three seconds
}, 3000);
```

<br/>

`useBalance(address, provider, [pollTime])`: poll for the balance of an address from a provider

```js
const localBalance = useBalance(address, localProvider);
```

<br/>

`useBlockNumber(provider,[pollTime])`: get current block number from a provider

```js
const blockNumber = useBlockNumber(props.provider);
```

<br/>

`useGasPrice([speed])`: gets current "fast" price from [ethgasstation](https://ethgasstation.info)

```js
const gasPrice = useGasPrice();
```

<br/>

`useExchangePrice(mainnetProvider, [pollTime])`: gets current price of Ethereum on the Uniswap exchange

```js
const price = useExchangePrice(mainnetProvider);
```

<br/>

`useContractLoader(provider)`: loads your smart contract interface

```js
const readContracts = useContractLoader(localProvider);
const writeContracts = useContractLoader(injectedProvider);
```

<br/>

`useContractReader(contracts, contractName, variableName, [pollTime])`: reads a variable from your contract and keeps it in the state

```js
const title = useContractReader(props.readContracts, contractName, "title");
const owner = useContractReader(props.readContracts, contractName, "owner");
```

<br/>

`useEventListener(contracts, contractName, eventName, [provider], [startBlock])`: listens for events from a smart contract and keeps them in the state

```js
const ownerUpdates = useEventListener(
  readContracts,
  contractName,
  "UpdateOwner",
  props.localProvider,
  1
);
```

---

## 📦 Components:

![image](https://user-images.githubusercontent.com/2653167/110500019-04ed5d00-80b6-11eb-97a4-74068fa90846.png)

Your commonly used React Ethereum components located in `packages/react-app/src/`:

<br/>

📬 `<Address />`: A simple display for an Ethereum address that uses a [Blockie](https://www.npmjs.com/package/ethereum-blockies), lets you copy, and links to [Etherescan](https://etherscan.io/).

```jsx
  <Address value={address} />
  <Address value={address} size="short" />
  <Address value={address} size="long" blockexplorer="https://blockscout.com/poa/xdai/address/"/>
  <Address value={address} ensProvider={mainnetProvider}/>
```

![ensaddress](https://user-images.githubusercontent.com/2653167/80522487-e375fd80-8949-11ea-84fd-0de3eab5cd03.gif)

<br/>

🖋 `<AddressInput />`: An input box you control with useState for an Ethereum address that uses a [Blockie](https://www.npmjs.com/package/ethereum-blockies) and ENS lookup/display.

```jsx
  const [ address, setAddress ] = useState("")
  <AddressInput
    value={address}
    ensProvider={props.ensProvider}
    onChange={(address)=>{
      setAddress(address)
    }}
  />
```

<br/>

💵 `<Balance />`: Displays the balance of an address in either dollars or decimal.

```jsx
<Balance
  address={address}
  provider={injectedProvider}
  dollarMultiplier={price}
/>
```

![balance](https://user-images.githubusercontent.com/2653167/80522919-86c71280-894a-11ea-8f61-70bac7a72106.gif)

<br/>

<br/>

👤 `<Account />`: Allows your users to start with an Ethereum address on page load but upgrade to a more secure, injected provider, using [Web3Modal](https://web3modal.com/). It will track your `address` and `localProvider` in your app's state:

```jsx
const [address, setAddress] = useState();
const [injectedProvider, setInjectedProvider] = useState();
const price = useExchangePrice(mainnetProvider);
```

```jsx
<Account
  address={address}
  setAddress={setAddress}
  localProvider={localProvider}
  injectedProvider={injectedProvider}
  setInjectedProvider={setInjectedProvider}
  dollarMultiplier={price}
/>
```

![account](https://user-images.githubusercontent.com/2653167/80527048-fdffa500-8950-11ea-9a0f-576be87e4368.gif)

> 💡 **Notice**: the `<Account />` component will call `setAddress` and `setInjectedProvider` for you.

---

---

## 🖲 UI Library

🐜 [Ant.design](https://ant.design/components/button/) is a fantastic UI library with components like the [grids](https://ant.design/components/grid/), [menus](https://ant.design/components/menu/), [dates](https://ant.design/components/date-picker/), [times](https://ant.design/components/time-picker/), [buttons](https://ant.design/components/button/), etc.

---

## ⛑ Helpers:

`Transactor`: The transactor returns a `tx()` function to make running and tracking transactions as simple and standardized as possible. We will bring in [BlockNative's Notify](https://www.blocknative.com/notify) library to track our testnet and mainnet transactions.

```js
const tx = Transactor(props.injectedProvider, props.gasPrice);
```

Then you can use the `tx()` function to send funds and write to your smart contracts:

```js
tx({
  to: readContracts[contractName].address,
  value: parseEther("0.001"),
});
```

```js
tx(writeContracts["SmartContractWallet"].updateOwner(newOwner));
```

> ☢️ **Warning**: You will need to update the configuration for `react-app/src/helpers/Transactor.js` to use _your_ [BlockNative dappId](https://www.blocknative.com/notify)

---

## 🎚 Extras:

🔑 Create wallet links to your app with `yarn wallet` and `yarn fundedwallet`

⬇️ Installing a new package to your frontend? You need to `cd packages/react-app` and then `yarn add PACKAGE`

⬇️ Installing a new package to your backend? You need to `cd packages/harthat` and then `yarn add PACKAGE`

---

## 🛳 Ship it!

You can deploy your app with:

```bash

# packge up the static site:

yarn build

# ship it!

yarn surge

OR

yarn s3

OR

yarn ipfs
```

🚀 Good luck!

---

## 🔬 Using Tenderly

[Tenderly](https://tenderly.co) is a platform for monitoring, alerting and trouble-shooting smart contracts. They also have a hardhat plugin and CLI tool that can be helpful for local development!

Hardhat Tenderly [announcement blog](https://blog.tenderly.co/level-up-your-smart-contract-productivity-using-hardhat-and-tenderly/) for reference.

### Verifying contracts on Tenderly

scaffold-eth includes the hardhat-tenderly plugin. When deploying to any of the following networks:

```
["kovan","goerli","mainnet","rinkeby","ropsten","matic","mumbai","xDai","POA"]
```

You can verify contracts as part of the `deploy.js` script. We have created a `tenderlyVerify()` helper function, which takes your contract name and its deployed address:

```
await tenderlyVerify(
  {contractName: "YourContract",
   contractAddress: yourContract.address
})
```

Make sure your target network is present in the hardhat networks config, then either update the default network in `hardhat.config.js` to your network of choice or run:

```
yarn deploy --network NETWORK_OF_CHOICE
```

Once verified, they will then be available to view on Tenderly!

[![TenderlyRun](https://user-images.githubusercontent.com/2653167/110502199-38c98200-80b8-11eb-8d79-a98bb1f39617.png)](https://www.youtube.com/watch?v=c04rrld1IiE&t=47s)

#### Exporting local Transactions

One of Tenderly's best features for builders is the ability to [upload local transactions](https://dashboard.tenderly.co/tx/main/0xb8f28a9cace2bdf6d10809b477c9c83e81ce1a1b2f75f35ddd19690bbc6612aa/local-transactions) so that you can use all of Tenderly's tools for analysis and debugging. You will need to create a [tenderly account](https://tenderly.co/) if you haven't already.

Exporting local transactions can be done using the [Tenderly CLI](https://github.com/tenderly/tenderly-cli). Installing the Tenderly CLI:

```
brew tap tenderly/tenderly
brew install tenderly
```

_See alternative installation steps [here](https://github.com/tenderly/tenderly-cli#installation)_

You need to log in and configure for your local chain (including any forking information) - this can be done from any directory, but it probably makes sense to do under `/packages/hardhat` to ensure that local contracts are also uploaded with the local transaction (see more below!)

```
cd packages/hardhat
tenderly login
tenderly export init
```

You can then take transaction hashes from your local chain and run the following from the `packages/hardhat` directory:

```
tenderly export <transactionHash>
```

Which will upload them to tenderly.co/dashboard!

Tenderly also allows users to debug smart contracts deployed to a local fork of some network (see `yarn fork`). To let Tenderly know that we are dealing with a fork, run the following command:

```
tenderly export init
```

CLI will ask you for your network's name and whether you are forking a public network. After choosing the right fork, your exporting will look something like this:

```
tenderly export <transactionHash> --export-network <networkName>
```

Note that `tenderly.yaml` file stores information about all networks that you initialized for exporting transactions. There can be multiple of them in a single file. You only need the `--export-network` if you have more than one network in your tenderly.yaml config!

**A quick note on local contracts:** if your local contracts are persisted in a place that Tenderly can find them, then they will also be uploaded as part of the local transaction `export`, which is one of the freshest features! We have added a call to `tenderly.persistArtifacts()` as part of the scaffold-eth deploy() script, which stores the contracts & meta-information in a `deployments` folder, so this should work out of the box.

Another pitfall when dealing with a local network (fork or not) is that you will not see the transaction hash if it fails. This happens because the hardhat detects an error while `eth_estimateGas` is executed. To prevent such behaviour, you can skip this estimation by passing a `gasLimit` override when making a call - an example of this is demonstrated in the `FunctionForm.jsx` file of the Contract component:

```
let overrides = {}
// Uncomment the next line if you want to skip the gas estimation for each transaction
// overrides.gasLimit = hexlify(1200000);
const returned = await tx(contractFunction(...args, overrides));
```

**One gotcha** - Tenderly does not (currently) support yarn workspaces, so any imported solidity contracts need to be local to `packages/hardhat` for your contracts to be exported. You can achieve this by using [`nohoist`](https://classic.yarnpkg.com/blog/2018/02/15/nohoist/) - this has been done for `hardhat` so that we can export `console.sol` - see the top-level `package.json` to see how!

```
"workspaces": {
  "packages": [
    "packages/*"
  ],
  "nohoist": [
    "**/hardhat",
    "**/hardhat/**"
  ]
}
```

---

## 🌐 Etherscan

Hardhat has a truly wonderful [`hardhat-etherscan` plugin](https://www.npmjs.com/package/@nomiclabs/hardhat-etherscan) that takes care of contract verification after deployment. You need to add the following to your `hardhat.config.js` imports:

```
require("@nomiclabs/hardhat-etherscan");
```

Then add your etherscan API key to the module.exports:

```
etherscan: {
  // Your API key for Etherscan
  // Obtain one at https://etherscan.io/
  apiKey: "YOUR-API-KEY-HERE"
}
```

Verifying is simple, assuming you are verifying a contract that you have just deployed from your hardhat setup - you just need to run the verify script, passing constructor arguments as an array if necessary (there is an example commented out in the `deploy.js`):

```
await run("verify:verify", {
  address: yourContract.address,
  // constructorArguments: args // If your contract has constructor arguments, you can pass them as an array
})
```

You only have to pass the contract because the plugin figures out which of the locally compiled contracts is the right one to verify. Pretty cool stuff!

---

## 🔶 Using Infura

You will need to update the `constants.js` in `packages/react-app/src` with [your own Infura ID](https://infura.io).

---

## 🟪 Blocknative

> update the `BLOCKNATIVE_DAPPID` in `packages/react-app/src/constants.js` with [your own Blocknative DappID](https://docs.blocknative.com/notify)

---
