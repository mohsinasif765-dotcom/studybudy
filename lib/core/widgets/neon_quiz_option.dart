// File: lib/core/widgets/neon_quiz_option.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NeonQuizOption extends StatefulWidget {
  final String text;
  final String letter;
  final bool isSelected;
  final bool isAnswered;
  final bool isCorrect;
  final VoidCallback onTap;

  const NeonQuizOption({
    super.key,
    required this.text,
    required this.letter,
    required this.isSelected,
    required this.isAnswered,
    required this.isCorrect,
    required this.onTap,
  });

  @override
  State<NeonQuizOption> createState() => _NeonQuizOptionState();
}

class _NeonQuizOptionState extends State<NeonQuizOption> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool showNeon = widget.isSelected && !widget.isAnswered;
    bool showResult = widget.isAnswered;

    Color borderColor = Colors.grey.shade300;
    Color bgColor = Colors.white;
    Color textColor = Colors.black87;
    IconData? statusIcon;

    if (showResult) {
      if (widget.isCorrect) {
        borderColor = Colors.green;
        // Updated for new Flutter version
        bgColor = Colors.green.withValues(alpha: 0.1); 
        textColor = Colors.green.shade900;
        statusIcon = Icons.check_circle;
      } else if (widget.isSelected) {
        borderColor = Colors.red;
        // Updated for new Flutter version
        bgColor = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red.shade900;
        statusIcon = Icons.cancel;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: widget.isAnswered ? null : widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _NeonPainter(
                isNeonActive: showNeon,
                animationValue: _controller.value,
                staticColor: borderColor,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  // Border sirf tab dikhao jab neon na ho
                  border: showNeon ? null : Border.all(color: borderColor, width: 2),
                ),
                child: Row(
                  children: [
                    Text(
                      "${widget.letter}. ",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: showNeon ? Colors.blueAccent : textColor,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.text,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: textColor,
                          fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (statusIcon != null) Icon(statusIcon, color: borderColor),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NeonPainter extends CustomPainter {
  final bool isNeonActive;
  final double animationValue;
  final Color staticColor;

  _NeonPainter({
    required this.isNeonActive,
    required this.animationValue,
    required this.staticColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isNeonActive) return;

    final rect = Offset.zero & size;
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(16));
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    // Fixed: 'const' removed and 'magenta' replaced with 'purpleAccent'
    final gradient = SweepGradient(
      colors: [
        Colors.red,
        Colors.blue,
        Colors.green,
        Colors.yellow,
        Colors.purpleAccent, // Use purpleAccent instead of magenta
        Colors.cyan,
        Colors.red,
      ],
      transform: GradientRotation(animationValue * 2 * math.pi),
    );

    // Glow Layer
    paint.shader = gradient.createShader(rect);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(rRect, paint);

    // Sharp Top Layer
    paint.maskFilter = null;
    paint.strokeWidth = 2.0;
    canvas.drawRRect(rRect, paint);
  }

  @override
  bool shouldRepaint(covariant _NeonPainter oldDelegate) => true;
}