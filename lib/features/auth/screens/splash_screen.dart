import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studybudy_ai/core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  bool _isFading = false;
  late AnimationController _rotationController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _startLoading();
  }

  void _startLoading() {
    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      setState(() {
        if (_progress >= 1.0) {
          timer.cancel();
          _triggerTransition();
        } else {
          _progress += (Random().nextDouble() * 0.15);
          if (_progress > 1.0) _progress = 1.0;
        }
      });
    });
  }

  void _triggerTransition() {
    setState(() => _isFading = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 700),
        opacity: _isFading ? 0.0 : 1.0,
        child: Stack(
          children: [
            // 1. BACKGROUND EFFECTS
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Fixed: withValues used instead of withOpacity
                  color: Colors.indigo.withValues(alpha: 0.2), 
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

            Positioned(
              bottom: -100,
              right: -100,
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Fixed: withValues used
                  color: Colors.purple.withValues(alpha: 0.2),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),

            Positioned.fill(
              child: RotationTransition(
                turns: _rotationController,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.5,
                      colors: [
                        Colors.transparent,
                        Colors.indigo.shade900.withValues(alpha: 0.1), // Fixed
                        Colors.transparent,
                      ],
                      stops: const [0.3, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // 2. MAIN CONTENT
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- LOGO CONTAINER ---
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow Effect
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withValues(alpha: 0.5), // Fixed
                              blurRadius: 50,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      // Glass Box
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          // Fixed: withValues used
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Center(
                          child: Image.network(
                            "https://cdn-icons-png.flaticon.com/512/4712/4712038.png",
                            width: 64,
                            height: 64,
                            // Agar internet na ho to error se bachne ke liye icon dikhayen
                            errorBuilder: (context, error, stackTrace) => 
                              const Icon(Icons.school, size: 50, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 48),

                  // --- TEXT ---
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 40, 
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      children: [
                        const TextSpan(text: "Study"),
                        WidgetSpan(
                          child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF818CF8), Color(0xFFC084FC)],
                            ).createShader(bounds),
                            child: Text(
                              "Buddy",
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: " AI"),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Subtitle (Colors.slate fixed to Colors.blueGrey)
                  Text(
                    "YOUR INTELLIGENT LEARNING COMPANION",
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      letterSpacing: 1.5,
                      color: Colors.blueGrey.shade400, // Fixed: slate -> blueGrey
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // --- PROGRESS BAR ---
                  SizedBox(
                    width: 250,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _progress,
                            minHeight: 6,
                            backgroundColor: Colors.blueGrey.shade800, // Fixed: slate -> blueGrey
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("INITIALIZING CORE...", style: _statusStyle),
                            Text("${(_progress * 100).toInt()}%", style: _statusStyle),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. FOOTER
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  "v1.0.0 • Secure Environment",
                  style: GoogleFonts.sourceCodePro(
                    color: Colors.blueGrey.shade600, // Fixed: slate -> blueGrey
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle get _statusStyle => GoogleFonts.outfit(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    color: Colors.blueGrey.shade500, // Fixed: slate -> blueGrey
    letterSpacing: 1.0,
  );
}