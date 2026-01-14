from fastapi import FastAPI, File, UploadFile, HTTPException
import fitz  # PyMuPDF
import pytesseract
from pdf2image import convert_from_bytes
import io

app = FastAPI()

@app.get("/")
def home():
    return {"message": "StudyBuddy Smart Extractor v2 is Running!"}

@app.post("/extract_text")
async def extract_text(file: UploadFile = File(...)):
    doc = None
    try:
        print(f"📥 Analysis started: {file.filename}")
        content = await file.read()
        
        doc = fitz.open(stream=content, filetype="pdf")
        total_pages = len(doc)
        
        full_text = ""
        valid_pages_count = 0
        is_scanned = False
        
        # 🧠 SMART EXTRACTION LOGIC
        # Hum shuru ke 50 pages scan karenge, lekin sirf 'kaam ke' pages uthayenge
        scan_depth = min(total_pages, 50)
        
        print(f"🔍 Scanning first {scan_depth} pages for quality content...")

        for i in range(scan_depth):
            page_text = doc[i].get_text()
            cleaned_text = page_text.strip()
            
            # 🛡️ GARBAGE FILTER:
            # Agar page par 100 se kam alfaaz hain (e.g. sirf "Chapter 1" likha ha), to SKIP karo.
            if len(cleaned_text) < 100:
                continue 

            full_text += f"\n--- Page {i+1} ---\n{cleaned_text}"
            valid_pages_count += 1
            
            # 🛑 STOPPING CONDITION:
            # Agar humein 15 bharpoor pages mil gaye hain, to bas karo (AI ke liye kaafi ha)
            if valid_pages_count >= 15:
                break

        # --- SCANNED DETECTION CHECK ---
        # Agar itne pages scan karne k baad bhi text bohot thora ha (< 200 chars), to ye Image ha.
        if len(full_text) < 200:
            print("⚠️ Low text density detected. Switching to OCR mode...")
            is_scanned = True
            full_text = "" # Reset
            
            # --- OCR FALLBACK (Heavy Process) ---
            # Sirf shuru ke 3 pages ka OCR karenge taake server crash na ho
            ocr_limit = min(total_pages, 3)
            
            images = convert_from_bytes(content, first_page=1, last_page=ocr_limit)
            
            for i, img in enumerate(images):
                page_text = pytesseract.image_to_string(img)
                full_text += f"\n--- Page {i+1} (OCR) ---\n{page_text}"
        
        else:
            print(f"✅ Successfully extracted text from {valid_pages_count} valid pages.")

        doc.close()
        
        if not full_text.strip():
            return {"text": "", "error": "Could not extract text (File might be empty)"}

        # Final Safety Truncate (AI Token Limit)
        if len(full_text) > 100000:
            full_text = full_text[:100000] + "\n...[Truncated]"

        return {
            "text": full_text.strip(),
            "pages_processed": 3 if is_scanned else valid_pages_count,
            "file_type": "scanned" if is_scanned else "digital"
        }

    except Exception as e:
        print(f"❌ Error: {str(e)}")
        if doc: doc.close()
        raise HTTPException(status_code=500, detail=str(e))