// === users_list_page.dart (好友发现与添加 - 完整代码) ===

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'private_chat_page.dart';
import 'config.dart';

class UsersListPage extends StatefulWidget {
  final int currentUserId;
  const UsersListPage({super.key, required this.currentUserId});

  @override
  State<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends State<UsersListPage> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String _myAvatarUrl = '';
  // ！！！！请务必替换为您自己的IP地址！！！！
  final String _apiUrl = AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _fetchMyAvatar(); // 提前获取自己的头像，以备聊天跳转使用
  }

  // 获取用户列表 (使用 V2 接口，包含好友状态)
  Future<void> _fetchUsers() async {
    setState(() { _isLoading = true; });
    try {
      // ⚠️ 注意：这里调用的是新接口 v2
      final response = await http.get(Uri.parse('$_apiUrl/api/users/v2?currentUserId=${widget.currentUserId}'));
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _users = data['data'];
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载用户失败: $e')));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // 获取自己的头像
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
      print("获取自己头像失败: $e");
    }
  }

  // 发送好友申请
  Future<void> _sendFriendRequest(int targetUserId) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/friends/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requesterId': widget.currentUserId,
          'addresseeId': targetUserId,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['code'] == 200) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('好友申请已发送')));
        _fetchUsers(); // 刷新列表状态
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(body['msg'] ?? '发送失败')));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('网络错误')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('发现好友')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? const Center(child: Text('暂无其他用户'))
          : ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final status = user['friendship_status']; // 'pending', 'accepted', null
          final requesterId = user['requester_id']; // 谁发起的申请

          // 根据状态构建右侧按钮
          Widget trailingWidget;

          if (status == 'accepted') {
            // 1. 已经是好友 -> 显示聊天图标
            trailingWidget = IconButton(
              icon: const Icon(Icons.chat, color: Colors.blue),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrivateChatPage(
                      currentUserId: widget.currentUserId,
                      otherUserId: user['id'],
                      otherUserNickname: user['nickname'],
                      otherUserAvatar: user['avatar_url'],
                      currentUserAvatar: _myAvatarUrl,
                    ),
                  ),
                );
              },
            );
          } else if (status == 'pending') {
            // 2. 申请中
            if (requesterId == widget.currentUserId) {
              // 我发起的
              trailingWidget = const Text("已申请", style: TextStyle(color: Colors.grey, fontSize: 12));
            } else {
              // 对方发起的
              trailingWidget = const Text("对方已申请", style: TextStyle(color: Colors.orange, fontSize: 12));
            }
          } else {
            // 3. 陌生人 -> 显示添加按钮
            trailingWidget = ElevatedButton(
              onPressed: () => _sendFriendRequest(user['id']),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(60, 30),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text("添加"),
            );
          }

          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(user['avatar_url'] ?? ''),
            ),
            title: Text(user['nickname']),
            subtitle: Text(user['introduction'] ?? '这家伙很懒...', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: trailingWidget,
          );
        },
      ),
    );
  }
}