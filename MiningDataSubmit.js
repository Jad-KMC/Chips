/**
 * Full end‑to‑end Kadena mining‑data ingestion & submission script
 *
 * - Reads all log files from `<coin>MiningLogs/`
 * - Parses each share: worker (C0,C1…), accepted?, difficulty, timestamp
 * - Reads on‑chain NFTs from `chips-policy.get-all-token-ids` & `get-token`
 * - Decodes each NFT’s associatedChips binary -> machine#, startChip
 * - Groups shares by token+machine if within that chip range
 * - For each token+machine: computes accepted‑share count, avg difficulty,
 *   duration (start->end)
 * - Submits via `chips-policy.submit-mining-data`
 * - Moves processed logs to `processed<coin>Logs/`
 * - testnet contract is "free.chipsKDA-policy"
 */

import fs from 'fs/promises';
import path from 'path';
import Pact from 'pact-lang-api';

// ------------------------------------------------------------------------------------
// CONFIGURATION
// ------------------------------------------------------------------------------------
const NETWORK_ID    = 'testnet04';
const CHAIN_ID      = '1';
const API_HOST      = `https://api.testnet.chainweb.com/chainweb/0.0/${NETWORK_ID}/chain/${CHAIN_ID}/pact`;
const CONTRACT_NAME = 'free.chipsKDA-policy';
const CALLER        = "k:4aab9f08f1bd86c3ce007a9a87225ef061c09e7062efa622e2fd704c24514cfa"; //replace with your public key with oracle permissions
const KEY_PAIR      = {
  publicKey: CALLER.slice(2),
  secretKey: "SECRET_KEY_GOES_HERE"
};

// ------------------------------------------------------------------------------------
// TIMING HELPERS
// ------------------------------------------------------------------------------------
/** Pact expects a recent timestamp; subtract a small buffer for safety */
function creationTime() {
  return Math.floor(Date.now() / 1000) - 15;
}
/** Simple delay for throttling submissions */
function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// ------------------------------------------------------------------------------------
// READ-ONLY CONTRACT CALL
// ------------------------------------------------------------------------------------
/**
 * fetchContractData
 *
 * Generic read-only helper for any function on chips-policy.
 * @param {string} fnName  - on-chain function name (e.g. "get-all-token-ids", "get-token")
 * @param {...any} args    - zero or more args for that function
 * @returns {Promise<any[]>} - `.data` from Pact or [] on error
 */
async function fetchContractData(fnName, ...args) {
  // Serialize args: strings quoted, numbers as-is
  const ser = args.map(a =>
    typeof a === 'string' ? `"${a}"` : a
  ).join(' ');
  const pactCode = ser
    ? `(${CONTRACT_NAME}.${fnName} ${ser})`
    : `(${CONTRACT_NAME}.${fnName})`;

  const cmd = {
    networkId: NETWORK_ID,
    pactCode,
    envData: {},
    meta: {
      creationTime: creationTime(),
      ttl: 28000,
      gasLimit: 930000,
      chainId: CHAIN_ID,
      gasPrice: 0.0000001,
      sender: "" // read-only
    }
  };

  try {
    const resp = await Pact.fetch.local(cmd, API_HOST);
    if (resp.result.status === "success") {
      return resp.result.data;
    } else {
      console.error(`Error reading ${fnName}:`, resp.result.error.message);
      return [];
    }
  } catch (err) {
    console.error(`Exception in fetchContractData(${fnName}):`, err);
    return [];
  }
}

// ------------------------------------------------------------------------------------
// PARSING & AGGREGATION HELPERS
// ------------------------------------------------------------------------------------
/**
 * parseLogLine
 *
 * Extracts timestamp, workerId, accepted, difficulty from a raw log line.
 * Example raw:
 *   "[2025-02-20 20:14:58.560],accept,...,C1:A80,...Diff 55/50,50(...)"
 */
function parseLogLine(line) {
  const tsMatch = line.match(/^\[([^\]]+)\]/);
  const workerMatch = line.match(/,([^,]*?),[^\n]*?C(\d+):A(\d+)/);
  const diffMatch = line.match(/Diff\s+\d+\/\d+,(\d+(\.\d+)?)/);
  if (!tsMatch || !workerMatch || !diffMatch) return null;

  return {
    timestamp: new Date(tsMatch[1]).getTime(),
    worker: `C${workerMatch[2]}`,
    shareIndex: parseInt(workerMatch[3], 10),
    accepted: line.includes(',accept,'),
    difficulty: parseFloat(diffMatch[1])
  };
}

/**
 * decodeAssociatedChips
 *
 * Given an NFT’s associated-chips binary string and numChips count,
 * returns { machine: number, start: number, end: number }.
 *
 * E.g. "10000000101" → machine 0, start 101
 *      if numChips=50 → end = start + numChips - 1
 */
function decodeAssociatedChips(binStr, numChips) {
  // Strip leading '1' marker, then:
  // assume upper bits before last 8 represent machine, last bits represent start
  // here we'll take first 3 bits as machine, rest as start
  const totalBits = binStr.length;
  const machineBits = 3;
  const machine = parseInt(binStr.slice(0, machineBits), 2);
  const start   = parseInt(binStr.slice(machineBits), 2);
  return { machine, start, end: start + numChips - 1 };
}

/**
 * aggregateSharesByToken
 *
 * For each on-chain token, groups matching shares (by machine & chip range),
 * then computes acceptedCount, avgDifficulty, durationSeconds.
 */
function aggregateSharesByToken(shares, tokens, coin) {
  const results = [];
  for (const tokenId of tokens) {
    const td = tokens[tokenId];
    const { numChips, associatedChips } = td;
    const { machine, start, end } =
      decodeAssociatedChips(associatedChips, numChips);

    // Filter shares matching this machine & chip range & accepted
    const matched = shares.filter(s =>
      s.worker === `C${machine}` &&
      s.shareIndex >= start &&
      s.shareIndex <= end &&
      s.accepted
    );
    if (matched.length === 0) continue;

    const acceptedCount = matched.length;
    const avgDiff =
      matched.reduce((sum, s) => sum + s.difficulty, 0) / acceptedCount;
    const times = matched.map(s => s.timestamp).sort();
    const duration = Math.ceil((times[times.length - 1] - times[0]) / 1000);

    results.push({
      tokenId,
      coin,
      shares: acceptedCount,
      difficulty: avgDiff,
      duration,
      address: CALLER
    });
  }
  return results;
}

// ------------------------------------------------------------------------------------
// SUBMISSION HELPER
// ------------------------------------------------------------------------------------
async function submitMiningData(detail) {
  const { tokenId, coin, shares, difficulty, duration, address } = detail;
  // Build Pact code for submit-mining-data
  const pactCode = `(${CONTRACT_NAME}.submit-mining-data "${tokenId}" "${coin}" ${shares} ${difficulty} ${duration} "${address}")`;
  const cmd = {
    networkId: NETWORK_ID,
    keyPairs: KEY_PAIR,
    pactCode,
    envData: {},
    meta: {
      creationTime: creationTime(),
      ttl: 800,
      gasLimit: 800,
      chainId: CHAIN_ID,
      gasPrice: 0.0000001,
      sender: CALLER
    }
  };

  try {
    console.log("Submitting:", detail);
    const result = await Pact.fetch.send(cmd, API_HOST);
    console.log("→ Result:", await Pact.fetch.listen(result.requestKey));
  } catch (err) {
    console.error("Submission error for", detail, err);
  }
}
// ------------------------------------------------------------------------------------
// MAIN PROCESSING FUNCTION
// ------------------------------------------------------------------------------------
// The main function ties everything together:
//   1. It takes a coin type as a command-line argument.
//   2. It compiles the NFT-mining data by matching blockchain token data with aggregated mining logs.
//   3. It then loops over each token entry, printing the data to be submitted, and calls submitMiningData.
//   4. There is a 500-millisecond delay between each submission.
//   5. Finally, it moves the processed logs folder (e.g. KDAMiningLogs) to a new folder ("processedKDAMiningLogs")
//      to ensure that data is not submitted twice.
async function main() {
  // 1) Coin (e.g. "KDA","BTC","LTC") from CLI
  const coin = process.argv[2];
  if (!coin) {
    console.error("Usage: node script.js <KDA|BTC|LTC>");
    process.exit(1);
  }

  const logDir       = `${coin}MiningLogs`;
  const processedDir = `processed${coin}Logs`;

  // Ensure processed directory exists
  await fs.mkdir(processedDir, { recursive: true });

  // 2) Read & parse all log files
  const files = await fs.readdir(logDir);
  const shares = [];
  for (const file of files) {
    const content = await fs.readFile(path.join(logDir, file), 'utf-8');
    for (const line of content.split('\n')) {
      const parsed = parseLogLine(line);
      if (parsed) shares.push(parsed);
    }
    // Move processed file
    await fs.rename(
      path.join(logDir, file),
      path.join(processedDir, file)
    );
  }

  // 3) Fetch on-chain tokens
  const tokenIds = await fetchContractData("get-all-token-ids");
  const tokens = {};
  for (const id of tokenIds) {
    const t = await fetchContractData("get-token", id);
    tokens[id] = {
      numChips: t["num-chips"],
      associatedChips: t["associated-chips"]
    };
  }

  // 4) Aggregate & compress per token
  const toSubmit = aggregateSharesByToken(shares, tokens, coin);

  // 5) Submit each at 0.5s intervals
  for (const detail of toSubmit) {
    await submitMiningData(detail);
    await delay(500);
  }
}

// Execute
main().catch(err => {
  console.error("Fatal error:", err);
  process.exit(1);
});
