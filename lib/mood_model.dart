class MoodRecord {
  final int id;
  final String moodType;
  final String content;
  final String aiResponse;
  final String createdAt;

  MoodRecord({
    required this.id,
    required this.moodType,
    required this.content,
    required this.aiResponse,
    required this.createdAt,
  });

  factory MoodRecord.fromJson(Map<String, dynamic> json) {
    return MoodRecord(
      id: json['id'],
      // --- 关键点：这里必须和 index.js 里的 SQL 查询结果字段一致 ---
      moodType: json['mood_type'],        // 对应 MySQL 的 mood_type
      content: json['content'] ?? '',     // 对应 MySQL 的 content
      aiResponse: json['ai_response'] ?? '', // 对应 MySQL 的 ai_response
      createdAt: json['created_at'] != null
          ? json['created_at'].toString() // 确保转为字符串
          : DateTime.now().toString(),
    );
  }
}