import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart'; 

// Aapke project imports
import 'package:prepvault_ai/core/theme/app_theme.dart';
import 'package:prepvault_ai/router.dart';
import 'package:prepvault_ai/core/services/hive_storage.dart'; 

void main() async {
  // 1. Bindings Init
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 2. Load Env (Ye zaroori hai Supabase k liye)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("⚠️ Env load warning: $e");
  }

  // 3. Initialize Hive (Bas Init, Boxes Splash me open honge)
  // Yeh is liye zaroori hai taake Supabase HiveLocalStorage ko use kar sake
  await Hive.initFlutter();
  
  // Note: Boxes Splash screen me open honge, lekin Supabase ka auth box
  // yahan open karna padega agar hum chahte hain ke Supabase init ho jaye.
  // Lekin aap chahte hain load Splash me ho, to hum Supabase Init bhi wahan shift kar sakte hain
  // ya phir yahan sirf 'supabase_auth' box open kar lein.
  
  // SAFE STRATEGY: Supabase init yahan hi rakhte hain taake Router ko pata ho user logged in hai ya nahi.
  await Hive.openBox('supabase_auth'); 

  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '', 
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        localStorage: HiveLocalStorage(), 
      ),
    ).timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint("⚠️ Supabase Offline/Error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  @override
  void initState() {
    super.initState();
    // 🚀 Heavy plugins load in background after app starts
    Future.delayed(const Duration(seconds: 2), () {
      _initHeavyPlugins();
    });
  }

  Future<void> _initHeavyPlugins() async {
    if (kIsWeb) return;

    // 1. Try AdMob
    try {
      await MobileAds.instance.initialize();
      debugPrint("✅ AdMob Connected");
    } catch (e) {
      debugPrint("❌ AdMob Failed (Ignored): $e");
    }

    // 2. Try IAP
    try {
      final Stream<List<PurchaseDetails>> purchaseUpdated = InAppPurchase.instance.purchaseStream;
      _subscription = purchaseUpdated.listen((purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      }, onError: (error) {
        debugPrint("❌ IAP Stream Error: $error");
      });
      debugPrint("✅ IAP Listener Active");
    } catch (e) {
      debugPrint("❌ IAP Init Failed: $e");
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    // Payment Logic
  }

  @override
Widget build(BuildContext context) {
  return MaterialApp.router(
    title: 'PrepVault AI', // Aapka naya brand name
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    
    // 🔥 Is line ko 'ThemeMode.light' kar den
    // Is se mobile ki settings jo bhi hon, app light hi rahegi
    themeMode: ThemeMode.light, 
    
    routerConfig: createRouter(),
  );
}
}