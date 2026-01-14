class HistoryItem {
  final String id;
  final String title;
  final String type; // 'summary' or 'quiz'
  final DateTime createdAt;
  final String originalFileName;
  final String status; // 👈 Added Status
  final dynamic content;

  HistoryItem({
    required this.id,
    required this.title,
    required this.type,
    required this.createdAt,
    required this.originalFileName,
    required this.status,
    required this.content,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'].toString(),
      title: json['title'] ?? 'Untitled',
      type: json['type'] ?? 'summary',
      createdAt: DateTime.parse(json['created_at']),
      originalFileName: json['original_file_name'] ?? 'Unknown',
      status: json['status'] ?? 'completed', // Default to completed
      content: json['content'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'created_at': createdAt.toIso8601String(),
      'original_file_name': originalFileName,
      'status': status,
      'content': content,
    };
  }
}