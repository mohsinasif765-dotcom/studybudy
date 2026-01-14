import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';

class SummaryDocumentViewer extends StatelessWidget {
  final String fileName;
  final String content; // Markdown content
  final int wordCount;
  final int readingTime;
  final bool isLoading;

  const SummaryDocumentViewer({
    super.key,
    required this.fileName,
    required this.content,
    required this.wordCount,
    required this.readingTime,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isRTL = RegExp(r'[\u0600-\u06FF]').hasMatch(content);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        // Deep shadow for "Paper on Desk" effect
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          
          // 1. DOCUMENT HEADER (Clean & Minimal)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Icon(Icons.article_outlined, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "DOCUMENT VIEW",
                        style: GoogleFonts.inter(
                          fontSize: 10, 
                          fontWeight: FontWeight.bold, 
                          letterSpacing: 1.5,
                          color: Colors.grey.shade500
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fileName,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. CONTENT AREA (Professional Typography)
          Padding(
            padding: const EdgeInsets.all(40), // More padding for "Paper" feel
            child: isLoading
                ? _buildLoadingSkeleton()
                : Directionality(
                    textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                    child: MarkdownBody(
                      data: content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        // H1 - Big, Bold, Sans-Serif
                        h1: GoogleFonts.spaceGrotesk(
                          fontSize: 32, 
                          fontWeight: FontWeight.bold, 
                          height: 1.3,
                          color: AppColors.primaryStart
                        ),
                        h1Padding: const EdgeInsets.only(top: 24, bottom: 12),
                        
                        // H2 - Slightly smaller, dark
                        h2: GoogleFonts.spaceGrotesk(
                          fontSize: 24, 
                          fontWeight: FontWeight.w600, 
                          height: 1.4,
                          color: isDark ? Colors.white : Colors.black87
                        ),
                        h2Padding: const EdgeInsets.only(top: 24, bottom: 10),

                        // H3
                        h3: GoogleFonts.spaceGrotesk(
                          fontSize: 20, 
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800
                        ),
                        
                        // Body Text - SERIF (Merriweather) for readability
                        p: GoogleFonts.merriweather(
                          fontSize: 17, 
                          height: 1.8, 
                          color: isDark ? Colors.grey.shade300 : const Color(0xFF333333)
                        ),
                        
                        // Blockquote - Stylish Indent
                        blockquote: GoogleFonts.merriweather(
                          color: Colors.grey.shade600, 
                          fontStyle: FontStyle.italic,
                          fontSize: 16,
                        ),
                        blockquoteDecoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: const Border(left: BorderSide(color: AppColors.primaryStart, width: 4)),
                        ),
                        blockquotePadding: const EdgeInsets.all(16),

                        // Code Blocks
                        code: GoogleFonts.firaCode(
                          backgroundColor: isDark ? Colors.black26 : const Color(0xFFF3F4F6),
                          fontSize: 14,
                          color: const Color(0xFFC026D3), // Pinkish code text
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: isDark ? Colors.black26 : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),

                        // Lists
                        listBullet: TextStyle(color: AppColors.primaryStart, fontSize: 16),
                        listIndent: 24,
                      ),
                    ),
                  ),
          ),

          // 3. FOOTER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              color: isDark ? Colors.black12 : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "PrepVault AI Generated",
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                ),
                Text(
                  "$wordCount words",
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Loading Skeleton (Matches the paper padding)
  Widget _buildLoadingSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _skeletonRow(width: 250, height: 32), // H1
        const SizedBox(height: 24),
        _skeletonRow(width: double.infinity, height: 16),
        const SizedBox(height: 10),
        _skeletonRow(width: double.infinity, height: 16),
        const SizedBox(height: 10),
        _skeletonRow(width: 300, height: 16),
        const SizedBox(height: 32),
        _skeletonRow(width: 200, height: 24), // H2
        const SizedBox(height: 16),
        _skeletonRow(width: double.infinity, height: 16),
      ],
    );
  }

  Widget _skeletonRow({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}