// === friend_requests_page.dart (全新文件) ===
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class FriendRequestsPage extends StatefulWidget {
  final int currentUserId;
  const FriendRequestsPage({super.key, required this.currentUserId});

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  List<dynamic> _requests = [];
  bool _isLoading = true;
  final String _apiUrl = AppConfig.baseUrl; // 替换你的IP

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    try {
      final res = await http.get(Uri.parse('$_apiUrl/api/friends/requests?userId=${widget.currentUserId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if(mounted) setState(() {
          _requests = data['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _respond(int requestId, String action) async {
    try {
      await http.post(
        Uri.parse('$_apiUrl/api/friends/respond'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': requestId, 'action': action}),
      );
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(action == 'accepted' ? "已添加好友" : "已忽略申请")));
      }
      _fetchRequests(); // 刷新列表
    } catch (e) {
      // error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("新朋友")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mail_outline, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("暂无好友申请", style: TextStyle(color: Colors.grey[500])),
        ],
      ))
          : ListView.builder(
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final req = _requests[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 24,
              backgroundImage: NetworkImage(req['avatar_url'] ?? ''),
            ),
            title: Text(req['nickname'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(req['introduction'] ?? '请求添加好友'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => _respond(req['request_id'], 'rejected'),
                  child: const Text("忽略", style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _respond(req['request_id'], 'accepted'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text("接受"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}