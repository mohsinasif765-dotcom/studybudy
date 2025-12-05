class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
  });

  // JSON se Dart object banane ke liye factory
  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswerIndex: json['correctAnswerIndex'] ?? 0,
      explanation: json['explanation'] ?? '',
    );
  }
}

// User ki settings store karne ke liye
class QuizConfig {
  final String difficulty; // Easy, Medium, Hard
  final String topic;
  final int count;
  final String fileContent; // Base64 string from upload

  QuizConfig({
    required this.difficulty,
    required this.topic,
    required this.count,
    required this.fileContent,
  });
}