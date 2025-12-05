class HistoryItem {
  final String id;
  final String title;
  final String type; // 'summary' or 'quiz'
  final DateTime createdAt;
  final String originalFileName;
  final dynamic content; // JSON content

  HistoryItem({
    required this.id,
    required this.title,
    required this.type,
    required this.createdAt,
    required this.originalFileName,
    required this.content,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'],
      title: json['title'] ?? 'Untitled',
      type: json['type'] ?? 'summary',
      createdAt: DateTime.parse(json['created_at']),
      originalFileName: json['original_file_name'] ?? 'Unknown',
      content: json['content'],
    );
  }
}