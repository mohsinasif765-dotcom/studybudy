class OfficialTestModel {
  final String id;
  final String title;
  final String category;
  final String countryCode;
  final String difficulty;
  final int totalQuestions;
  final int creditCost;
  final DateTime createdAt;
  
  // 🔥 NEW: Part Number add kiya hai
  final int partNo; 

  // Constructor
  const OfficialTestModel({
    required this.id,
    required this.title,
    required this.category,
    required this.countryCode,
    required this.difficulty,
    required this.totalQuestions,
    required this.creditCost,
    required this.createdAt,
    required this.partNo, // 🔥 Required
  });

  // Factory Constructor (Safe Parsing for Relational DB 🛡️)
  factory OfficialTestModel.fromJson(Map<String, dynamic> json) {
    
    // 🔥 STEP 1: Total Questions Count nikalna (Relational Check)
    int extractedCount = 0;
    
    if (json['test_questions'] != null) {
      if (json['test_questions'] is List && (json['test_questions'] as List).isNotEmpty) {
        extractedCount = json['test_questions'][0]['count'] ?? 0;
      }
    } else {
      extractedCount = (json['total_questions'] as num?)?.toInt() ?? 0;
    }

    return OfficialTestModel(
      // ID parsing
      id: json['id']?.toString() ?? '',
      
      // Basic Fields
      title: json['title'] as String? ?? 'Untitled Test',
      category: json['category'] as String? ?? 'General',
      countryCode: json['country_code'] as String? ?? 'PK',
      
      // 🛡️ Safe Defaults
      difficulty: json['difficulty'] as String? ?? 'Medium',
      
      // ✅ Count
      totalQuestions: extractedCount,
      
      // 🛡️ Credit Cost
      creditCost: (json['credit_cost'] as num?)?.toInt() ?? 0,
      
      // Date Parsing
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),

      // 🔥 NEW: Part Number Parsing (Database se uthayega)
      // Agar database man null ho, to default 1 lagay ga.
      partNo: (json['part_no'] as num?)?.toInt() ?? 1, 
    );
  }

  // Debugging k liye data wapis map man convert krnay ka function
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'country_code': countryCode,
      'difficulty': difficulty,
      'total_questions': totalQuestions,
      'credit_cost': creditCost,
      'created_at': createdAt.toIso8601String(),
      'part_no': partNo, // 🔥 JSON man bhi add krdia
    };
  }
}