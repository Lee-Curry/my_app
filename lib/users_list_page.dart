// === users_list_page.dart (全新文件) ===

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'private_chat_page.dart'; // 导入私聊页面

class UsersListPage extends StatefulWidget {
  final int currentUserId;
  const UsersListPage({super.key, required this.currentUserId});

  @override
  State<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends State<UsersListPage> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String _myAvatarUrl = ''; // 【新增】
  final String _apiUrl = 'http://192.168.23.18:3000'; // ！！！！请务必替换为您自己的IP地址！！！！

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() { _isLoading = true; });
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/users/list/${widget.currentUserId}'));
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _users = data['data'];
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载用户列表失败: $e')));
    } finally {
      // 【新增】在这里获取自己的头像
      if (_myAvatarUrl.isEmpty) await _fetchMyAvatar();
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // 【新增】获取自己头像的函数
  Future<void> _fetchMyAvatar() async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/profile/${widget.currentUserId}'));
      if(mounted && response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        if(mounted) setState(() {
          _myAvatarUrl = data['avatar_url'] ?? '';
        });
      }
    } catch (e) {
      print("在用户列表页，获取自己头像失败: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发起聊天'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? const Center(child: Text('没有其他用户'))
          : ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(user['avatar_url']),
            ),
            title: Text(user['nickname']),
            trailing: const Icon(Icons.chat_bubble_outline),
            onTap: () {
              // 点击用户，直接跳转到与他的聊天页面
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => PrivateChatPage(
                    currentUserId: widget.currentUserId,
                    otherUserId: user['id'],
                    otherUserNickname: user['nickname'],
                    otherUserAvatar: user['avatar_url'],
                    currentUserAvatar: _myAvatarUrl, // 【修改】传递真实的头像URL
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}