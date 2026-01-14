import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prepvault_ai/core/theme/app_colors.dart';

class TranslationSelector extends StatefulWidget {
  final String currentLanguage;
  final Function(String) onSelect;

  const TranslationSelector({
    super.key,
    required this.currentLanguage,
    required this.onSelect,
  });

  @override
  State<TranslationSelector> createState() => _TranslationSelectorState();
}

class _TranslationSelectorState extends State<TranslationSelector> {
  // 👇 Updated List with more languages
  final List<String> _languages = [
    'English', 'Urdu', 'Hindi', 'Arabic', 'Spanish', 
    'French', 'German', 'Chinese (Simplified)', 'Portuguese', 'Russian',
    'Turkish', 'Japanese', 'Korean', 'Italian', 'Bengali', 'Indonesian', 'Persian'
  ];

  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Filter logic
    final filteredLanguages = _languages
        .where((lang) => lang.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75, // Thora aur lamba kiya
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // 1. Handle Bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.translate, color: AppColors.primaryStart),
                  const SizedBox(width: 10),
                  Text(
                    "Translate Summary",
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          
          const SizedBox(height: 20),

          // 3. Search Bar
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: "Search language...",
              prefixIcon: const Icon(Icons.search),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
            ),
          ),

          const SizedBox(height: 16),

          // 4. Language List
          Expanded(
            child: ListView.separated(
              itemCount: filteredLanguages.length,
              separatorBuilder: (c, i) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final lang = filteredLanguages[index];
                final isSelected = widget.currentLanguage == lang;

                return Material( // 👈 Added Material for better touch response
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      // 👇 DEBUG LOG (Check Console when you tap)
                      debugPrint("🟢 [UI] User tapped on language: $lang");
                      
                      // Action Perform
                      widget.onSelect(lang);
                      
                      // Close
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? AppColors.primaryStart.withOpacity(0.1) 
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected 
                            ? Border.all(color: AppColors.primaryStart)
                            : Border.all(color: Colors.transparent),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            lang,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppColors.primaryStart : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle, color: AppColors.primaryStart, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}