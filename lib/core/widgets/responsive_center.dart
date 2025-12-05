import 'package:flutter/material.dart';

class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveCenter({
    super.key, 
    required this.child, 
    this.maxWidth = 600, // Default width for Auth cards
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    // Screen width check karein
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 800;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? (isDesktop ? EdgeInsets.zero : const EdgeInsets.all(24)),
          child: isDesktop
              ? Container(
                  // Desktop Look: Card style with shadow
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: child,
                )
              : child, // Mobile Look: Normal content (No extra card)
        ),
      ),
    );
  }
}