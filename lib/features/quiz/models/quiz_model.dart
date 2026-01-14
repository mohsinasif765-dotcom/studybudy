import 'package:flutter/foundation.dart'; // debugPrint ke liye zaroori

// ==============================================================================
// 1️⃣ QUIZ QUESTION MODEL (UPDATED FOR THEORY & MCQS)
// ==============================================================================
class QuizQuestion {
  final String question;
  
  // MCQ Fields (Existing)
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;
  
  // 🔥 NEW FIELDS (Theory/Question Set ke liye)
  final String? answer; // Detailed Model Answer
  final int? marks;     // Marks (e.g., 5)

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
    this.answer, // Nullable (MCQ mein nahi hoga)
    this.marks,  // Nullable
  });

  // ---------------------------------------------------------------------------
  // 🟢 FACTORY 1: MCQs ke liye (Old Logic - No Changes needed mostly)
  // ---------------------------------------------------------------------------
  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] ?? 'Unknown Question',
      
      // Options safe parsing
      options: json['options'] is List 
          ? List<String>.from(json['options'].map((x) => x.toString()))
          : [],
      
      // Index safe parsing
      correctAnswerIndex: json['correctAnswerIndex'] is int 
          ? json['correctAnswerIndex'] 
          : 0,
      
      explanation: json['explanation'] ?? 'No explanation available.',
      
      // Capture optional theory fields if they exist
      answer: json['answer'],
      marks: json['marks'],
    );
  }

  // ---------------------------------------------------------------------------
  // 🔵 FACTORY 2: THEORY ke liye (🔥 CRITICAL NEW ADDITION)
  // Yeh wo function hai jo Service dhoond raha tha
  // ---------------------------------------------------------------------------
  factory QuizQuestion.fromTheoryJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] ?? 'Unknown Question',
      
      // 🔥 TRICK: Theory mein options nahi hote, isliye empty list bhejo
      // taake app crash na ho (kyunke options required hai)
      options: [], 
      
      // Dummy index (-1 indicate karega ke ye MCQ nahi hai)
      correctAnswerIndex: -1, 
      
      // Agar explanation na ho to answer hi use kar lo context ke liye
      explanation: json['explanation'] ?? 'See model answer.',
      
      // ✅ Main Theory Data
      answer: json['answer'] ?? 'No Answer Provided',
      marks: json['marks'] is int ? json['marks'] : 5, // Default 5 marks
    );
  }

  // ---------------------------------------------------------------------------
  // 💾 METHOD: OBJECT TO JSON (Serialization)
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
      // 🔥 New fields ko bhi save karna zaroori hai
      'answer': answer,
      'marks': marks,
    };
  }
}

// ==============================================================================
// 2️⃣ QUIZ CONFIGURATION MODEL (No Changes needed)
// ==============================================================================
class QuizConfig {
  final String difficulty;
  final String topic;
  final int count;
  final String fileContent;

  QuizConfig({
    required this.difficulty,
    required this.topic,
    required this.count,
    required this.fileContent,
  });

  @override
  String toString() {
    return 'QuizConfig(difficulty: $difficulty, count: $count, topic: $topic)';
  }
}