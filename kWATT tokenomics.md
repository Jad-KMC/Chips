# kWATT Tokenomics Summary

**Purpose**  
kWATT is the utility token powering electricity payments within the Chips ecosystem. It serves two primary functions:

- **Powering Rentals:** Users pay for electricity during hashrate rentals with kWATT tokens.  
- **Reward Incentives:** Users earn kWATT through promotions, community participation, and liquidity pool incentives.

---

**Pricing and Valuation**

- **Default Price Cap:** `$0.08` USD per kWATT (set by the Chips team).  
- **Effective Price Range:** `$0.061 – $0.08` USD.  
- **Discounts:** Available via promotions and community roles (e.g. brand ambassador, support).  
- **DEX Pricing:** Users can purchase kWATT on decentralized exchanges. Chips monitors these prices:
  - If price < `$0.061`, the rental system buys from the DEX to restore price stability.
  - Users may also buy from DEXs and use cheaper tokens directly on the Chips site.

---

**Minting and Burning Logic**

- **Minting:** When a rental is initiated, kWATT tokens are minted and deposited into the Chips contract.  
- **Burning:** Upon rental completion, all kWATT tokens used are burned.  
- **Early Withdrawal:** Users who cancel early receive the remaining kWATTs minus a **20% penalty**.

---

**Supply Characteristics**

- **Unlimited Supply:** Tokens are minted and burned as needed, based on user activity and rental flows.

---

**Economic Design**

- The capped price ensures predictability for users.  
- The burn mechanism creates deflationary pressure tied to rental activity.  
- Strategic DEX arbitrage protects the economic floor of `$0.061`, ensuring operational stability.
