import os
import io
import requests
from fastapi import FastAPI, BackgroundTasks, HTTPException
from pydantic import BaseModel
from supabase import create_client, Client
from pypdf import PdfReader

app = FastAPI()

# Supabase Credentials (Env Variables se ayenge)
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

class FileRequest(BaseModel):
    file_path: str  # e.g. "uploads/file_123.pdf"
    file_id: str    # Database ID to update status

# 🛠️ BACKGROUND TASK (Asal Jaadoo Yahan Hai)
def process_pdf_task(file_path: str, file_id: str):
    try:
        print(f"📥 Downloading: {file_path}")
        
        # 1. Download from Supabase Storage
        response = supabase.storage.from_("documents").download(file_path)
        
        # 2. Extract Text (Python is super optimized for this)
        pdf_file = io.BytesIO(response)
        reader = PdfReader(pdf_file)
        
        full_text = ""
        # Limit to 50 pages for speed (AI doesn't need more)
        limit = min(len(reader.pages), 50)
        
        for i in range(limit):
            page_text = reader.pages[i].extract_text()
            if page_text:
                full_text += page_text + "\n"

        status = "COMPLETED"
        if not full_text.strip():
            status = "FAILED"
            full_text = "Scanned PDF or Empty."

        # 3. Update Database (Mobile will listen to this)
        supabase.table("user_files").update({
            "extracted_text": full_text,
            "status": status,
            "processed_pages": limit
        }).eq("id", file_id).execute()
        
        print(f"✅ Success: {file_id}")

    except Exception as e:
        print(f"❌ Error: {e}")
        supabase.table("user_files").update({
            "status": "ERROR", 
            "error_message": str(e)
        }).eq("id", file_id).execute()

# 🚀 API ENDPOINT
@app.post("/webhook/process-pdf")
async def trigger_processing(req: FileRequest, background_tasks: BackgroundTasks):
    # Mobile ko foran "OK" bol do, kaam peeche chalta rahega
    background_tasks.add_task(process_pdf_task, req.file_path, req.file_id)
    return {"message": "Processing started in background"}