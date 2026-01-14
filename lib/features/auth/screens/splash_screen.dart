import 'dart:async';
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; 
import 'package:google_fonts/google_fonts.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart'; 

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  
  double _progress = 0.0;
  String _loadingText = "STARTING...";
  bool _hasError = false; 
  
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  @override
  void initState() {
    super.initState();
    
    _breathingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _breathingAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    // 🔥 FIX: Logic ko frame render honay k baad call karo
    // Taake app start hotay hi freeze na ho jaye.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runSplashLogic();
    });
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  Future<void> _runSplashLogic() async {
    debugPrint("🚀 [SPLASH] Logic Started...");
    FlutterNativeSplash.remove(); 

    if (mounted) setState(() { _hasError = false; _progress = 0.0; _loadingText = "STARTING..."; });

    // UI ko saans lene do
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // -----------------------------------------------------------
      // 🔥 STEP 0: PRE-LOAD FONTS
      // -----------------------------------------------------------
      if(mounted) setState(() { _progress = 0.1; _loadingText = "LOADING RESOURCES..."; });
      
      try {
        await GoogleFonts.pendingFonts([
          GoogleFonts.spaceGrotesk(), 
          GoogleFonts.outfit(),
        ]);
      } catch (fontError) {
        debugPrint("⚠️ [SPLASH] Fonts Load Failed (Offline Mode): $fontError");
      }
      
      // Chota delay taake progress bar update ho
      await Future.delayed(const Duration(milliseconds: 100));

      // -----------------------------------------------------------
      // 🔥 STEP 1: INITIALIZE DATABASE (Hive)
      // -----------------------------------------------------------
      if(mounted) setState(() { _progress = 0.3; _loadingText = "INITIALIZING DB..."; });
      
      try {
        // Agar box pehle se open nahi hai tabhi open karo
        if (!Hive.isBoxOpen('user_prefs')) {
             await Future.wait([
              Hive.openBox('study_history_db'),     
              Hive.openBox('official_store_cache'), 
              Hive.openBox('user_prefs'),           
            ]);
        }
        debugPrint("✅ [SPLASH] Hive Boxes Opened Successfully.");
      } catch (e) {
        debugPrint("⚠️ [SPLASH] Hive Init Warning: $e");
      }

      // -----------------------------------------------------------
      // STEP 2: CHECK ONBOARDING
      // -----------------------------------------------------------
      if(mounted) setState(() { _progress = 0.5; _loadingText = "CHECKING STATUS..."; });
      
      bool seenOnboarding = false;
      try {
          // Box open hone ka wait zaroori hai agar upar fail hua ho
          var box = Hive.isBoxOpen('user_prefs') ? Hive.box('user_prefs') : await Hive.openBox('user_prefs');
          seenOnboarding = box.get('seen_onboarding', defaultValue: false);
      } catch (e) {
          final prefs = await SharedPreferences.getInstance();
          seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
      }

      // 🔥 UPDATE: Agar user Naya hai, to login MAT karo.
      if (!seenOnboarding) {
        debugPrint("🆕 [SPLASH] New User -> Going to Onboarding");
        if(mounted) setState(() { _progress = 1.0; _loadingText = "WELCOME!"; });
        await Future.delayed(const Duration(milliseconds: 500));
        
        if(mounted) context.go('/onboarding'); 
        return; 
      }

      // -----------------------------------------------------------
      // 🔥 STEP 3: CHECK SESSION (For Returning Users)
      // -----------------------------------------------------------
      debugPrint("🔍 [SPLASH] Checking Supabase Session...");
      final session = Supabase.instance.client.auth.currentSession;

      if (session != null) {
        // ✅ OLD USER LOGGED IN -> Dashboard
        debugPrint("🟢 [SPLASH] User Logged In. Going to Dashboard.");
        _finalizeAndGo('/dashboard'); 

      } else {
        // 🟡 USER HAS SEEN ONBOARDING BUT IS LOGGED OUT
        // Try to log them in Anonymously again (Guest Mode)
        debugPrint("👤 [SPLASH] Returning Guest. Logging in...");
        if(mounted) setState(() { _progress = 0.7; _loadingText = "RESTORING SESSION..."; });

        try {
          await Supabase.instance.client.auth.signInAnonymously();
          debugPrint("✅ [SPLASH] Anonymous Login Restored!");
          _finalizeAndGo('/dashboard');
        } catch (authError) {
          // ❌ Agar login fail ho (Internet issue), to Login Screen
          debugPrint("❌ [SPLASH] Anon Login Failed: $authError");
          if(mounted) setState(() { _progress = 0.9; _loadingText = "LOGIN REQUIRED..."; });
          _finalizeAndGo('/login');
        }
      }

    } catch (e) {
      debugPrint("❌ [SPLASH ERROR]: $e");
      // Fallback: Agar kuch samajh na aaye to Login par bhej do
      if(mounted) context.go('/login');
    }
  }

  Future<void> _finalizeAndGo(String route) async {
    if(mounted) setState(() { _progress = 1.0; _loadingText = "READY!"; });
    await Future.delayed(const Duration(milliseconds: 300));
    if(mounted) {
        debugPrint("🚀 [SPLASH] Navigating to: $route");
        context.go(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a237e), 
      body: Stack(
        children: [
          Positioned(top: -100, left: -100, child: _buildBlurCircle(Colors.indigo, 500)),
          Positioned(bottom: -100, right: -100, child: _buildBlurCircle(Colors.purple, 500)),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _breathingAnimation,
                  child: Container(
                    width: 130, height: 130,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(35), 
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 25, offset: const Offset(0, 10))],
                    ),
                    child: const Center(
                      child: Icon(Icons.school_rounded, size: 80, color: Color(0xFF1a237e)),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 32, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.white,
                      fontFamily: 'Roboto',
                    ), 
                    children: [
                      const TextSpan(text: "Prep"),
                      TextSpan(text: "Valt", style: TextStyle(color: Colors.indigo.shade200)),
                      const TextSpan(text: " AI"),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                
                if (_hasError)
                  Column(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                      const SizedBox(height: 10),
                      Text("Something went wrong", style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _runSplashLogic,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Retry"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF1a237e)),
                      )
                    ],
                  )
                else
                  SizedBox(
                    width: 200,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _progress,
                            minHeight: 6,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _loadingText, 
                          style: const TextStyle(fontSize: 11, color: Colors.white70, letterSpacing: 2.0, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            bottom: 30, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Powered by Almohsin Dev with ", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
                const Icon(Icons.favorite, color: Colors.redAccent, size: 14), 
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurCircle(Color color, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15)),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container(color: Colors.transparent)),
    );
  }
}