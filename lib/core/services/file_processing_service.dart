import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // compute & kIsWeb
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart'; 

class FileProcessingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // 👇 Yahan apna Render/Python Server ka URL dalein (Jab deploy ho jaye)
  // Filhal testing ke liye aap Ngrok URL bhi use kar sakte hain
  final String _serverUrl = "https://your-app-name.onrender.com"; 

  // ====================================================
  // 1. 📷 IMAGE OCR (Always Local)
  // Images usually choti hoti hain, mobile par fast hoti hain.
  // ====================================================
  Future<String> extractTextFromImage(XFile imageFile) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      if (recognizedText.text.trim().isEmpty) {
        throw Exception("No text found in image. Please try a clearer photo.");
      }
      return recognizedText.text;
    } catch (e) {
      throw Exception("OCR Failed: $e");
    } finally {
      await textRecognizer.close();
    }
  }

  // ====================================================
  // 2. 🧠 SMART PDF HANDLER (The Gatekeeper)
  // Decides whether to process locally or send to server.
  // Returns: String (Text) if local, NULL if sent to server.
  // ====================================================
  Future<String?> processSmartly(PlatformFile file, {Function(String status)? onStatusChange}) async {
    
    // Step 1: Check Size (5MB = 5 * 1024 * 1024 bytes)
    final int sizeInBytes = file.size;
    final bool isLargeFile = sizeInBytes > (5 * 1024 * 1024);

    if (isLargeFile) {
      // 🔴 CASE A: Large File (> 5MB) -> Send to Server
      onStatusChange?.call("Large File Detected (>5MB). Sending to Cloud...");
      await _uploadToServer(file, onStatusChange);
      return null; // Null return karne ka matlab hai: "User ko free kar do, notification ayega"
    } else {
      // 🟢 CASE B: Small File (< 5MB) -> Process Locally
      onStatusChange?.call("Processing File Locally...");
      return await _extractLocally(file);
    }
  }

  // 🏠 LOCAL PROCESSING (For Small Files)
  Future<String> _extractLocally(PlatformFile file) async {
    try {
      dynamic input;
      if (kIsWeb) {
        input = file.bytes!;
      } else {
        // Mobile par Path use karo (Memory Bachao)
        if (file.path != null) {
          input = file.path!;
        } else if (file.bytes != null) {
          input = file.bytes!;
        } else {
          throw Exception("File path missing.");
        }
      }
      
      // Compute (Isolate) use kar rahe hain taake UI freeze na ho
      return await compute(_isolateExtractPdf, input);
    } catch (e) {
      throw Exception("Could not read file locally. Error: $e");
    }
  }

  // ☁️ SERVER PROCESSING (For Large Files)
  Future<void> _uploadToServer(PlatformFile file, Function(String status)? onStatusChange) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      // Unique File Name
      final fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '_')}";
      final filePath = "$userId/$fileName";

      // 1. DB Entry (Ticket Create karo)
      final dbResponse = await _supabase.from('user_files').insert({
        'user_id': userId,
        'file_name': file.name,
        'file_path': filePath,
        'status': 'UPLOADING'
      }).select().single();
      
      final String fileId = dbResponse['id'];

      // 2. Upload to Storage
      onStatusChange?.call("Uploading to Cloud...");
      if (kIsWeb) {
        await _supabase.storage.from('documents').uploadBinary(filePath, file.bytes!);
      } else {
        await _supabase.storage.from('documents').upload(filePath, File(file.path!));
      }

      onStatusChange?.call("Triggering AI Server...");

      // 3. Webhook to Python Server
      try {
        await http.post(
          Uri.parse('$_serverUrl/webhook/process-pdf'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'file_path': filePath, 'file_id': fileId})
        ).timeout(const Duration(seconds: 5)); // Jaldi wapis aa jao, wait mat karo
      } catch (e) {
        // Timeout is OK here, server peeche kaam karta rahega
        debugPrint("Webhook triggered (Background processing started)");
      }

    } catch (e) {
      throw Exception("Server Upload Failed: $e");
    }
  }
}

// 🌍 BACKGROUND TASK (Isolate Function)
// Ye function main class se bahar hona chahiye taake 'compute' isay chala sake.
Future<String> _isolateExtractPdf(dynamic input) async {
  try {
    PdfDocument document;
    
    // Load Document based on Input Type
    if (input is String) {
      document = PdfDocument(inputBytes: File(input).readAsBytesSync());
    } else {
      document = PdfDocument(inputBytes: input);
    }

    // Extract Text
    String text = PdfTextExtractor(document).extractText();
    document.dispose(); // Memory Saaf

    if (text.trim().isEmpty) throw "Scanned PDF Detected (Images only).";
    
    // Safety Truncate (Agar text had se zyada bara ho to kaat do taake app crash na ho)
    if (text.length > 200000) {
      text = text.substring(0, 200000);
      text += "\n\n[TRUNCATED: File was large, loaded first part for AI Analysis.]";
    }
    
    return text;
  } catch (e) {
    throw e;
  }
}