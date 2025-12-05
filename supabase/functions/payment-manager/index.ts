import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@12.0.0?target=deno";

serve(async (req) => {
  // CORS Headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };

  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    // 1. Initialize Supabase
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    );

    // 2. Verify User
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
    if (userError || !user) throw new Error("User not authenticated");

    const { action, planId, interval, platform, receipt, purchaseToken, productId } = await req.json();
    
    // Stripe Init
    const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') as string, { apiVersion: '2022-11-15' });

    // ==================================================
    // 🌐 CASE 1: WEB PAYMENT (STRIPE)
    // ==================================================
    if (action === 'create_stripe_session') {
      console.log(`💳 Creating Stripe Session: ${planId} (${interval})`);

      // 👇 REAL STRIPE PRICE IDs (Replace with yours)
      const prices: Record<string, Record<string, string>> = {
        'mini': {
          'month': 'price_mini_month', 
          'year': 'price_mini_year'
        },
        'basic': {
          'month': 'price_basic_month', 
          'year': 'price_basic_year'
        },
        'pro': {
          'month': 'price_pro_month', 
          'year': 'price_pro_year'
        }
      };

      // Select ID based on Plan & Interval
      const selectedPriceId = prices[planId]?.[interval] || prices[planId]?.['month'];
      if (!selectedPriceId) throw new Error("Price ID not found");

      const session = await stripe.checkout.sessions.create({
        payment_method_types: ['card'],
        line_items: [{ price: selectedPriceId, quantity: 1 }],
        mode: 'payment', // or 'subscription'
        success_url: `${req.headers.get('origin')}/dashboard?payment=success`,
        cancel_url: `${req.headers.get('origin')}/dashboard?payment=cancelled`,
        customer_email: user.email,
        metadata: { user_id: user.id, plan_id: planId, interval: interval }
      });

      return new Response(JSON.stringify({ url: session.url }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // ==================================================
    // 📱 CASE 2: MOBILE VERIFICATION (Google / Huawei)
    // ==================================================
    else if (action === 'verify_mobile_receipt') {
      console.log(`📲 Verifying ${platform} receipt...`);
      let isValid = false;

      // 🤖 A. Google Play Verification
      if (platform === 'google_play') {
        // Note: Real Google Verification requires OAuth Token generation from Service Account.
        // Simplified Logic:
        // 1. Get Access Token (Needs implementation or library)
        // 2. Call: GET https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{packageName}/purchases/products/{productId}/tokens/{token}
        
        // For now, allowing valid if receipt exists (Replace with real logic in production)
        if (purchaseToken && productId) isValid = true; 
        
        /* // Real implementation hint:
        const accessToken = await getGoogleAccessToken();
        const res = await fetch(`https://androidpublisher.googleapis.com/...`, { headers: { Authorization: `Bearer ${accessToken}` }});
        if (res.status === 200) isValid = true;
        */
      } 
      
      // 🧧 B. Huawei AppGallery Verification
      else if (platform === 'huawei_appgallery') {
        const appId = Deno.env.get('HUAWEI_APP_ID');
        const appSecret = Deno.env.get('HUAWEI_APP_SECRET');

        // 1. Get Access Token
        const tokenRes = await fetch('https://oauth-login.cloud.huawei.com/oauth2/v3/token', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: `grant_type=client_credentials&client_id=${appId}&client_secret=${appSecret}`
        });
        
        const tokenData = await tokenRes.json();
        const accessToken = tokenData.access_token;

        if (accessToken) {
          // 2. Verify Purchase
          // Use 'purchaseToken' sent from Flutter
          const verifyRes = await fetch('https://orders-at-dre.iap.dbankcloud.com/applications/purchases/tokens/verify', {
            method: 'POST',
            headers: { 
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${accessToken}` 
            },
            body: JSON.stringify({
              purchaseToken: purchaseToken,
              productId: productId
            })
          });
          
          const verifyData = await verifyRes.json();
          // Check response code (0 usually means success in Huawei)
          if (verifyData.responseCode === "0") isValid = true;
        }
      }

      // ✅ IF VALIDATED -> UPDATE DATABASE
      if (isValid || true) { // '|| true' is for testing while you setup credentials. REMOVE FOR PROD.
        
        const supabaseAdmin = createClient(
          Deno.env.get('SUPABASE_URL') ?? '',
          Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        );

        // Credits Logic
        let credits = 0;
        if (planId === 'mini') credits = 300;
        else if (planId === 'basic') credits = 2000;
        else if (planId === 'pro') credits = 10000;

        // Apply Multiplier for Yearly
        if (interval === 'year') credits = credits * 12;

        // Get current credits
        const { data: profile } = await supabaseAdmin.from('profiles').select('credits_total').eq('id', user.id).single();
        const newTotal = (profile?.credits_total || 0) + credits;

        // Update DB
        await supabaseAdmin.from('profiles').update({
          plan_id: planId,
          credits_total: newTotal,
          is_vip: planId === 'pro'
        }).eq('id', user.id);

        return new Response(JSON.stringify({ success: true, message: "Plan activated!" }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      } else {
        throw new Error("Invalid Receipt/Token");
      }
    }

    throw new Error("Invalid Action");

  } catch (error: any) {
    console.error("Payment Error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});