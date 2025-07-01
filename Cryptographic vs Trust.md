# Chips Protocol: Trust-Based vs. Cryptographically Enforced Architecture

## Overview

The Chips protocol includes an on-chain Oracle system designed to report crypto-mining operation data (e.g. hashrate, shares submitted, mining rewards) onto the blockchain for transparent, automated reward distribution.  

To comply with best practices in decentralized architecture, we divide its components into:

1. **Cryptographically Enforced Components** (provable, verifiable on-chain)
2. **Trust-Based Components** (requires off-chain trust assumptions)

---

## 1. Cryptographically Enforced Components

These components have *on-chain logic* that enforces correctness or enables external cryptographic verification. They do not rely on subjective trust in the oracle operator.

### 1.1 Function: `insert-coin-mined`

**Purpose**:  
Records total mined amounts per coin on-chain for rewards tracking and claiming.

**Verification Methods**:

- **Pool Data Cross-Verification**:  
  Public mining pool stats (e.g. via Watcher links) list total mined currency. Anyone can independently cross-check the recorded totals.

- **Hashrate & Difficulty Model**:  
  Theoretical expected mining output can be calculated using:
  - Reported hashrate (TH/s)
  - Network difficulty (dynamic, historical data on-chain or via reputable APIs)
  - Block rewards and emission schedules

  This means even without direct pool data, a mathematical range for "expected mined coins" can be validated.

- **On-Chain Record**:  
  Once data is inserted, it's immutable and auditable. Any manipulation attempt is visible on-chain.

---

### 1.2 Function: `chips-policy.submit-mining-data`

**Purpose**:  
Records difficulty and number of accepted shares per machine over a period.

**Verification Methods**:

- On-chain contract enforces data schema and integrity.
- Anyone can recompute expected shares from reported hashrate and known network difficulty to validate plausibility.
- Historical difficulty snapshots can be stored or referenced to detect outlier submissions.

**Enforced Elements**:

- Format, schema, and storage of data on-chain.
- Immutable history for auditability.

**Limitations**:

- While the *on-chain storage* is enforced, *the raw source data* (miner logs) cannot be cryptographically proven untampered. This bridges us into the trust-based section.

---

## 2. Trust-Based Components

These rely on operator integrity and cannot be cryptographically enforced purely on-chain. The Chips protocol recognizes this limitation and documents it clearly.

### 2.1 Miner Log Generation & Parsing

**Description**:  
Miner log files are generated locally on mining hardware, containing share submissions, timestamps, difficulties, worker IDs, etc.

**Trust Assumptions**:

- Operators can tamper with logs before submission.
- No cryptographic signing or secure attestation from miner firmware is enforced.

---

### 2.2 Oracle Submission

**Description**:  
Oracle node collects mining logs, parses share counts and difficulty, and calls `submit-mining-data`.

**Trust Assumptions**:

- Oracle operator must honestly relay the log data.
- No enforced signature chain from miner to on-chain.

---

## 3. Summary Table

| Component                       | Category                   | Enforced By                              | Trust Assumption                                      |
|---------------------------------|----------------------------|------------------------------------------|--------------------------------------------------------|
| `chips.insert-coin-mined`         | Cryptographically Enforced | On-chain record, pool data cross-check   | None beyond network-wide difficulty data accuracy      |
| `chips-policy.submit-mining-data` | Cryptographically Enforced | On-chain schema & history, share plausibility | Trust in original miner log correctness               |
| Miner Log Generation            | Trust-Based                | N/A                                      | Operator can modify logs                               |
| Oracle Submission Process       | Trust-Based                | N/A                                      | Oracle must honestly parse and submit log data         |
