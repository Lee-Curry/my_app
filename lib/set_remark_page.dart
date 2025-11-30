// === set_remark_page.dart (设置备注页面) ===
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SetRemarkPage extends StatefulWidget {
  final int myUserId;
  final int friendUserId;
  final String originalNickname;
  final String? initialRemark; // 初始备注

  const SetRemarkPage({
    super.key,
    required this.myUserId,
    required this.friendUserId,
    required this.originalNickname,
    this.initialRemark,
  });

  @override
  State<SetRemarkPage> createState() => _SetRemarkPageState();
}

class _SetRemarkPageState extends State<SetRemarkPage> {
  final TextEditingController _controller = TextEditingController();
  final String _apiUrl = 'http://192.168.23.18:3000'; // 替换IP

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialRemark ?? "";
  }

  Future<void> _saveRemark() async {
    final remark = _controller.text.trim();
    try {
      final res = await http.post(
        Uri.parse('$_apiUrl/api/friends/remark'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'myUserId': widget.myUserId,
          'friendUserId': widget.friendUserId,
          'remark': remark
        }),
      );
      if (res.statusCode == 200) {
        // 返回上一页，并带回新的备注
        if (mounted) Navigator.pop(context, remark);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存失败')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('网络错误')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("设置备注"),
        actions: [
          TextButton(
            onPressed: _saveRemark,
            child: const Text("完成", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text("备注名", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          ),
          Container(
            color: cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _controller,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "添加备注名",
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text("原名: ${widget.originalNickname}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}