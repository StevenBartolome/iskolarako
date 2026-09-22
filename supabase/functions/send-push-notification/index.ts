// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface PushNotificationPayload {
  userId?: string;
  userIds?: string[];
  title: string;
  body: string;
  type?: string;
  data?: Record<string, any>;
}

// Generate Google OAuth 2.0 Access Token using Web Crypto API
async function getGoogleAccessToken(serviceAccount: any): Promise<string> {
  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  const pemContents = serviceAccount.private_key
    .replace(pemHeader, "")
    .replace(pemFooter, "")
    .replace(/\s/g, "");

  const binaryDerString = atob(pemContents);
  const binaryDer = new Uint8Array(binaryDerString.length);
  for (let i = 0; i < binaryDerString.length; i++) {
    binaryDer[i] = binaryDerString.charCodeAt(i);
  }

  const key = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const encode = (obj: any) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");

  const unsignedToken = `${encode(header)}.${encode(claimSet)}`;
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsignedToken)
  );

  const base64Signature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  const jwt = `${unsignedToken}.${base64Signature}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const resData = await res.json();
  if (!resData.access_token) {
    throw new Error(`Failed to get OAuth token: ${JSON.stringify(resData)}`);
  }
  return resData.access_token;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_ANON_KEY") ??
      "";

    const serviceAccountRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "";

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const payload: PushNotificationPayload = await req.json();
    const { userId, userIds, title, body, type = "info", data = {} } = payload;

    const targetUserIds = userIds || (userId ? [userId] : []);

    if (targetUserIds.length === 0) {
      return new Response(
        JSON.stringify({ success: false, error: "No target user specified." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    // 1. Fetch FCM tokens for target users from user_fcm_tokens table
    const { data: tokenRows, error: tokenError } = await supabase
      .from("user_fcm_tokens")
      .select("fcm_token, user_id")
      .in("user_id", targetUserIds);

    if (tokenError) {
      return new Response(
        JSON.stringify({ success: false, error: tokenError.message }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
      );
    }

    if (!tokenRows || tokenRows.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          deliveredCount: 0,
          message: "No active FCM tokens found for target user(s).",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
      );
    }

    const tokens = tokenRows.map((r: any) => r.fcm_token).filter(Boolean);

    let deliveredCount = 0;
    const errors: any[] = [];

    // 2. Obtain Google OAuth 2.0 Token & Dispatch FCM v1 Push Payload
    if (serviceAccountRaw) {
      const serviceAccount = JSON.parse(serviceAccountRaw);
      const accessToken = await getGoogleAccessToken(serviceAccount);
      const projectId = serviceAccount.project_id || "iskolarako-2343f";

      for (const token of tokens) {
        try {
          const fcmRes = await fetch(
            `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
            {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${accessToken}`,
              },
              body: JSON.stringify({
                message: {
                  token: token,
                  notification: {
                    title: title,
                    body: body,
                  },
                  data: {
                    type: type,
                    click_action: "FLUTTER_NOTIFICATION_CLICK",
                    ...data,
                  },
                },
              }),
            }
          );

          if (fcmRes.ok) {
            deliveredCount++;
          } else {
            const errText = await fcmRes.text();
            errors.push({ token, error: errText });
          }
        } catch (fcmErr: any) {
          errors.push({ token, error: fcmErr.message });
        }
      }
    } else {
      console.warn("[FCM Notice]: FIREBASE_SERVICE_ACCOUNT secret not set.");
    }

    return new Response(
      JSON.stringify({
        success: true,
        deliveredCount,
        totalTokens: tokens.length,
        errors: errors.length > 0 ? errors : undefined,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );
  } catch (err: any) {
    console.error("[Push Notification Error]:", err);
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );
  }
});
