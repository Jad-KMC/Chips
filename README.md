# Chips
**Open-source framework for managing real-world asset (RWA) tokens on the Kadena blockchain.**

---

## Deliverable 1: Energy Token Framework

**Final Deliverable:**  
A functional codebase for deploying energy-tracking tokens, designed to integrate with external systems.

**Relevant Components:**
- `kWATT.pact` — defines the energy token structure.
- `chips.pact` — utilizes the kWATT framework for rental operations.

---

## Deliverable 2: Hashrate Rental Framework

**Final Deliverable:**  
A modular system enabling hashrate rental and computational asset tracking, built to support extensibility for additional tokens or features.

**Relevant Components:**
- `chips.pact` — primary contract orchestrating system logic.
- `chips-policy.pact` — storage of mining device metadata, mining outputs per chip, equipment aging, and related metrics.
- `chips-oracle.pact` — integration of off-chain coin prices (e.g., ETH, BTC, LTC, DOGE) into the on-chain environment.
- `chips-presale.pact` — maintains operational profitability metrics, including energy use by machine type. Key function: `get-kwatts-and-power`.

---

## Deliverable 3: Oracle Integration Framework

**Final Deliverable:**  
A fully operational oracle system capable of interfacing with smart contracts and adapting to additional datasets or computational environments.

**Relevant Components:**
- `chips-policy.pact` — primary contract for storing reported mining data (shares, difficulty, duration) linked to NFTs.
- `PoolDataSubmit.js` — monitors total token earnings across mining devices.
- `MiningDataSubmit.js` — tracks shares submitted/accepted and difficulty per chip, mapping this data to NFTs.
- `chips.pact` — integrates all oracle submissions into the broader platform logic.

---

## Notes
- All Pact contracts follow modular structure and minimize external dependencies.
- Oracle submission scripts are designed for low-latency updates and minimal gas overhead.
- System architecture prioritizes flexibility to support future integrations (additional token types, resource categories, or external oracles).
