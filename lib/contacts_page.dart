// === contacts_page.dart (通讯录 - 完整代码) ===
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/user_profile_page.dart';
import 'dart:convert';
import 'private_chat_page.dart'; // 点击好友直接聊天

class ContactsPage extends StatefulWidget {
  final int currentUserId;
  const ContactsPage({super.key, required this.currentUserId});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<dynamic> _contacts = [];
  bool _isLoading = true;
  String _myAvatarUrl = '';

  // ！！！！请务必替换为您自己的IP地址！！！！
  final String _apiUrl = 'http://192.168.23.18:3000';

  @override
  void initState() {
    super.initState();
    _fetchContacts();
    _fetchMyAvatar();
  }

  // 获取通讯录列表
  Future<void> _fetchContacts() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse(
          '$_apiUrl/api/friends/list?userId=${widget.currentUserId}'));
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _contacts = data['data'];
        });
      }
    } catch (e) {
      // error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 获取自己的头像（用于跳转聊天）
  Future<void> _fetchMyAvatar() async {
    try {
      final response = await http.get(
          Uri.parse('$_apiUrl/api/profile/${widget.currentUserId}'));
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        setState(() => _myAvatarUrl = data['avatar_url'] ?? '');
      }
    } catch (e) {
      // ignore
    }
  }

  // 删除好友
  Future<void> _deleteFriend(int friendId, String nickname) async {
    try {
      final response = await http.delete(
        Uri.parse('$_apiUrl/api/friends/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'myUserId': widget.currentUserId,
          'friendUserId': friendId,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已删除好友 $nickname')));
        _fetchContacts(); // 刷新列表
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('删除失败')));
    }
  }

  // 显示删除确认框
  void _showDeleteConfirmDialog(int friendId, String nickname) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("删除联系人"),
          content: Text("确定要删除好友“$nickname”吗？同时将删除聊天记录。"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("取消", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // 关闭弹窗
                _deleteFriend(friendId, nickname); // 执行删除
              },
              child: const Text("删除", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('通讯录')),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _contacts.isEmpty
            ? Center(child: Text(
            '暂无联系人', style: TextStyle(color: Colors.grey[600])))
            : RefreshIndicator(
          onRefresh: _fetchContacts,
          child: ListView.separated(
            itemCount: _contacts.length,
            separatorBuilder: (context, index) =>
            const Divider(height: 1, indent: 70), // 仿微信分割线
            // 修改 ListView.separated 的 itemBuilder
            itemBuilder: (context, index) {
              final user = _contacts[index];

              // 包裹 Dismissible 实现侧滑删除
              return Dismissible(
                key: Key(user['id'].toString()),
                // 必须有唯一Key
                direction: DismissDirection.endToStart,
                // 只能从右向左滑
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  // 弹出确认框，返回 true 才会执行 onDismissed
                  return await showDialog(
                    context: context,
                    builder: (ctx) =>
                        AlertDialog(
                          title: const Text("删除好友"),
                          content: Text("确定删除 ${user['nickname']} 吗？"),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text("取消")),
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text("删除",
                                    style: TextStyle(color: Colors.red))),
                          ],
                        ),
                  );
                },
                onDismissed: (direction) {
                  // 这里执行删除逻辑
                  _deleteFriend(user['id'], user['nickname']);
                },
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(user['avatar_url'] ?? ''),
                  ),
                  title: Text(user['nickname'], style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
                  onTap: () {
                    // 👇👇👇 修改：点击不再直接聊天，而是去资料页 👇👇👇
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            UserProfilePage(
                              currentUserId: widget.currentUserId,
                              targetUserId: user['id'],
                              nickname: user['nickname'],
                              avatarUrl: user['avatar_url'],
                              introduction: user['introduction'] ?? '',
                              myAvatarUrl: _myAvatarUrl,
                            ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        )
    );
  }
}