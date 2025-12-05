import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// 👇 FIX 1: Hide LocalStorage from Supabase to avoid conflict
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';

// 👇 FIX 2: Correct Router Import (Relative path is fine here)
import 'router.dart'; 

// 👇 FIX 3: Robust Package Import for LocalStorage
// Make sure 'studybudy_ai' matches your pubspec.yaml name exactly
import 'package:studybudy_ai/core/services/local_storage.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. Load Environment Variables
    await dotenv.load(fileName: ".env");
    debugPrint("✅ .env loaded!"); 

    // 2. Check keys
    final url = dotenv.env['SUPABASE_URL'];
    final key = dotenv.env['SUPABASE_ANON_KEY'];

    if (url == null || key == null) {
      throw Exception("❌ Supabase Keys not found in .env file");
    }

    // 3. Initialize Supabase
    await Supabase.initialize(
      url: url,
      anonKey: key,
    );
    debugPrint("✅ Supabase Initialized!");

    // 4. Initialize Local Storage
    // Agar ye line error de, to App ko STOP karke dobara chalayen
    await LocalStorage.init(); 
    debugPrint("✅ LocalStorage Initialized!");

    runApp(const MyApp());
    
  } catch (e) {
    debugPrint("🔥 CRITICAL ERROR: $e");
    runApp(ErrorApp(message: e.toString()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'StudyBuddy AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String message;
  const ErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red.shade50,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 10),
                const Text("Startup Failed", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}