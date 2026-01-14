import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart'; // 🔥 Hive Import
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/history_model.dart';
import 'package:prepvault_ai/features/quiz/models/quiz_model.dart';

class HistoryService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // 🔥 Hive Box Name (Must match Splash Screen)
  final String _boxName = 'study_history_db';

  // ===========================================================================
  // 🛡️ CRASH PROOF BOX GETTER (The Fix)
  // ===========================================================================
  // Ye synchronous getter (=>) ki jagah Future hai.
  // Ye check karega ke box open hai ya nahi. Agar band hai to open karega.
  Future<Box> get _box async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    } else {
      debugPrint("⚠️ [HISTORY] Box was closed. Re-opening safe mode...");
      return await Hive.openBox(_boxName);
    }
  }

  // ===========================================================================
  // 1️⃣ GET MAIN LIST (Dashboard Load)
  // ===========================================================================
  /// Pehle Hive Cache check karega (Fast), phir background mein Network call karega.
  Future<List<HistoryItem>> getHistory() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint("🚫 [HISTORY] No user logged in.");
      return [];
    }

    debugPrint("📥 [HISTORY] Getting history list...");

    // A. Fast Path: Check Hive Cache
    final cachedData = await _getHistoryFromHive(); // 🔥 Added await
    if (cachedData.isNotEmpty) {
      debugPrint("🚀 [HISTORY] Returning ${cachedData.length} items from Hive Cache (Fast Mode).");
      
      // Background Refresh (Dont await this, let it run in background)
      fetchLatestHistory(userId).then((_) => debugPrint("🔄 [HISTORY] Background refresh done."));
      
      return cachedData;
    }

    // B. Slow Path: Fetch from Network if cache is empty
    return await fetchLatestHistory(userId);
  }

  // ===========================================================================
  // 2️⃣ FETCH FROM SUPABASE (Network Call)
  // ===========================================================================
  Future<List<HistoryItem>> fetchLatestHistory(String userId, {bool onlyCompleted = true}) async {
    try {
      debugPrint("🌍 [HISTORY] Fetching fresh data from Supabase...");

      // NOTE: Ensure table name is 'study_history' in Supabase
      PostgrestFilterBuilder query = _supabase.from('study_history').select();
      query = query.eq('user_id', userId);

      if (onlyCompleted) {
        query = query.eq('status', 'completed');
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(50); // Increased limit for better history

      final List<HistoryItem> historyItems = (response as List).map((map) {
        return _mapSupabaseToModel(map);
      }).toList();

      debugPrint("✅ [HISTORY] Fetched ${historyItems.length} items successfully.");

      // 🔥 Save to Hive (Overwrite Cache)
      if (onlyCompleted) {
        await _saveHistoryToHive(historyItems);
      }

      return historyItems;

    } catch (e) {
      debugPrint("❌ [HISTORY] Error fetching list: $e");
      // Agar internet nahi hai to Hive Cache return karo
      return onlyCompleted ? await _getHistoryFromHive() : [];
    }
  }

  // ===========================================================================
  // 3️⃣ GET SINGLE ITEMS BY ID (Smart Lookup)
  // ===========================================================================
  
  // 🅰️ QUIZ DATA BY ID
  Future<List<dynamic>> getQuizDataById(String id) async {
    try {
      debugPrint("🔍 [HISTORY] Looking for Quiz Data. ID: $id");

      // 1. Check Hive directly (O(1) Lookup - Super Fast)
      final box = await _box; // 🔥 Safe Access
      final cachedMap = box.get(id);
      
      if (cachedMap != null) {
        debugPrint("🚀 [HISTORY] Found Quiz in Hive!");
        // Hive returns Map<dynamic, dynamic>, convert to Map<String, dynamic>
        final safeMap = Map<String, dynamic>.from(cachedMap);
        final item = HistoryItem.fromJson(safeMap);
        return _extractQuizList(item.content);
      }

      // 2. Network Fetch
      return await _fetchContentFromNetwork(id, (content) => _extractQuizList(content));
    } catch (e) {
      debugPrint("❌ [HISTORY] Error getting quiz: $e");
      return [];
    }
  }

  // 🅱️ QUESTION SET DATA BY ID
  Future<List<dynamic>> getQuestionSetDataById(String id) async {
    try {
      debugPrint("🔍 [HISTORY] Looking for Theory Set Data. ID: $id");

      // 1. Check Hive
      final box = await _box; // 🔥 Safe Access
      final cachedMap = box.get(id);

      if (cachedMap != null) {
        debugPrint("🚀 [HISTORY] Found Theory Set in Hive!");
        final safeMap = Map<String, dynamic>.from(cachedMap);
        final item = HistoryItem.fromJson(safeMap);
        return _extractQuizList(item.content);
      }

      // 2. Network Fetch
      return await _fetchContentFromNetwork(id, (content) => _extractQuizList(content));
    } catch (e) {
      debugPrint("❌ [HISTORY] Error getting theory set: $e");
      return [];
    }
  }

  // 🆎 SUMMARY DATA BY ID
  Future<String> getSummaryDataById(String id) async {
    try {
      debugPrint("📄 [HISTORY] Looking for Summary Data. ID: $id");

      // 1. Check Hive
      final box = await _box; // 🔥 Safe Access
      final cachedMap = box.get(id);

      if (cachedMap != null) {
        debugPrint("🚀 [HISTORY] Found Summary in Hive!");
        final safeMap = Map<String, dynamic>.from(cachedMap);
        final item = HistoryItem.fromJson(safeMap);
        return _extractSummaryText(item.content);
      }

      // 2. Network Fetch
      final result = await _fetchContentFromNetwork(id, (content) => _extractSummaryText(content));
      return result is String ? result : "Error loading summary.";
    } catch (e) {
      debugPrint("❌ [HISTORY] Error getting summary: $e");
      return "Error loading summary.";
    }
  }

  // Helper for Network Fetch of Single Items
  Future<dynamic> _fetchContentFromNetwork(String id, Function(dynamic) extractor) async {
    try {
      debugPrint("🌍 [HISTORY] Not in cache. Fetching ID $id from Supabase...");
      final response = await _supabase.from('study_history').select('content').eq('id', id).single();
      if (response != null) {
        debugPrint("✅ [HISTORY] Downloaded from Supabase.");
        return extractor(response['content']);
      }
    } catch (e) {
      debugPrint("❌ [HISTORY] Single Fetch Error: $e");
    }
    return [];
  }

  // ===========================================================================
  // 4️⃣ INSTANT CACHE INJECTION (Hive Magic)
  // ===========================================================================

  void cacheDataInstantly(String id, List<QuizQuestion> questions, {String title = 'Generated Quiz'}) {
    _injectToHive(id, 'quiz', title, {
      'data': questions.map((e) => e.toJson()).toList()
    });
  }

  void cacheQuestionSetInstantly(String id, List<QuizQuestion> questions, {String title = 'Theory Set'}) {
    _injectToHive(id, 'questionset', title, {
      'data': questions.map((e) => e.toJson()).toList()
    });
  }

  void cacheSummaryInstantly(String id, String summaryText, {String title = 'Generated Summary'}) {
    _injectToHive(id, 'summary', title, {
      'summary_markdown': summaryText,
      'content': summaryText
    });
  }

  // 🛠️ INTERNAL HELPER FOR HIVE INJECTION
  Future<void> _injectToHive(String id, String type, String title, Map<String, dynamic> content) async {
    try {
      debugPrint("💉 [HISTORY] Injecting '$type' into Hive...");

      final newItem = HistoryItem(
        id: id,
        type: type,
        title: title,
        createdAt: DateTime.now(),
        originalFileName: 'New File',
        status: 'completed',
        content: content,
      );

      // Save as Map directly using ID as key
      final box = await _box; // 🔥 Safe Access
      await box.put(id, newItem.toJson());
      
      debugPrint("✅ [HISTORY] Injection Complete! ID $id ready.");
    } catch (e) {
      debugPrint("⚠️ [HISTORY] Failed to cache instantly: $e");
    }
  }

  // ===========================================================================
  // 5️⃣ PARSING HELPERS (Original Logic Preserved)
  // ===========================================================================

  HistoryItem _mapSupabaseToModel(Map<String, dynamic> map) {
    dynamic resultJson;
    final contentData = map['content'];

    if (contentData is String) {
      try {
        resultJson = jsonDecode(contentData);
      } catch (e) {
        // Fallback logic preserved
        resultJson = {'summary_markdown': contentData, 'raw_text': contentData};
      }
    } else {
      resultJson = contentData;
    }

    return HistoryItem.fromJson({
      'id': map['id'],
      'type': map['type'],
      'title': map['title'] ?? resultJson?['title'] ?? 'Untitled',
      'created_at': map['created_at'],
      'original_file_name': map['original_file_name'] ?? 'Unknown File',
      'status': map['status'] ?? 'completed',
      'content': resultJson ?? {},
    });
  }

  List<dynamic> _extractQuizList(dynamic content) {
    dynamic parsed = content;
    if (parsed is String) {
      try { parsed = jsonDecode(parsed); } catch (_) { return []; }
    }
    if (parsed is Map && parsed.containsKey('data')) {
      return parsed['data'] is List ? parsed['data'] : [];
    } else if (parsed is List) {
      return parsed;
    }
    return [];
  }

  String _extractSummaryText(dynamic content) {
    if (content is String) return content;
    if (content is Map) {
      return content['summary_markdown'] ?? content['content'] ?? content['summary'] ?? "";
    }
    return "";
  }
  
  // Dummy item helper
  HistoryItem _emptyItem() {
    return HistoryItem(id: '', type: '', title: '', createdAt: DateTime.now(), originalFileName: '', status: '', content: {});
  }

  // ===========================================================================
  // 6️⃣ DELETE & CLEANUP (With Hive)
  // ===========================================================================
  
  Future<void> deleteItem(String id) async {
    try {
      debugPrint("🗑️ [HISTORY] Deleting item: $id");
      
      // 1. Delete from Cloud
      await _supabase.from('study_history').delete().eq('id', id);
      
      // 2. Delete from Hive (Instant)
      final box = await _box; // 🔥 Safe Access
      await box.delete(id);
      debugPrint("✅ Deleted from Hive.");
      
    } catch (e) {
      debugPrint("❌ Error deleting item: $e");
      // Still delete from local if cloud fails (Optimistic)
      final box = await _box;
      await box.delete(id);
    }
  }

  Future<void> cleanupOldFailures() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
       // Cleanup failed items older than 24 hours
       final yesterday = DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
       await _supabase.from('study_history').delete().eq('status', 'failed').lt('created_at', yesterday);
    } catch (e) {
      debugPrint("Cleanup Warning: $e");
    }
  }

  // ===========================================================================
  // 7️⃣ LOCAL STORAGE REPLACEMENT (Hive Logic)
  // ===========================================================================
  
  // 🔥 Save List to Hive
  Future<void> _saveHistoryToHive(List<HistoryItem> items) async {
    try {
      // Create a batch map { 'id': json, 'id2': json }
      final Map<String, Map<String, dynamic>> batchData = {};
      for (var item in items) {
        batchData[item.id] = item.toJson();
      }
      
      // Put All is very efficient
      final box = await _box; // 🔥 Safe Access
      await box.putAll(batchData);
      debugPrint("💾 [HIVE] Saved ${items.length} items.");
    } catch (e) {
      debugPrint("⚠️ [HIVE] Failed to save: $e");
    }
  }

  // 🔥 Get List from Hive
  // Updated to return Future because accessing _box is now async for safety
  Future<List<HistoryItem>> _getHistoryFromHive() async {
    try {
      final box = await _box; // 🔥 Safe Access

      if (box.isEmpty) return [];

      final List<HistoryItem> items = [];
      
      // Hive keys par iterate karo
      for (var key in box.keys) {
        final data = box.get(key);
        if (data != null) {
          // Hive returns LinkedMap, convert safely
          final safeMap = Map<String, dynamic>.from(data);
          items.add(HistoryItem.fromJson(safeMap));
        }
      }

      // Sort by CreatedAt (Newest First) kyunki Hive order guarantee nahi karta hamesha
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return items;
    } catch (e) {
      debugPrint("⚠️ [HIVE] Error reading cache: $e");
      return [];
    }
  }
}