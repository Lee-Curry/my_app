import 'package:flutter/material.dart';
import 'mood_model.dart'; // 记得导入你的模型

class MoodDetailPage extends StatelessWidget {
  final MoodRecord record;

  const MoodDetailPage({super.key, required this.record});

  // 简单的心情 Emoji 映射（如果在其他地方也有，建议提取成公共常量）
  String _getEmoji(String mood) {
    const map = {
      "开心": "😄", "平静": "☕", "难过": "😢", "焦虑": "🌀", "生气": "😡",
    };
    return map[mood] ?? "😐";
  }

  // 格式化时间函数
  String _formatDate(String isoString) {
    try {
      // 1. 解析字符串为 DateTime 对象
      final DateTime dt = DateTime.parse(isoString);
      // 2. 转换为手机当前的本地时区 (比如北京时间)
      final DateTime localDt = dt.toLocal();

      // 3. 手动拼接成好看的格式: "2025-11-24 16:26"
      // padLeft(2, '0') 的作用是把 "9" 变成 "09"
      String year = localDt.year.toString();
      String month = localDt.month.toString().padLeft(2, '0');
      String day = localDt.day.toString().padLeft(2, '0');
      String hour = localDt.hour.toString().padLeft(2, '0');
      String minute = localDt.minute.toString().padLeft(2, '0');

      return "$year年$month月$day日 $hour:$minute";
    } catch (e) {
      // 如果解析失败，就还显示原来的，避免报错
      return isoString;
    }
  }


  @override
  Widget build(BuildContext context) {
    // 获取当前主题颜色，用于适配深色/浅色模式
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text("心情详情"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 顶部日期和心情大图标
            Center(
              child: Column(
                children: [
                  // 使用 Hero 动画，如果列表页也有 tag，跳转会很丝滑
                  Hero(
                    tag: 'mood_icon_${record.id}',
                    child: Text(
                      _getEmoji(record.moodType),
                      style: const TextStyle(fontSize: 64),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    record.moodType,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 5),

                  // 👇👇👇 修改这一行 👇👇👇
                  Text(
                    _formatDate(record.createdAt), // 这里调用刚才写的函数
                    style: TextStyle(fontSize: 14, color: secondaryTextColor),
                  ),
                  // 👆👆👆 修改结束 👆👆👆
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 2. 用户的日记内容
            Text(
              "我的记录",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                // 给卡片加一点微弱的阴影（仅在浅色模式明显）
                boxShadow: isDark ? [] : [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Text(
                record.content.isEmpty ? "（当时没有写下具体内容）" : record.content,
                style: TextStyle(fontSize: 16, height: 1.6, color: textColor),
              ),
            ),

            const SizedBox(height: 30),

            // 3. AI 的暖心回复
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  "AI 暖心回信",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber[700]),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                // 使用暖色背景，区分于普通内容
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF3E2723), const Color(0xFF1A1A1A)]
                      : [const Color(0xFFFFF8E1), const Color(0xFFFFECB3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Text(
                record.aiResponse,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.amber[100] : Colors.brown[800],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}