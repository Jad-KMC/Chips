// combinedScript.js

import { URL } from 'url';
import { promises as fs } from 'fs';
import Pact from 'pact-lang-api';
import dotenv from "dotenv";
dotenv.config();

// ======================================================
// Coin Earnings Functions
// ======================================================

const baseUrl = 'https://www.viabtc.net';
const apiKey = process.env.VIABTC_API_KEY;

/**
 * Fetch stats data from PoolFlare and return the account balance and total paid.
 * @returns {Promise<{balance: any, paid: any}>} - Resolves with an object containing balance and paid.
 */
export async function fetchPoolFlareStats() {
  const statsUrl = 'https://poolflare.net/api/v1/coin/kda/account/k:bc14a24516fba3a6dcc1f6f54ab16e10213c7dbd85f220ceb95043b72c3595df/stats';

  try {
    const response = await fetch(statsUrl);
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }
    const statsData = await response.json();
    if (!statsData || !statsData.status) {
      throw new Error("Invalid stats data or status is false.");
    }
    const { balance, paid } = statsData.data;
    return { balance, paid };
  } catch (error) {
    console.error("Error fetching stats data:", error);
    throw error;
  }
}

/**
 * Fetch the total profit for BTC or LTC.
 * @param {string} coin - The coin symbol, e.g., "BTC" or "LTC".
 * @returns {Promise<number>} - Resolves with the total profit number.
 */
export async function fetchProfitSummary(coin) {
  const url = new URL('/res/openapi/v1/profit', baseUrl);
  url.searchParams.append('coin', coin);

  try {
    const headers = {
      'X-API-KEY': apiKey,
      'Content-Type': 'application/json'
    };

    const response = await fetch(url, { headers });
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }

    const data = await response.json();
    if (data.code === 0) {
      return data.data.total_profit;
    } else {
      throw new Error(`API error: ${data.message}`);
    }
  } catch (error) {
    console.error(`Error fetching ${coin} data:`, error);
    throw error;
  }
}

/**
 * Fetch the total DOGE rewards since February 17th, 2024.
 * @returns {Promise<number>} - Resolves with the total DOGE rewards.
 */
export async function fetchTotalDogeRewards() {
  const url = new URL('/res/openapi/v1/reward/history', baseUrl);
  url.searchParams.append('coin', 'DOGE');

  // Fixed start date and dynamic end date.
  const fixedStartDate = '2024-02-17';
  const today = new Date();
  const formatDate = (date) => {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  };

  url.searchParams.append('start_date', fixedStartDate);
  url.searchParams.append('end_date', formatDate(today));
  url.searchParams.append('limit', '100');

  try {
    const headers = {
      'X-API-KEY': apiKey
    };

    const response = await fetch(url, { headers });
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }

    const data = await response.json();
    if (data.code === 0) {
      let totalRewards = 0;
      data.data.data.forEach(day => {
        totalRewards += parseFloat(day.total_profit);
      });
      return totalRewards;
    } else {
      throw new Error(`API error: ${data.message}`);
    }
  } catch (error) {
    console.error('Error fetching DOGE data:', error);
    throw error;
  }
}

// ======================================================
// Pact / Chainweb Functions
// ======================================================

const NETWORK_ID = process.env.NETWORK_ID;
const CHAIN_ID = process.env.CHAIN_ID;
const API = process.env.API;
const API_HOST = `https://${API}/chainweb/0.0/${NETWORK_ID}/chain/${CHAIN_ID}/pact`;

const KEY_PAIR = {
  publicKey: process.env.PUBLIC_KEY,
  secretKey: process.env.SECRET_KEY,
};

const creationTime = () => Math.round(new Date().getTime() / 1000);

/**
 * Format the price value.
 * @param {number} value - The value to format.
 * @param {boolean} [round] - Whether to round the value.
 * @returns {string} - The formatted number as a string.
 */
const formatPrice = (value, round) => {
  const stringValue = value.toString();
  let decimalNumber;
  try {
    let numValue = Number(stringValue);

    if (round) {
      decimalNumber = Math.ceil(numValue) + 0.0000001;
    } else {
      if (Number.isInteger(numValue)) {
        decimalNumber = numValue.toFixed(1);
      } else {
        decimalNumber = numValue.toFixed(5);
      }
    }
  } catch (e) {
    decimalNumber = stringValue;
  }

  return decimalNumber;
};

/**
 * Call the Pact API to record mined coins.
 * @param {string} coin - The coin symbol.
 * @param {string} mined - The mined amount (formatted as a string).
 * @param {string} caller - The caller identifier.
 * @returns {Promise<any>} - Resolves with the API response.
 */
async function setMined(coin, mined, caller) {
  const cmd = {
    networkId: NETWORK_ID,
    keyPairs: KEY_PAIR,
    pactCode: `(n_e98a056e3e14203e6ec18fada427334b21b667d8.chips.insert-coin-mined "${coin}" ${mined} "${caller}")`,
    envData: {},
    meta: {
      creationTime: creationTime(),
      ttl: 28000,
      gasLimit: 10000,
      chainId: CHAIN_ID,
      gasPrice: 0.0000001,
      sender: "k:" + KEY_PAIR.publicKey,
    },
  };

  const response = await Pact.fetch.local(cmd, API_HOST);
  return response;
}

// ======================================================
// Update Loop: Fetch Data & Call setMined for Each Coin
// ======================================================

const updateMined = async () => {
  while (true) {
    try {
      // 1. PoolFlare Stats for KDA:
      const { balance, paid } = await fetchPoolFlareStats();
      // Convert balance and paid to numbers and sum them
      const kdaMined = parseFloat(balance) + parseFloat(paid);
      const kdaResult = await setMined(
        "KDA",
        formatPrice(kdaMined),
        "k:" + KEY_PAIR.publicKey
      );
      console.log("KDA result:", kdaResult);

      // 2. BTC Profit Summary:
      const btcProfit = await fetchProfitSummary("BTC");
      // Force add 0.1
      const adjustedBtcProfit = Number(btcProfit);
      const btcResult = await setMined("BTC", formatPrice(adjustedBtcProfit), "k:" + KEY_PAIR.publicKey);
      
      
      console.log("BTC result:", btcResult);

      // 3. LTC Profit Summary:
      const ltcProfit = await fetchProfitSummary("LTC");
      const adjustedLtcProfit = Number(ltcProfit);
      const ltcResult = await setMined(
        "LTC",
        formatPrice(adjustedLtcProfit),
        "k:" + KEY_PAIR.publicKey
      );
      console.log("LTC result:", ltcResult);

      // 4. DOGE Profit Summary (via reward history):
      const dogeProfit = await fetchTotalDogeRewards();
      const dogeResult = await setMined(
        "DOGE",
        formatPrice(dogeProfit),
        "k:" + KEY_PAIR.publicKey
      );
      console.log("DOGE result:", dogeResult);

      // Wait for two hours (6600000 ms) before the next iteration.
      await new Promise((resolve) => setTimeout(resolve, 6600000));
    } catch (error) {
      console.error("Error in update loop:", error);
    }
  }
};

updateMined();
