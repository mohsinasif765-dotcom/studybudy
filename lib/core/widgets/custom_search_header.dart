// File: lib/core/widgets/custom_search_header.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/scheduler.dart'; 
import 'package:prepvault_ai/core/theme/app_colors.dart'; 

class CustomSearchHeader extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final List<String> categories;
  final String selectedCategory;
  final Function(String) onCategorySelect;
  final bool showFilter;

  const CustomSearchHeader({
    super.key,
    required this.controller,
    this.hintText = "Search...",
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelect,
    this.showFilter = true,
  });

  @override
  State<CustomSearchHeader> createState() => _CustomSearchHeaderState();
}

class _CustomSearchHeaderState extends State<CustomSearchHeader> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _animationValue = 0.0;
  
  // ---- Speed Physics Settings ----
  double _currentSpeed = 0.003; // Idle speed ko thora aur slow aur smooth kiya hai
  final double _baseSpeed = 0.003; 
  final double _maxSpeed = 0.12; // Typing speed
  
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    
    // Ticker hamesha chalta rahega
    _ticker = createTicker((elapsed) {
      setState(() {
        // Friction Logic: Agar speed tez hai to dheeere dheeere base speed par wapis lao
        if (_currentSpeed > _baseSpeed) {
          _currentSpeed *= 0.94; // Decay factor (Jeetna qareeb 1 k, utna smooth slow down)
        } else {
          _currentSpeed = _baseSpeed; // Ensure k base speed se neeche na jaye
        }
        
        // Value update (0 se 1 tak loop)
        _animationValue += _currentSpeed;
        if (_animationValue > 1) _animationValue -= 1; // Better looping than setting to 0
      });
    });

    _ticker.start();

    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
        // Agar focus mila hai, to thora sa speed boost do taake reaction feel ho
        if (_isFocused) {
           _currentSpeed = math.max(_currentSpeed, _baseSpeed * 4);
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onUserTyping(String value) {
    setState(() {
      // 🚀 TYPING BOOST: Speed full kar do!
      _currentSpeed = _maxSpeed;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check karte hain ke kya abhi typing speed effect chal raha hai?
    bool isSpeedBoosted = _currentSpeed > _baseSpeed * 1.5;
    // Active state tab hai jab ya to focus ho, ya abhi speed tez ho (typing k baad ka effect)
    bool isActiveState = _isFocused || isSpeedBoosted;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          // --- NEON BORDER TEXT FIELD ---
          AnimatedBuilder( // Using AnimatedBuilder for cleaner rebuilds based on controller if needed, but here just wrapping custom paint
            animation: Listenable.merge([_focusNode, widget.controller]),
            builder: (context, child) {
               return CustomPaint(
                // Painter ab hamesha paint karega, bas style change hoga
                painter: _ProfessionalNeonPainter(
                  animationValue: _animationValue,
                  isActive: isActiveState,
                ),
                child: Container(
                  // Inner White Box
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      // Jab active ho to transparent, warna halka sa grey border taake shape define rahe
                      color: isActiveState 
                          ? Colors.transparent 
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    onChanged: _onUserTyping,
                    style: GoogleFonts.outfit(fontSize: 16, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: GoogleFonts.outfit(color: Colors.grey.shade400),
                      prefixIcon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.search,
                          key: ValueKey(isActiveState), // Key change hone par animate hoga
                          color: isActiveState ? AppColors.primaryStart : Colors.grey.shade400,
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ),
              );
            }
          ),
          
          // --- Filter List ---
          if (widget.showFilter && widget.categories.isNotEmpty)
            _CategoryFilterList(
              categories: widget.categories,
              selectedCategory: widget.selectedCategory,
              onSelect: widget.onCategorySelect,
            ),
        ],
      ),
    );
  }
}

// 🔥 THE PROFESSIONAL PAINTER
class _ProfessionalNeonPainter extends CustomPainter {
  final double animationValue;
  final bool isActive; // True if focused or typing fast

  _ProfessionalNeonPainter({required this.animationValue, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // --- Professional Dynamic Styling ---
    
    // 1. Thickness: Active pe mota, Idle pe patla
    final double strokeWidth = isActive ? 3.0 : 1.5;
    
    // 2. Opacity/Brightness: Active pe bright, Idle pe dim
    final double opacity = isActive ? 1.0 : 0.35;
    
    // 3. Glow (Blur): Active pe zyada glow, Idle pe kam
    final double blurSigma = isActive ? 5.0 : 2.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Gradient Rotation Logic
    final startAngle = animationValue * 2 * math.pi;

    // Colors with Dynamic Opacity
    final List<Color> neonColors = [
      Colors.transparent,
      AppColors.primaryStart.withOpacity(opacity), 
      Colors.purpleAccent.withOpacity(opacity),
      Colors.cyanAccent.withOpacity(opacity),
      AppColors.primaryStart.withOpacity(opacity),
      Colors.transparent,
    ];

    final gradient = SweepGradient(
      startAngle: 0.0,
      endAngle: 2 * math.pi,
      colors: neonColors,
      stops: const [0.0, 0.1, 0.3, 0.5, 0.7, 1.0], // Stops adjust kiye hain better flow k liye
      transform: GradientRotation(startAngle),
    );

    paint.shader = gradient.createShader(rect);

    // Apply dynamic glow blur
    paint.maskFilter = MaskFilter.blur(BlurStyle.solid, blurSigma);

    canvas.drawRRect(rRect, paint);
  }

  @override
  bool shouldRepaint(covariant _ProfessionalNeonPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.isActive != isActive;
  }
}

// --- Filter List Widget (Same as before) ---
class _CategoryFilterList extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final Function(String) onSelect;

  const _CategoryFilterList({
    required this.categories,
    required this.selectedCategory,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = selectedCategory == cat;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryStart : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
                boxShadow: isSelected
                    ? [BoxShadow(color: AppColors.primaryStart.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                    : [],
              ),
              child: Center(
                child: Text(
                  cat,
                  style: GoogleFonts.outfit(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}