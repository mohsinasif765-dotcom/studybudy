import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // 1. Handle CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  console.log("----------------------------------------------------------------");
  console.log("🚀 [EMAIL] Function Triggered");

  try {
    // 2. Check API Key
    if (!RESEND_API_KEY) {
        console.error("❌ [EMAIL] Missing RESEND_API_KEY in Secrets");
        throw new Error("Server Misconfiguration: Missing API Key");
    }

    // 3. Get data from Flutter App
    const { name, email, subject, message } = await req.json();
    
    console.log(`📩 [EMAIL] From: ${name} (${email})`);
    console.log(`📝 [EMAIL] Subject: ${subject}`);

    if (!email || !message) {
        throw new Error("Missing required fields (email or message)");
    }

    // 4. Send Email using Resend API
    console.log("🔌 [EMAIL] Sending request to Resend API...");
    
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: "StudyBuddy App <onboarding@resend.dev>", // Testing domain
        to: ["studybudyai.support@gmail.com"], // Admin Email
        subject: `StudyBuddy Feedback: ${subject}`,
        html: `
          <h3>New Contact Message</h3>
          <p><strong>From:</strong> ${name} (${email})</p>
          <p><strong>Category:</strong> ${subject}</p>
          <hr />
          <p><strong>Message:</strong></p>
          <p>${message}</p>
          <br />
          <p style="font-size: 12px; color: grey;">Sent via StudyBuddy App</p>
        `,
        reply_to: email, // Direct reply to user
      }),
    });

    const data = await res.json();

    if (!res.ok) {
      console.error("❌ [EMAIL] Resend API Failed:", JSON.stringify(data));
      return new Response(JSON.stringify({ error: data }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    console.log(`✅ [EMAIL] Sent Successfully! ID: ${data.id}`);

    // 5. Return Success
    return new Response(JSON.stringify(data), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error: any) {
    console.error("🔥 [EMAIL] Critical Error:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});