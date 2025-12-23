import 'dart:convert';
import 'package:http/http.dart' as http;
import 'mood_model.dart';
import 'config.dart';

class MoodService {
  // ！！！！请确保这里的 IP 和你 index.js 运行的电脑 IP 一致！！！！
  final String baseUrl = AppConfig.baseUrl;

  // 1. 提交心情
  Future<String> submitMood({
    required int userId,
    required String moodType,
    required String content,
  }) async {
    final url = Uri.parse('$baseUrl/api/mood');

    print("正在提交心情到: $url"); // 方便调试

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'moodType': moodType,
        'content': content,
      }),
    );

    if (response.statusCode == 200) {
      // 后端返回: { "code": 200, "data": { "aiResponse": "..." } }
      final resBody = jsonDecode(response.body);

      if (resBody['code'] == 200) {
        // 对应 index.js 里的 data: { aiResponse: aiResponseText }
        return resBody['data']['aiResponse'];
      } else {
        throw Exception(resBody['msg'] ?? '未知错误');
      }
    } else {
      throw Exception('服务器错误: ${response.statusCode}');
    }
  }

  // 2. 获取历史记录
  Future<List<MoodRecord>> getHistory(int userId) async {
    final url = Uri.parse('$baseUrl/api/mood/list?userId=$userId');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      // 后端返回: { "code": 200, "data": [ ...数组... ] }
      final resBody = jsonDecode(response.body);

      if (resBody['code'] == 200) {
        final List<dynamic> list = resBody['data'];
        // 将数组里的每一项转为 MoodRecord 对象
        return list.map((e) => MoodRecord.fromJson(e)).toList();
      } else {
        return []; // 如果 code 不是 200，暂时返回空列表
      }
    } else {
      throw Exception('获取历史失败: ${response.statusCode}');
    }
  }
}