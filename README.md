# Chips 
Open Source codebase for managing RWA tokens on the kadena blockchain

======================================

Deliverable 1: Energy Token Framework

Final deliverable: A functional codebase for deploying energy-tracking tokens that can integrate with external systems
See: 

kWATT.pact and its usage in chips.pact

======================================

Deliverable 2: Hashrate Rental Framework

Final deliverable: A modular codebase enabling hashrate rental and computational asset tracking, with the ability to support additional tokens or features over time.

See: 

chips.pact - primary codebase, uses all of the contracts below

chips-policy.pact - This contract is where all mining data is stored, including ASIC information, mining data per machine chip, age, etc.

chips-oracle.pact - for prices of coins not on the kadena blockchain, such as ETH, BTC, LTC, DOGE, etc.

chips-presale.pact - this is very minor, we store our metrics here for profitability purposes such as energy usage per machine type and current profitability. `get-kwatts-and-power` is going to be the main function pulled from here.

======================================

Deliverable 3: Oracle Integration Framework

Final deliverable: A fully operational oracle system capable of interfacing with blockchain smart contracts and adapting to additional datasets or computational environments.

See:

chips-policy.pact

PoolDataSubmit.js - for tracking total tokens earned

MiningDataSubmit.js - for tracking shares submitted/accepted and difficulty for each one, assigning these details to an NFT

chips.pact - using all of the data submitted
