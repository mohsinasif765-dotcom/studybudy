import 'dart:io';
import 'dart:async'; // Added for Completer/Future
import 'dart:convert';
import 'dart:typed_data'; 
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // compute, kIsWeb logic

// ---------------------------------------------------------------------------
// 🚀 TOP-LEVEL FUNCTION (BACKGROUND ISOLATE)
// Yeh function Class ke bahar hona zaroori hai taake 'compute' isay chala sakay.
// Yeh Mobile processor ke alag thread par heavy PDF parsing karega.
// ---------------------------------------------------------------------------
Future<String> _backgroundPdfParser(String filePath) async {
  // Yeh code alag thread par chalega, Main UI ko Block nahi karega
  final file = File(filePath);
  final bytes = await file.readAsBytes(); // Async read
  
  final document = PdfDocument(inputBytes: bytes);
  String text = PdfTextExtractor(document).extractText();
  document.dispose();
  
  return text;
}

class FileProcessingService {
  final _supabase = Supabase.instance.client;

  // ===========================================================================
  // 1️⃣ SMART IMAGE PROCESSOR (Web, Mobile, Desktop)
  // ===========================================================================
  Future<dynamic> processImageSmartly(
    XFile image, 
    String actionType, 
    {
      required Function(String status) onStatusChange,
      Map<String, dynamic>? options
    }
  ) async {
    // 🟢 FORAN UI UPDATE: Overlay show karne ke liye status update
    onStatusChange("Processing Image...");

    // 🔥 NEW CHECK: 40MB Limit for Images
    final int imageSize = await image.length();
    final double imageSizeMB = imageSize / (1024 * 1024);
    
    if (imageSizeMB > 40) {
      debugPrint("🛑 [STOP] Image size ($imageSizeMB MB) exceeds 40MB limit.");
      throw "File size is too large (Max 40MB).";
    }

    // Check Platform: Web/Desktop needs upload. Mobile uses local OCR.
    bool mustUpload = kIsWeb; 
    if (!kIsWeb) {
      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        mustUpload = true;
      }
    }

    if (mustUpload) {
      debugPrint("🌐/🖥️ [IMAGE] Web/Desktop detected. Uploading for AI Vision...");
      
      final bytes = await image.readAsBytes();
      final platformFile = PlatformFile(
        name: image.name,
        size: bytes.length,
        bytes: bytes,
      );

      return await _uploadAndPollServer(platformFile, actionType, onStatusChange, options);
    } 
    else {
      debugPrint("📱 [IMAGE] Mobile detected. Using LOCAL OCR.");
      onStatusChange("Reading Text (OCR)...");
      
      try {
        final text = await _extractTextFromImageLocal(image);
        debugPrint("✅ [OCR] Extracted ${text.length} chars locally.");

        // Send Text to Server
        return await processTextOnServer(
          text, 
          "Scanned Image ${DateTime.now().minute}", 
          actionType, 
          onStatusChange, 
          options
        );
      } catch (e) {
        // Agar Local OCR fail ho jaye (e.g. library crash), tab upload fallback
        debugPrint("⚠️ [OCR FAILED] Fallback to Upload. Error: $e");
        
        final bytes = await image.readAsBytes();
        final platformFile = PlatformFile(
          name: image.name,
          size: bytes.length,
          bytes: bytes,
        );
        return await _uploadAndPollServer(platformFile, actionType, onStatusChange, options);
      }
    }
  }

  // Local OCR (Mobile Only)
  Future<String> _extractTextFromImageLocal(XFile imageFile) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      final String rawText = recognizedText.text.trim();

      if (rawText.isEmpty) throw Exception("No text found.");
      if (rawText.length < 20) throw Exception("Text is too short (${rawText.length} chars).");

      return rawText;
    } catch (e) {
      if (e.toString().contains("Text is too short")) rethrow;
      throw Exception("OCR Failed: $e");
    } finally {
      await textRecognizer.close();
    }
  }

  // ===========================================================================
  // 2️⃣ SMART PDF HANDLER (With Background Isolate Fix)
  // ===========================================================================
  Future<dynamic> processSmartly(
    PlatformFile file, 
    String actionType, 
    {
      required Function(String status) onStatusChange,
      Map<String, dynamic>? options
    }
  ) async {
    // 🟢 FORAN UI UPDATE: Taake user ko lagay process start ho gaya
    onStatusChange("Analyzing File...");

    final int sizeInBytes = file.size;
    final double sizeInMB = sizeInBytes / (1024 * 1024);
    final cleanAction = actionType.toLowerCase().trim();

    debugPrint("📂 [PDF] Name: ${file.name} | Size: ${sizeInMB.toStringAsFixed(2)} MB");

    // 🔥 NEW CHECK: 40MB Limit
    if (sizeInMB > 40) {
      debugPrint("🛑 [STOP] File size ($sizeInMB MB) exceeds 40MB limit.");
      throw "File size is too large (Max 40MB).";
    }

    // 🛑 STRICT CHECK: 5MB Limit
    if (sizeInMB > 5) {
      debugPrint("🚀 [LARGE PDF] > 5MB. Uploading...");
      return await _uploadAndPollServer(file, cleanAction, onStatusChange, options);
    } 
    else {
      debugPrint("⚡ [SMALL PDF] < 5MB. Reading LOCALLY...");
      onStatusChange("Extracting Text...");
      
      try {
        // 🔥 Ye function ab 'compute' use karega crash bachane ke liye
        final text = await _extractLocally(file);
        debugPrint("✅ [LOCAL READ] Success. Extracted ${text.length} chars.");
        
        debugPrint("📤 [SERVER] Sending extracted text to AI...");
        return await processTextOnServer(text, file.name, cleanAction, onStatusChange, options);

      } catch (e) {
        
        debugPrint("🚨 [CATCH BLOCK] Exception Caught: $e");
        String errorStr = e.toString();

        // 👇 CRITICAL FIX: Agar Error AI/Server ka hai, to UPLOAD MAT KARO
        if (errorStr.contains("LOW_CREDITS") || 
            errorStr.contains("insufficient credits") ||
            errorStr.contains("Rate limit") || 
            errorStr.contains("AI Generation Failed") ||
            errorStr.contains("FunctionException")) { 
            
           debugPrint("🛑 [STOP] Server/AI Error detected. NOT switching to upload fallback.");
           rethrow; 
        }

        // Agar error Local Parsing ka tha, tabhi Fallback karo
        debugPrint("⚠️ [LOCAL READ FAILED] Reason: $e");
        debugPrint("🔄 [FALLBACK] Attempting Upload...");
        return await _uploadAndPollServer(file, cleanAction, onStatusChange, options);
      }
    }
  }

  // 🔥 UPDATED FUNCTION: Uses 'compute' to prevent App Crash/Freeze
  Future<String> _extractLocally(PlatformFile file) async {
    try {
      String text = "";

      // ---------------------------------------------------------
      // CASE 1: WEB (Web par standard parsing)
      // ---------------------------------------------------------
      if (kIsWeb) {
        PdfDocument document;
        if (file.bytes != null) {
          document = PdfDocument(inputBytes: file.bytes!);
        } else {
          throw "Web File bytes are empty.";
        }
        text = PdfTextExtractor(document).extractText();
        document.dispose();
      } 
      // ---------------------------------------------------------
      // CASE 2: MOBILE (Android/iOS) - USE BACKGROUND THREAD
      // ---------------------------------------------------------
      else {
        if (file.path != null) {
           // 🚀 JADOO: Yeh line heavy kaam background mein karegi
           // Is se App Freeze nahi hogi.
           text = await compute(_backgroundPdfParser, file.path!); 
        } else if (file.bytes != null) {
          // Fallback agar path na mile (rare case)
          final document = PdfDocument(inputBytes: file.bytes!);
          text = PdfTextExtractor(document).extractText();
          document.dispose();
        } else {
          throw "File path missing.";
        }
      }

      if (text.trim().isEmpty) throw "PDF text layer missing (Scanned?).";
      if (text.length < 50) throw "PDF text too short."; 
      if (text.length > 100000) text = text.substring(0, 100000); // Truncate
      
      return text;
    } catch (e) {
      if (e.toString().contains("_Namespace")) throw "Browser Error: Refresh Page.";
      throw "$e"; 
    }
  }

  // ===========================================================================
  // 3️⃣ SEND TEXT TO SERVER
  // ===========================================================================
  Future<dynamic> processTextOnServer(
    String text,
    String fileName,
    String actionType,
    Function(String status) onStatusChange,
    Map<String, dynamic>? options
  ) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw "User not logged in";

      final String dbType = actionType; 
      final String aiAction = (actionType == 'quiz') ? 'generate_quiz' : actionType;

      onStatusChange("AI Thinking..."); // Update UI
      
      final insertRes = await _supabase.from('study_history').insert({
        'user_id': user.id,
        'type': dbType, 
        'title': fileName,
        'original_file_name': fileName,
        'status': 'processing', 
        'content': {}, 
      }).select().single();

      final historyId = insertRes['id'];

      onStatusChange(actionType == 'quiz' ? "Generating Quiz..." : "Summarizing...");
      
      final res = await _supabase.functions.invoke('ai-brain', body: {
        'history_id': historyId,
        'action': aiAction, 
        'options': options ?? {},
        'content': text, 
      });

      if (res.data != null && res.data is Map && res.data['error'] != null) {
         throw res.data['error']; 
      }

      return await _pollForCompletion(historyId, actionType, onStatusChange, null);

    } catch (e) {
      throw e.toString().replaceAll("Exception:", "").trim();
    }
  }

  // ===========================================================================
  // 4️⃣ UPLOAD & POLL (Fallback / Large Files / Images)
  // ===========================================================================
  Future<dynamic> _uploadAndPollServer(
    PlatformFile file, 
    String actionType, 
    Function(String status) onStatusChange,
    Map<String, dynamic>? options
  ) async {
    String? uploadedPath; 
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw "User not logged in";

      final String dbType = actionType;
      final String aiAction = (actionType == 'quiz') ? 'generate_quiz' : actionType;

      final fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '_')}";
      uploadedPath = fileName;

      onStatusChange("Uploading File...");
      Uint8List fileBytes;
      
      if (kIsWeb) {
        fileBytes = file.bytes!;
      } else {
        if (file.path != null) {
          fileBytes = File(file.path!).readAsBytesSync();
        } else {
          fileBytes = file.bytes!;
        }
      }
      
      await _supabase.storage.from('documents').uploadBinary(
        uploadedPath, fileBytes, fileOptions: const FileOptions(upsert: true)
      );

      onStatusChange("Processing on Server...");
      
      final insertRes = await _supabase.from('study_history').insert({
        'user_id': user.id,
        'type': dbType,
        'title': file.name,
        'original_file_name': file.name,
        'status': 'uploading', 
        'content': {}, 
      }).select().single();

      final historyId = insertRes['id'];

      final res = await _supabase.functions.invoke('ai-brain', body: {
        'history_id': historyId,
        'action': aiAction,
        'options': options ?? {},
        'file_path': uploadedPath, 
      });

      if (res.data != null && res.data is Map && res.data['error'] != null) {
         throw res.data['error']; 
      }

      return await _pollForCompletion(historyId, actionType, onStatusChange, uploadedPath);

    } catch (e) {
      if (uploadedPath != null) _deleteFileFromBucket(uploadedPath); 
      throw e.toString().replaceAll("Exception:", "").trim();
    }
  }

  // ===========================================================================
  // 5️⃣ POLLING (Wait for AI Result)
  // ===========================================================================
  Future<dynamic> _pollForCompletion(
    String historyId, 
    String actionType, 
    Function(String status) onStatusChange,
    String? fileToDelete
  ) async {
    final startTime = DateTime.now();
    final cleanAction = actionType.toLowerCase().trim();

    while (DateTime.now().difference(startTime).inSeconds < 120) {
      await Future.delayed(const Duration(seconds: 4));
      
      final res = await _supabase.from('study_history').select('status, content').eq('id', historyId).single();
      final status = res['status'];

      if (status == 'completed') {
         onStatusChange("Finalizing...");
         if (fileToDelete != null) await _deleteFileFromBucket(fileToDelete);
         
         dynamic content = res['content'];

         if (content is String) {
           try { content = jsonDecode(content); } catch (_) {}
           if (content is String) { try { content = jsonDecode(content); } catch (_) {} }
         }

         if (cleanAction.contains('summary')) {
           if (content is Map) return content;
           return {
             'summary_markdown': content.toString(),
             'title': 'Summary',
             'emoji': '📄',
             'reading_time': '2 min',
             'key_points': [], 
           };
         }

         if (cleanAction.contains('quiz')) {
            if (content is Map && content.containsKey('data')) return content['data'];
            if (content is List) return content;
            if (content is Map) {
               for (var val in content.values) {
                 if (val is List) return val; 
               }
            }
            return content;
         }
         return content;
      }

      if (status == 'failed') {
        if (fileToDelete != null) await _deleteFileFromBucket(fileToDelete);
        final errorMsg = res['content']?['error'] ?? "AI Failed.";
        throw errorMsg; 
      }
    }
    throw "Timeout.";
  }

  Future<void> _deleteFileFromBucket(String path) async {
    try { await _supabase.storage.from('documents').remove([path]); } catch (_) {}
  }
}