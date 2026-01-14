import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:http/http.dart' as http;
import 'package:country_picker/country_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ Supabase Import

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  bool _isLastPage = false;
  bool _isLoadingRegion = false;

  final List<OnboardingModel> _pages = [
    OnboardingModel(
      title: "Smart AI Study Assistant",
      description: "Upload syllabus, books, or notes. AI will summarize them instantly.",
      lottieFile: "assets/animations/ai_study.json",
      fallbackIcon: Icons.auto_stories_rounded,
    ),
    OnboardingModel(
      title: "Targeted Prep",
      description: "Your Region, Your Exam. Tailored study material designed for your local curriculum and career goals.",
      lottieFile: "assets/animations/targeted_prep.json",
      fallbackIcon: Icons.public,
    ),
  ];

  // 🌍 1. Secure IP Detection Logic
  Future<String> _detectCountry() async {
    try {
      final response = await http.get(Uri.parse('https://api.country.is')).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String detected = data['country'] ?? 'US';
        debugPrint("🌍 IP Detected: $detected");
        return detected; 
      }
    } catch (e) {
      debugPrint("IP Detect Error: $e");
    }
    return 'US'; // Fallback
  }

  // 🛠️ 2. Smart Confirmation Logic
  Future<void> _handleGetStarted() async {
    setState(() => _isLoadingRegion = true);
    String detectedCode = await _detectCountry();
    setState(() => _isLoadingRegion = false);

    if (!mounted) return;

    Country? detectedCountry = Country.tryParse(detectedCode);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return SingleChildScrollView( 
          child: Padding(
            padding: EdgeInsets.only(
              top: 24.0, 
              left: 24.0, 
              right: 24.0, 
              bottom: MediaQuery.of(context).viewInsets.bottom + 24.0
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1a237e).withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.public, color: Color(0xFF1a237e), size: 40),
                ),
                const SizedBox(height: 20),
                Text("Is this your region?", 
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(detectedCountry?.flagEmoji ?? "🌍", style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Text(detectedCountry?.displayNameNoCountryCode ?? detectedCode, 
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1a237e))),
                  ],
                ),
                const SizedBox(height: 10),
                Text("We detected this location based on your IP. If you are using a VPN, you can change it.", 
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.grey.shade600, fontSize: 14)),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1a237e),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context); 
                      _finalizeSetup(detectedCode); 
                    },
                    child: Text("Yes, Continue", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context); 
                      _openManualPicker(detectedCode); 
                    },
                    child: Text("No, Select Manually", style: GoogleFonts.outfit(color: Colors.black87, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openManualPicker(String detectedCode) {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      countryListTheme: CountryListThemeData(
        flagSize: 25,
        backgroundColor: Colors.white,
        textStyle: GoogleFonts.outfit(fontSize: 16),
        bottomSheetHeight: 600,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        inputDecoration: InputDecoration(
          labelText: 'Search Country',
          hintText: 'Start typing to search',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderSide: BorderSide(color: const Color(0xFF1a237e).withOpacity(0.2))),
        ),
      ),
      favorite: [detectedCode, 'US', 'GB', 'CA'], 
      onSelect: (Country country) {
        _finalizeSetup(country.countryCode);
      },
    );
  }

  // ✅ UPDATED: Database Update Logic Added
  Future<void> _finalizeSetup(String countryCode) async {
    try {
      // 1. Local Hive Update
      var box = Hive.isBoxOpen('user_prefs') ? Hive.box('user_prefs') : await Hive.openBox('user_prefs');
      await box.put('seen_onboarding', true);
      await box.put('target_audience', countryCode);
      
      debugPrint("✅ Local Prefs Saved: $countryCode");

      // 2. Supabase Update (Anonymous ya Login dono ke liye) 🚀
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId != null) {
        debugPrint("🛠 Updating Supabase 'country' for User: $userId");
        
        await supabase
            .from('profiles')
            .update({'country': countryCode}) // Table column 'country' update ho rahi hai
            .eq('id', userId);
            
        debugPrint("✨ Database Country Updated: $countryCode");
      } else {
        debugPrint("⚠️ Supabase Update Skipped: No authenticated User ID found.");
      }
      
      if (mounted) context.go('/subscription'); 
      
    } catch (e) {
      debugPrint("❌ Error finalizing setup: $e");
      if (mounted) context.go('/subscription'); 
    }
  }

  @override
  Widget build(BuildContext context) {
    const mainColor = Color(0xFF1a237e);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (index) => setState(() => _isLastPage = index == _pages.length - 1),
            itemCount: _pages.length,
            itemBuilder: (context, index) => _buildPage(_pages[index], mainColor),
          ),
          Positioned(
            bottom: 40, left: 24, right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SmoothPageIndicator(
                    controller: _controller, count: _pages.length,
                    effect: const ExpandingDotsEffect(activeDotColor: mainColor, dotHeight: 8, dotWidth: 8, spacing: 6)),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isLastPage ? 160 : 60,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isLoadingRegion 
                      ? null 
                      : () {
                          if (_isLastPage) {
                            _handleGetStarted();
                          } else {
                            _controller.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                          }
                        },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mainColor,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_isLastPage ? 16 : 30)),
                    ),
                    child: _isLoadingRegion
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : (_isLastPage
                            ? Text("Get Started", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))
                            : const Icon(Icons.arrow_forward_rounded, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingModel page, Color themeColor) {
     return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Center(
              child: Lottie.asset(
                page.lottieFile,
                width: 300,
                fit: BoxFit.contain, 
                errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(color: themeColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(page.fallbackIcon, size: 80, color: themeColor),
                    );
                },
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(page.title, textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2)),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(page.description, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey.shade600, height: 1.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingModel {
  final String title;
  final String description;
  final String lottieFile;
  final IconData fallbackIcon;
  OnboardingModel({required this.title, required this.description, required this.lottieFile, required this.fallbackIcon});
}