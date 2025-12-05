class SummaryModel {
  final String title;
  final String emoji;
  final String readingTime;
  final List<String> keyPoints;
  final String summaryMarkdown;

  SummaryModel({
    required this.title,
    required this.emoji,
    required this.readingTime,
    required this.keyPoints,
    required this.summaryMarkdown,
  });

  factory SummaryModel.fromJson(Map<String, dynamic> json) {
    return SummaryModel(
      title: json['title'] ?? 'Untitled',
      emoji: json['emoji'] ?? '📄',
      readingTime: json['reading_time'] ?? '2 min',
      keyPoints: List<String>.from(json['key_points'] ?? []),
      summaryMarkdown: json['summary_markdown'] ?? '',
    );
  }
}