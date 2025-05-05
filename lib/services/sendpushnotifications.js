// Supabase Edge Function for sending push notifications via FCM
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// You'll need to create a Firebase service account and add the credentials to Supabase secrets
// Run: supabase secrets set FIREBASE_SERVICE_ACCOUNT_KEY='your-service-account-json'
const FIREBASE_SERVICE_ACCOUNT_KEY = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_KEY");

// This is the Supabase Edge Function entry point
serve(async (req) => {
  try {
    // Parse the request body
    const { token, title, body, payload } = await req.json();
    
    if (!token) {
      return new Response(
        JSON.stringify({ error: "FCM token is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }
    
    // Make the request to FCM API
    const response = await sendPushNotification(token, title, body, payload);
    
    return new Response(
      JSON.stringify(response),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error sending push notification:", error);
    
    return new Response(
      JSON.stringify({ error: "Failed to send push notification" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

// Function to send push notification via FCM
async function sendPushNotification(token, title, body, payload) {
  if (!FIREBASE_SERVICE_ACCOUNT_KEY) {
    throw new Error("Firebase service account key not configured");
  }

  const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_KEY);
  
  // First, get an access token for Firebase
  const accessToken = await getFirebaseAccessToken(serviceAccount);
  
  // Prepare the FCM message
  const message = {
    message: {
      token: token,
      notification: {
        title,
        body,
      },
      data: {
        payload: payload || "",
      },
      android: {
        notification: {
          sound: "default",
          priority: "high",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    },
  };
  
  // Send the message to FCM
  const url = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${accessToken}`,
    },
    body: JSON.stringify(message),
  });
  
  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`FCM API error: ${response.status} ${errorText}`);
  }
  
  return await response.json();
}

// Function to get Firebase access token
async function getFirebaseAccessToken(serviceAccount) {
  const now = Math.floor(Date.now() / 1000);
  
  // Create a JWT for Google's OAuth2 service
  const jwtHeader = {
    alg: "RS256",
    typ: "JWT",
  };
  
  const jwtPayload = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600, // 1 hour expiration
    iat: now,
  };
  
  // Encode the JWT header and payload
  const encodedHeader = btoa(JSON.stringify(jwtHeader));
  const encodedPayload = btoa(JSON.stringify(jwtPayload));
  
  // Create the JWT content
  const signatureInput = `${encodedHeader}.${encodedPayload}`;
  
  // Sign the JWT using the private key from the service account
  const privateKey = serviceAccount.private_key.replace(/\\n/g, '\n');
  const encoder = new TextEncoder();
  const keyImport = await crypto.subtle.importKey(
    "pkcs8",
    encoder.encode(privateKey),
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );
  
  const signature = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    keyImport,
    encoder.encode(signatureInput)
  );
  
  // Convert the signature to base64
  const base64Signature = btoa(String.fromCharCode(...new Uint8Array(signature)));
  
  // Create the complete JWT
  const jwt = `${encodedHeader}.${encodedPayload}.${base64Signature}`;
  
  // Exchange the JWT for an access token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  
  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text();
    throw new Error(`OAuth2 error: ${tokenResponse.status} ${errorText}`);
  }
  
  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}