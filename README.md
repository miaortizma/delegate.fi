# Delegate.fi

## Overall Idea
Use credit delegation from Aave to maximized returns to users who has idle borrowable power and does not know what to do with it. We handle it smoothly!

## Contracts Architecture

- Protocol fund contract: it is where the protocol fee revenue would be sent (should be multisig by all devs), it should not be much complex likely some withdrawal process with X days of timelock will work and another method for cancelling the process of withdrawal if some dev member disagree on the action and some events to track off-chain how much has been withdrawed and where. I think it should be sufficient.

- Delegated Credit Manager contract: basically will be the direct contact point between the users and the protocol, where they can assign the borrowing power to (amount agreed), and it will play the role of deploying the capital elsewhere. Basically the options of how much they can delegate would be done via f/e, nothing to worry about at the smart contract level.

- Strategy contract: it will be where initially the capital will be deployed. As a target we can look into what the gitcoin described for their bounty. Link shared on the group.

- Tracking User Returns contract: maybe here could be sent the returns from the strategy contract and pull out using the Superfluid stream feature somehow directly into the users wallet upon certain condition that makes economical sense. The users are going to be tracked via a mapping type variable within the Delegated Credit Manager, which could be a point to a struct, so it can be given on a pro-rata manner. Otherwise, it will need to be claimable from here.

- Dashboard for outsider borrowers contract: @ElocRemarc is very much interested in this front. Feel free to dive deeper.