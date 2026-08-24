import { ethers } from 'ethers';

export interface AuditResult {
  isTampered: boolean;
  onChainAmount?: number;
  onChainScholarId?: string;
  onChainPaymongoId?: string;
  error?: string;
}

// Fallback Polygon Amoy RPC nodes
const RPC_URLS = [
  'https://polygon-amoy.g.alchemy.com/v2/alch_LdmO-wF5wwCTE5pMgXUAg',
  'https://polygon-amoy-bor-rpc.publicnode.com',
  'https://rpc-amoy.polygon.technology',
];

// In-memory verification cache to avoid duplicate RPC queries for identical records
const memoryCache = new Map<string, AuditResult>();

/**
 * Helper to get a working JSON-RPC Provider by checking fallbacks
 */
async function getProvider(): Promise<ethers.JsonRpcProvider> {
  let lastError: any = null;
  for (const url of RPC_URLS) {
    try {
      const provider = new ethers.JsonRpcProvider(url);
      // Quickly verify network connectivity
      await provider.getNetwork();
      return provider;
    } catch (err) {
      console.warn(`RPC node failed: ${url}`, err);
      lastError = err;
    }
  }
  throw lastError || new Error("All Polygon Amoy RPC endpoints are unreachable.");
}

/**
 * Dynamically audits and verifies a database transaction against Polygon blockchain logs.
 * 
 * @param txHash Transaction hash on Polygon Amoy
 * @param dbAmount Numeric amount in PHP
 * @param dbScholarId Scholar's UUID in the database
 * @param dbScholarName Scholar's full name in the database
 */
export async function verifyDisbursementOnChain(
  txHash: string,
  dbAmount: number,
  dbScholarId: string,
  dbScholarName: string
): Promise<AuditResult> {
  if (!txHash || !txHash.startsWith('0x') || txHash.length !== 66) {
    return { isTampered: false, error: "Invalid transaction hash format" };
  }

  // Create unique cache key: combination of txHash, dbAmount, dbScholarId, and dbScholarName.
  // If the database changes (e.g. amount or scholar is tampered), the key will change,
  // causing a cache miss and triggering a fresh blockchain check.
  const cacheKey = `${txHash}_${Math.round(dbAmount)}_${dbScholarId.toLowerCase()}_${dbScholarName.toLowerCase()}`;

  // 1. Check in-memory cache
  if (memoryCache.has(cacheKey)) {
    return memoryCache.get(cacheKey)!;
  }

  // 2. Check sessionStorage cache to survive page refreshes
  try {
    const cachedString = sessionStorage.getItem(`iskoako_audit_${cacheKey}`);
    if (cachedString) {
      const cachedResult: AuditResult = JSON.parse(cachedString);
      memoryCache.set(cacheKey, cachedResult);
      return cachedResult;
    }
  } catch (e) {
    console.error("Failed to read audit cache from sessionStorage", e);
  }

  try {
    // 3. Connect to working RPC provider
    const provider = await getProvider();

    // 4. Fetch transaction details
    const tx = await provider.getTransaction(txHash);
    if (!tx) {
      throw new Error("Transaction details not found on-chain");
    }

    // 5. Setup interface to parse data
    const contractInterface = new ethers.Interface([
      "function recordRelease(string scholarshipId, string scholarId, uint256 amountCentavos, string paymongoPaymentId)"
    ]);

    // 6. Decode input data
    const decoded = contractInterface.parseTransaction({ data: tx.data });
    if (!decoded) {
      throw new Error("Failed to decode contract transaction input data");
    }

    // Parse decoded arguments:
    // Arguments: [scholarshipId, scholarId, amountCentavos, paymongoPaymentId]
    const onChainScholarId = decoded.args[1];
    const onChainAmountCentavos = Number(decoded.args[2]);
    const onChainAmount = onChainAmountCentavos / 100; // Convert centavos back to PHP
    const onChainPaymongoId = decoded.args[3];

    // 7. Verify fields: compare database records to on-chain blockchain values.
    // Use Math.round to avoid float rounding errors, or check for very small differences.
    const amountMismatch = Math.round(dbAmount) !== Math.round(onChainAmount);
    
    // Compare on-chain scholar field with BOTH DB UUID and DB Scholar Name
    const scholarMismatch = 
      dbScholarId.toLowerCase() !== onChainScholarId.toLowerCase() && 
      dbScholarName.toLowerCase() !== onChainScholarId.toLowerCase();

    const result: AuditResult = {
      isTampered: amountMismatch || scholarMismatch,
      onChainAmount,
      onChainScholarId,
      onChainPaymongoId,
    };

    // Store in cache
    memoryCache.set(cacheKey, result);
    try {
      sessionStorage.setItem(`iskoako_audit_${cacheKey}`, JSON.stringify(result));
    } catch (e) {
      console.warn("sessionStorage cache write failed", e);
    }

    return result;
  } catch (err: any) {
    console.error("Error during real-time on-chain verification:", err);
    return {
      isTampered: false,
      error: err.message || "Failed to query blockchain ledger",
    };
  }
}
