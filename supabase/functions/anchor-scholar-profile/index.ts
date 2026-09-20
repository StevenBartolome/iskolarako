// @ts-nocheck
import { createClient } from "npm:@supabase/supabase-js@2";
import { ethers } from "npm:ethers@6";

/**
 * anchor-scholar-profile
 *
 * Called after face verification succeeds in the app.
 * Computes a keccak256 hash of the scholar's immutable identity fields,
 * records it on the Polygon blockchain, and sets face_verification_status = 'verified'.
 *
 * Request body: { scholarId: string, reason?: string }
 * Response: { success, txHash, blockNumber, profileHash } or { success: false, error }
 */

const ABI = [
  "function anchorScholarProfile(string scholarId, bytes32 profileHash) returns (uint256)",
];

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const body = await req.json();
    const { scholarId, reason } = body || {};

    console.log(`[anchor-scholar-profile] Received request for scholarId: ${scholarId}`);

    if (!scholarId) {
      return new Response(
        JSON.stringify({ success: false, error: "scholarId is required" }),
        {
          status: 400,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        }
      );
    }

    // ── 1. Initialize Supabase (service_role for full admin access) ──
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // ── 2. Fetch scholar's locked identity fields ──
    const { data: scholar, error: fetchErr } = await supabase
      .from("scholar")
      .select(
        "id, first_name, last_name, middle_name, suffix, birth_date, gender, face_verification_status, face_verified_at"
      )
      .eq("id", scholarId)
      .maybeSingle();

    if (fetchErr || !scholar) {
      console.error(`[anchor-scholar-profile] Scholar not found: ${fetchErr?.message}`);
      return new Response(
        JSON.stringify({
          success: false,
          error: fetchErr?.message || "Scholar not found",
        }),
        {
          status: 404,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        }
      );
    }

    // Verified timestamp (preserve existing if already set, else set now)
    const verifiedAt = scholar.face_verified_at || new Date().toISOString();
    const faceStatus = "verified";

    // ── 3. Build canonical string and compute keccak256 hash ──
    //
    // Format: "scholarId|FIRST_NAME|LAST_NAME|MIDDLE_NAME|SUFFIX|BIRTH_DATE|GENDER|FACE_STATUS|VERIFIED_AT"
    // All name fields are uppercased and trimmed for deterministic hashing.
    //
    const canonicalParts = [
      scholar.id,
      (scholar.first_name || "").toUpperCase().trim(),
      (scholar.last_name || "").toUpperCase().trim(),
      (scholar.middle_name || "").toUpperCase().trim(),
      (scholar.suffix || "").toUpperCase().trim(),
      (scholar.birth_date || "").trim(),
      (scholar.gender || "").toLowerCase().trim(),
      faceStatus,
      verifiedAt.trim(),
    ];

    const canonicalString = canonicalParts.join("|");
    const profileHash = ethers.keccak256(ethers.toUtf8Bytes(canonicalString));

    console.log(
      `[anchor-scholar-profile] Scholar: ${scholarId}, Canonical: "${canonicalString}", Hash: ${profileHash}`
    );

    // ── 4. Write to Polygon blockchain ──
    const rpcUrl =
      Deno.env.get("ALCHEMY_RPC_URL") ||
      "https://polygon-amoy.g.alchemy.com/v2/alch_LdmO-wF5wwCTE5pMgXUAg";
    const privateKey = Deno.env.get("ADMIN_PRIVATE_KEY");
    const contractAddress =
      Deno.env.get("CONTRACT_ADDRESS") ||
      "0xafbef846a4aCf3efeFB992706bFdBb5dF7500829";

    if (!privateKey) {
      console.error("[anchor-scholar-profile] ADMIN_PRIVATE_KEY secret is not set");
      throw new Error(
        "ADMIN_PRIVATE_KEY secret is not set in Supabase Edge Function Secrets."
      );
    }

    console.log(`[anchor-scholar-profile] Connecting to contract at ${contractAddress} via RPC`);
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);
    const contract = new ethers.Contract(contractAddress, ABI, wallet);

    console.log(`[anchor-scholar-profile] Sending anchorScholarProfile tx for scholar ${scholarId}...`);
    const tx = await contract.anchorScholarProfile(scholarId, profileHash);
    console.log(`[anchor-scholar-profile] Sent TX: ${tx.hash}, waiting for confirmation...`);
    const receipt = await tx.wait();

    console.log(
      `[anchor-scholar-profile] Blockchain TX confirmed: ${receipt.hash}, Block: ${receipt.blockNumber}`
    );

    // ── 5. Update scholar row with verified status AND blockchain anchor data ──
    // Uses service_role client so database security triggers allow the update
    const { error: updateErr } = await supabase
      .from("scholar")
      .update({
        face_verification_status: "verified",
        face_verified_at: verifiedAt,
        face_verification_reason: reason || "Face & ID verification verified and anchored on Polygon blockchain",
        profile_blockchain_tx_hash: receipt.hash,
        profile_blockchain_block: Number(receipt.blockNumber),
        profile_blockchain_hash: profileHash,
        profile_blockchain_verified: true,
        updated_at: new Date().toISOString(),
      })
      .eq("id", scholarId);

    if (updateErr) {
      console.error(
        "[anchor-scholar-profile] DB update error:",
        updateErr.message
      );
      throw new Error(`Failed to update scholar database: ${updateErr.message}`);
    }

    console.log(`[anchor-scholar-profile] Scholar ${scholarId} successfully updated to verified and anchored!`);

    // ── 6. Log to audit_logs ──
    try {
      await supabase.from("audit_logs").insert({
        actor: "system:anchor-scholar-profile",
        action: "PROFILE_BLOCKCHAIN_ANCHORED",
        target: `scholar_id=${scholarId} | tx=${receipt.hash} | hash=${profileHash}`,
        ip_address: "edge_function",
      });
    } catch (auditErr) {
      console.warn("[anchor-scholar-profile] Audit log error:", auditErr);
    }

    return new Response(
      JSON.stringify({
        success: true,
        txHash: receipt.hash,
        blockNumber: Number(receipt.blockNumber),
        profileHash: profileHash,
        canonicalFields: canonicalParts.length,
      }),
      {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  } catch (error: any) {
    console.error("[anchor-scholar-profile] Error:", error.message || error);
    return new Response(
      JSON.stringify({ success: false, error: error.message || String(error) }),
      {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      }
    );
  }
});
