import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  // 🔒 Private Singleton Instance
  static late final SharedPreferences _instance;

  // 🚀 Initialize Function (Called in main.dart)
  static Future<void> init() async {
    _instance = await SharedPreferences.getInstance();
  }

  // --- 📖 GETTERS ---
  static String? getString(String key) => _instance.getString(key);
  static bool? getBool(String key) => _instance.getBool(key);
  static int? getInt(String key) => _instance.getInt(key);
  static double? getDouble(String key) => _instance.getDouble(key);
  static List<String>? getStringList(String key) => _instance.getStringList(key);

  // --- ✍️ SETTERS ---
  static Future<void> setString(String key, String value) => _instance.setString(key, value);
  static Future<void> setBool(String key, bool value) => _instance.setBool(key, value);
  static Future<void> setInt(String key, int value) => _instance.setInt(key, value);
  static Future<void> setDouble(String key, double value) => _instance.setDouble(key, value);
  static Future<void> setStringList(String key, List<String> value) => _instance.setStringList(key, value);

  // --- 🗑️ REMOVE / CLEAR ---
  static Future<void> remove(String key) => _instance.remove(key);
  static Future<void> clear() => _instance.clear();
  
  // Checks
  static bool containsKey(String key) => _instance.containsKey(key);
}