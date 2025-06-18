Here’s the revised README section with **all of your logic and details preserved**, reworded for clarity and formatted in proper GitHub Markdown. Nothing is omitted or abridged:


# Chips Smart Contract Overview

This document details the core functions of the Chips smart contract system, including clear definitions of all parameters, the logic involved in each function, and the overall structure of how mining rentals and tokenized rewards are managed.

---

````
## Function: `add-new-coin`


(defun add-new-coin (COIN:string fungible:module{fungible-v2} total-hashrate:decimal kWatts-per-day:decimal external:bool)
````

**Description**
Registers a new mineable coin for use in the Chips ecosystem.

**Parameters**

* `COIN` — The name of the mined coin (e.g., `"BTC"`, `"LTC"`, `"DOGE"`, `"KDA"`).
* `fungible` — The cToken associated with the coin (e.g., `cBTC`, `cLTC`).
* `total-hashrate` — The amount of mining hashrate available for this coin’s algorithm.
* `kWatts-per-day` — Estimated daily electricity usage for one unit of hashrate (e.g., per TH/s or GH/s).
* `external` — Boolean flag indicating reward distribution method:

  * `true` = rewards are claimed externally
  * `false` = rewards are claimed on-chain via Chips

**Purpose**
This enables admins to onboard new mineable tokens easily by providing a base level of hashpower and configuring how the platform should treat its reward claiming logic.

---

## Function: `insert-coin-mined`

```lisp
(defun insert-coin-mined (coin:string mined:decimal caller:string)
```

**Description**
Records the total amount of coins mined by the Chips mining operation for a specific coin.

**Parameters**

* `coin` — The coin being mined (e.g., `"BTC"`, `"KDA"`).
* `mined` — The total amount of coin mined from the pool. This value should always increase.
* `caller` — Identity authorized to submit the update, such as an admin or an oracle.

**Purpose**
This function powers reward calculations by logging cumulative mining data over time. It must be used consistently to ensure accurate rental-based reward distribution.

---

## Function: `change-total-hashrate`

```lisp
(defun change-total-hashrate (additional-hashrate:decimal cType:string)
```

**Description**
Adjusts the total available hashrate for a specific coin.

**Parameters**

* `additional-hashrate` — A positive or negative number representing added or removed hashrate.
* `cType` — The cToken type associated with this coin (e.g., `"cBTC"`, `"cLTC"`).

**Purpose**
This supports dynamic updates when machines are added or removed. For example, a negative value reflects downtime or hardware failure.

---

## Function: `claim-multiple`

```lisp
(defun claim-multiple (account:string external-account:[string] lock-ids:list)
```

**Description**
Allows users to claim mined rewards from multiple rentals.

**Parameters**

* `account` — The Kadena `k:` address of the user making the claim.
* `external-account` — An array of 1 or 2 external wallet addresses depending on the coin:

  * For BTC: `["btc123" ""]`
  * For merge-mined coins like LTC + DOGE: `["ltc123", "doge123"]`
* `lock-ids` — A list of lock IDs to claim from (e.g., `["0", "1", "13", "50"]`).
  You cannot claim from different coin types in one call to avoid mixing accounts.

**Purpose**
Used alongside the `claim` function to withdraw mined rewards tied to specific rental contracts.

---

## Function: `get-mined-for-lock`

```lisp
(defun get-mined-for-lock (lock-id:string coin:string)
```

**Description**
Performs the full reward calculation for a given lock ID by tracking changes in hashrate and cumulative mining output over time.

**Parameters**

* `lock-id` — The unique ID of the rental (e.g., `"0"`, `"1"`).
* `coin` — The coin being mined. For most coins, this parameter is ignored. However, for merge-mined setups (e.g., LTC with DOGE), this must specify the secondary coin (e.g., `"DOGE"`).

---

### Calculation Logic (Detailed)

The calculation system is designed to **reduce gas usage and avoid retroactive penalty effects** from changes in global hashrate. A naive calculation would divide past rewards based on present hashrate — which is incorrect. Instead, Chips uses a `change-index` system.

#### Concept: `change-index`

Each time total hashrate is changed (via `change-total-hashrate`), a global `change-index` is incremented. Every rental is created with the current value of this index. The function uses this value to track exactly how hashrate conditions changed during the life of a rental.

---

### Three-Step Reward Calculation:

1. **Initial Period Check**
   If the rental’s `change-index` matches the current global `change-index`, no calculation is necessary beyond the current period.

2. **Step 1 — Base Calculation**

   * Find the amount of coin mined at the start of the rental.
   * Find the amount mined by the end of the first change index.
   * Subtract the two to get **Result 1** (initial earned amount).

3. **Step 2 — Cascading Calculation**

   * For each intermediate `change-index`, calculate:

     * The amount of coin mined.
     * The applicable `divisor` (i.e., total hashrate at that point).
     * Divide user hashrate by this divisor to get proportional earnings.
   * Add all these periods to get **Result 2**.

4. **Step 3 — Final Period**

   * Calculate mined coins in the current `change-index` since the last change.
   * Compute user’s share and add as **Result 3**.

5. **Final Total** = `Result 1 + Result 2 + Result 3`

This approach ensures accuracy even as mining conditions change, and prevents over-penalizing users when hashrate increases mid-rental.

---

## Function: `start-rental`

```lisp
(defun start-rental (account:string cType:string cToken-amount:decimal payment-token:string payment-token-amount:decimal rental-duration:integer caller:string)
```

**Description**
Initializes a mining rental with cTokens and energy paid using kWATTs.

**Parameters**

* `account` — The user's Kadena `k:` account.
* `cType` — Token type representing hashrate (e.g., `"cBTC"`).
* `cToken-amount` — Amount of cTokens already held by the user (can be `0`).
* `payment-token` — The token used for payment (usually `"KDA"` unless using a bridge).
* `payment-token-amount` — How much the user is paying.
* `rental-duration` — Number of days the rental will run.
* `caller` — Used to validate EVM bridge calls when `payment-token` ≠ `"KDA"`.

**Purpose**
This is the core entry point for users — it wraps all key mechanics:

* Accepts crypto payment
* Calculates and mints corresponding cTokens and kWATTs
* Starts a lock for rental tracking
* Enables optional bridging logic

---

## Function: `extend-one-rental`

```lisp
(defun extend-one-rental (account:string lock-id:string use-kWATTs:bool payment-token:string payment-token-amount:decimal extend-by-days:integer caller:string)
```

**Description**
Extends an existing rental by adding more duration and/or energy.

**Parameters**

* `account` — The user's Kadena `k:` account.
* `lock-id` — The rental lock to extend (e.g., `"0"`, `"1"`).
* `use-kWATTs` — Boolean; if true, uses all available kWATTs in the wallet (up to the max required).
* `payment-token` — Token used to purchase additional time.
* `payment-token-amount` — How much the user is paying for the extension.
* `extend-by-days` — Number of days to add.
* `caller` — Required only for EVM-bridge initiated calls.

**Purpose**
Gives users control to continue mining by topping up duration and energy balance on an active lock.

---

## Function: `withdraw-from-lock`

```lisp
(defun withdraw-from-lock (account:string external-account:[string] lock-id:string)
```

**Description**
Allows the user to exit a rental early or after completion.

**Parameters**

* `account` — The user's Kadena `k:` account.
* `external-account` — Merge-mined external wallet structure as in `claim-multiple`.
* `lock-id` — The rental ID to withdraw from.

**Purpose**
Withdraws locked cTokens, and reclaims any unused kWATTs if the rental has not fully expired. Early exits will still burn kWATTs pro-rata based on usage.

---

Let me know when you want to append a section for **admin-only functions**, **keyset controls**, or **reward oracle logic**.

```
```
