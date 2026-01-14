import 'dart:convert';
import 'package:flutter/foundation.dart'; // debugPrint k liye
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/summary_model.dart';

class SummaryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ===========================================================================
  // 1. 🌍 TRANSLATE SUMMARY
  // ===========================================================================
  Future<String> translateSummary(String content, String targetLanguage) async {
    debugPrint("🌍 [SummaryService] Requesting Translation to: $targetLanguage");

    try {
      final response = await _supabase.functions.invoke(
        'ai-brain', // Ensure ye function deployed ho
        body: {
          'action': 'translate',
          'content': content,
          'options': {
            'target_language': targetLanguage,
          }
        },
      );

      debugPrint("📥 [SummaryService] AI Status: ${response.status}");
      
      // 1. Check Credits Error
      if (response.status == 400) {
        final data = response.data;
        if (data is Map && data['error'] != null) {
           debugPrint("❌ [SummaryService] API Error: ${data['error']}");
           if (data['error'].toString().contains('LOW_CREDITS')) {
             throw 'LOW_CREDITS';
           }
        }
      }

      if (response.status != 200) {
        throw Exception("Translation Failed (Status: ${response.status})");
      }
      
      final data = response.data;
      debugPrint("✅ [SummaryService] AI Response Data: $data");

      // 2. Parse Result (Safety Checks)
      if (data is Map) {
        // Case A: Direct Text key
        if (data.containsKey('text')) {
          return data['text'].toString();
        } 
        // Case B: Nested Data key
        else if (data.containsKey('data') && data['data'] is Map && data['data'].containsKey('text')) {
          return data['data']['text'].toString();
        }
      }
      
      // Case C: Agar direct string agayi
      if (data is String) return data;

      return data.toString();

    } catch (e) {
      if (e == 'LOW_CREDITS') rethrow;
      debugPrint("🔥 [SummaryService] Exception: $e");
      rethrow;
    }
  }

  // ===========================================================================
  // 2. 💬 CHAT WITH DOCUMENT
  // ===========================================================================
  Future<String> chatWithDocument(String context, String question) async {
    debugPrint("💬 [SummaryService] Sending Chat Question...");

    try {
      final response = await _supabase.functions.invoke(
        'ai-brain',
        body: {
          'action': 'chat',
          'content': '', // Content empty rakhein, context options man bhejein
          'options': {
            'document_context': context,
            'user_question': question,
          }
        },
      );

      if (response.status == 400) {
         final data = response.data;
         if (data is Map && data['error'].toString().contains('LOW_CREDITS')) throw 'LOW_CREDITS';
      }

      if (response.status != 200) throw Exception("Chat Failed");
      
      final data = response.data;
      if (data is Map && data.containsKey('text')) {
        return data['text'].toString();
      }
      
      return "I couldn't understand that.";

    } catch (e) {
      if (e == 'LOW_CREDITS') rethrow;
      debugPrint("🔥 Chat Error: $e");
      return "Error: $e";
    }
  }

  // ===========================================================================
  // 3. 📄 GENERATE SUMMARY (Updated Logic)
  // ===========================================================================
  Future<SummaryModel> generateSummary(String fileContent) async {
    debugPrint("📄 [SummaryService] Generating Summary...");
    try {
      // Note: Bari files k liye ye function use mat karein, process-file use karein.
      // Ye sirf choti text strings k liye theek hai.
      
      final response = await _supabase.functions.invoke(
        'ai-brain',
        body: {
          'action': 'summary',
          'content': fileContent,
          'options': {} 
        },
      );

      if (response.status == 400) {
        final data = response.data;
        if (data is Map && data['error'].toString().contains('LOW_CREDITS')) throw 'LOW_CREDITS';
      }

      final data = response.data;
      Map<String, dynamic> summaryData = {};

      // Handle Data parsing
      if (data is Map) {
        if (data.containsKey('summary_markdown')) {
          summaryData = Map<String, dynamic>.from(data);
        } else if (data.containsKey('data') && data['data'] is Map) {
          summaryData = Map<String, dynamic>.from(data['data']);
        }
      }

      if (summaryData.isNotEmpty) {
        // 🔥 FIX: Check if key_points contains headings and remove them
        if (summaryData.containsKey('key_points') && summaryData['key_points'] is List) {
          List<dynamic> rawPoints = summaryData['key_points'];
          List<String> cleanPoints = [];

          for (var point in rawPoints) {
            String p = point.toString().trim();
            // Filter out unwanted headings
            if (!p.startsWith('#') && !p.toLowerCase().contains('key points') && !p.toLowerCase().contains('conclusion')) {
              cleanPoints.add(p);
            }
          }
          summaryData['key_points'] = cleanPoints;
        }

        return SummaryModel.fromJson(summaryData);
      }

      throw Exception("Invalid AI Format");
      
    } catch (e) {
      if (e == 'LOW_CREDITS') rethrow;
      debugPrint("🔥 Summary Generation Error: $e");
      rethrow;
    }
  }
}