import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  // 🔒 Private Instance (Nullable banaya taake check kar sakein)
  static SharedPreferences? _instance;

  // ===========================================================================
  // 🚀 INITIALIZATION (Safe Logic)
  // ===========================================================================
  static Future<void> init() async {
    // 🔥 Check: Agar pehle se initialized hai to wapis jao (Crash se bachne k liye)
    if (_instance != null) {
      debugPrint("💾 [STORAGE] Already initialized. Skipping.");
      return;
    }

    _instance = await SharedPreferences.getInstance();
    debugPrint("💾 [STORAGE] Initialization Complete.");
  }

  // ===========================================================================
  // 📖 GETTERS (Safe Access using ?.)
  // ===========================================================================
  static String? getString(String key) => _instance?.getString(key);
  static bool? getBool(String key) => _instance?.getBool(key);
  static int? getInt(String key) => _instance?.getInt(key);
  static double? getDouble(String key) => _instance?.getDouble(key);
  static List<String>? getStringList(String key) => _instance?.getStringList(key);

  // ===========================================================================
  // ✍️ SETTERS (Safe Access)
  // ===========================================================================
  static Future<void> setString(String key, String value) async {
    await _instance?.setString(key, value);
  }

  static Future<void> setBool(String key, bool value) async {
    await _instance?.setBool(key, value);
  }

  static Future<void> setInt(String key, int value) async {
    await _instance?.setInt(key, value);
  }

  static Future<void> setDouble(String key, double value) async {
    await _instance?.setDouble(key, value);
  }

  static Future<void> setStringList(String key, List<String> value) async {
    await _instance?.setStringList(key, value);
  }

  // ===========================================================================
  // 🗑️ REMOVE / CLEAR
  // ===========================================================================
  static Future<void> remove(String key) async {
    await _instance?.remove(key);
  }

  static Future<void> clear() async {
    await _instance?.clear();
  }
  
  // Checks
  static bool containsKey(String key) => _instance?.containsKey(key) ?? false;
}