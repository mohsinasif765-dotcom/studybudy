import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // 0. Handle CORS
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  let history_id_ref = ''; 
  let file_path_ref = ''; 

  try {
    console.log("🚀 Function Triggered: process-file");

    // 1. Setup Clients
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) throw new Error("Missing Authorization Header");

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 2. Input Data Parse
    const { file_path, content, history_id, action, options } = await req.json();
    history_id_ref = history_id; 
    file_path_ref = file_path;

    console.log(`📜 STEP 1: Received Request`);
    console.log(`   - ID: ${history_id}`);
    console.log(`   - Action: ${action}`);

    let extractedText = "";

    // 👉 LOGIC BRANCH: Small File (Direct Text)
    if (content) {
       console.log("📝 Direct Text Provided. Skipping Download & OCR.");
       extractedText = content;
    } 
    // 👉 LOGIC BRANCH: Large File (Download)
    else if (file_path) {
       console.log(`💾 STEP 2: Downloading file from Storage: ${file_path}`);
       const { data: fileData, error: dlError } = await supabaseAdmin
         .storage.from('documents').download(file_path);
       
       if (dlError) throw new Error(`Download Failed: ${dlError.message}`);
       
       // Hugging Face Extraction
       const hfBaseUrl = Deno.env.get('HF_API_URL') ?? 'https://almohsin3-studybudy.hf.space';
       const hfUrl = `${hfBaseUrl}/extract_text`; 
    
       const formData = new FormData();
       formData.append('file', fileData, 'doc.pdf');
    
       console.log(`🔄 STEP 3: Sending to Hugging Face (${hfUrl})...`);
       const hfResponse = await fetch(hfUrl, { method: 'POST', body: formData });
    
       if (!hfResponse.ok) {
         const errText = await hfResponse.text();
         throw new Error(`Hugging Face Error (${hfResponse.status}): ${errText}`);
       }
       
       const hfResult = await hfResponse.json();
       extractedText = hfResult.text || "";
    } else {
       throw new Error("Neither 'content' nor 'file_path' provided.");
    }

    if (!extractedText) throw new Error("Extracted text is empty");

    // 5. Call AI Brain (Summary/Quiz Generation)
    console.log("🤖 STEP 4: Delegating to AI Brain...");
    const brainUrl = `${Deno.env.get('SUPABASE_URL')}/functions/v1/ai-brain`;
    
    const brainResponse = await fetch(brainUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': authHeader, 
      },
      body: JSON.stringify({
        action: action,       
        content: extractedText,
        options: options
      })
    });

    console.log(`   🧠 AI Brain Response Status: ${brainResponse.status}`);
    const brainData = await brainResponse.json();

    if (!brainResponse.ok) {
      console.error("   ❌ AI Brain Failed:", JSON.stringify(brainData));
      throw new Error(brainData.error || "AI Brain Failed to process request");
    }

    // AI Brain se jo data aya hai
    const finalContent = brainData.text ? brainData.text : brainData;
    console.log(`   ✅ AI Processing Complete.`);

    // =========================================================================
    // 🔍🔍🔍 DEBUG LOGGING ADDED HERE 🔍🔍🔍
    // =========================================================================
    const dataType = typeof finalContent;
    const isArray = Array.isArray(finalContent);
    
    console.log(`🕵️ DATA TYPE CHECK BEFORE SAVING:`);
    console.log(`   👉 Type: ${dataType}`);
    console.log(`   👉 Is Array? ${isArray}`);
    
    // Log first 200 characters to see format
    const preview = JSON.stringify(finalContent).substring(0, 200);
    console.log(`   👉 Content Preview: ${preview}...`);

    if (dataType === 'string') {
        console.error(`⚠️ WARNING: SAVING RAW STRING TO DB! (This causes client crash)`);
    } else {
        console.log(`✅ OK: Saving JSON Object/Array to DB.`);
    }
    // =========================================================================

    // 6. Update Database (Save Result)
    console.log("💾 STEP 5: Saving Result to Database...");
    
    const { error: updateError } = await supabaseAdmin
      .from('study_history')
      .update({
        content: finalContent, 
        status: 'completed'
      })
      .eq('id', history_id);

    if (updateError) {
      console.error("   ❌ Database Update Failed:", updateError);
      throw updateError;
    }

    // 🗑️ STEP 7: CLEANUP FILE
    if (file_path) {
      console.log("🧹 STEP 6: Cleaning up storage...");
      await supabaseAdmin.storage.from('documents').remove([file_path]);
    }

    console.log("🎉 STEP 7: Process Finished Successfully.");

    return new Response(JSON.stringify({ success: true, data: finalContent }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error: any) {
    console.error("🔥 FATAL ERROR:", error.message);
    
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    if (history_id_ref) {
       await supabaseAdmin.from('study_history')
         .update({ status: 'failed', content: { error: error.message } })
         .eq('id', history_id_ref);
    }

    if (file_path_ref) {
      await supabaseAdmin.storage.from('documents').remove([file_path_ref]);
    }

    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});