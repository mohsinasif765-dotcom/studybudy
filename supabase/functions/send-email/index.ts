import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // 1. Handle CORS (Pre-flight requests for Web/Mobile)
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 2. Get data from Flutter App
    const { name, email, subject, message } = await req.json();

    // 3. Send Email using Resend API
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: "StudyBuddy App <onboarding@resend.dev>", // Testing ke liye yehi use karein
        // Note: Production man apko apni domain verify kerni hogi Resend per
        to: ["studybudyai.support@gmail.com"], // 👈 Yahan apna admin email likhen jahan message receive kerna ha
        subject: subject,
        html: `
          <h3>New Contact Message</h3>
          <p><strong>From:</strong> ${name} (${email})</p>
          <p><strong>Category:</strong> ${subject}</p>
          <hr />
          <p><strong>Message:</strong></p>
          <p>${message}</p>
        `,
        reply_to: email, // Taake aap direct reply ker saken user ko
      }),
    });

    const data = await res.json();

    if (!res.ok) {
      return new Response(JSON.stringify({ error: data }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 4. Return Success to Flutter
    return new Response(JSON.stringify(data), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});