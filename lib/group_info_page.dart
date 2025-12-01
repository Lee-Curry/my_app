// === group_info_page.dart (带加号按钮版) ===
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_profile_page.dart';
import 'group_add_member_page.dart'; // 👈 导入新页面

class GroupInfoPage extends StatefulWidget {
  final int currentUserId;
  final int groupId;
  final String groupName;

  const GroupInfoPage({
    super.key,
    required this.currentUserId,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  List<dynamic> _members = [];
  bool _isLoading = true;
  final String _apiUrl = 'http://192.168.23.18:3000';

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    try {
      final res = await http.get(Uri.parse('$_apiUrl/api/groups/${widget.groupId}/members'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        if (mounted) {
          setState(() {
            _members = data;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 跳转邀请页面
  Future<void> _navigateToAddMember() async {
    // 提取所有已存在的ID，传给选人页面做过滤
    final existingIds = _members.map<int>((m) => m['id'] as int).toList();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupAddMemberPage(
          currentUserId: widget.currentUserId,
          groupId: widget.groupId,
          existingMemberIds: existingIds,
        ),
      ),
    );

    // 如果返回 true，说明添加了人，刷新列表
    if (result == true) {
      _fetchMembers();
    }
  }

  Future<void> _handleMemberTap(int targetUserId, String nickname, String avatar) async {
    if (targetUserId == widget.currentUserId) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(
        currentUserId: widget.currentUserId,
        targetUserId: targetUserId,
        nickname: nickname,
        avatarUrl: avatar,
        introduction: "",
        myAvatarUrl: "",
        isFriend: true,
      )));
      return;
    }

    try {
      final res = await http.get(Uri.parse('$_apiUrl/api/friendships/check?userIdA=${widget.currentUserId}&userIdB=$targetUserId'));
      bool isFriend = false;
      if (res.statusCode == 200) {
        isFriend = jsonDecode(res.body)['isFriend'];
      }

      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(
          currentUserId: widget.currentUserId,
          targetUserId: targetUserId,
          nickname: nickname,
          avatarUrl: avatar,
          introduction: "",
          myAvatarUrl: "",
          isFriend: isFriend,
        )));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无法获取用户信息')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("群聊信息(${_members.length})")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5, // 一行5个
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.75,
        ),
        // 👇 核心：数量+1 (为了放加号)
        itemCount: _members.length + 1,
        itemBuilder: (context, index) {
          // 👇 核心：如果是最后一个，显示加号
          if (index == _members.length) {
            return GestureDetector(
              onTap: _navigateToAddMember,
              child: Column(
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  // 占位，保持对齐
                  const Text("", style: TextStyle(fontSize: 12)),
                ],
              ),
            );
          }

          // 正常显示成员
          final member = _members[index];
          return GestureDetector(
            onTap: () => _handleMemberTap(member['id'], member['nickname'], member['avatar_url']),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    member['avatar_url'] ?? '',
                    width: 50, height: 50, fit: BoxFit.cover,
                    errorBuilder: (c,e,s) => Container(color: Colors.grey, width: 50, height: 50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                    member['nickname'],
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}