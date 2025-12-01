// === group_info_page.dart (支持群主踢人版) ===
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_profile_page.dart';
import 'group_add_member_page.dart';
import 'group_remove_member_page.dart'; // 👈 导入踢人页面

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
  bool _isOwner = false; // 是否是群主

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
        final json = jsonDecode(res.body)['data'];
        final int ownerId = json['ownerId'];
        final List list = json['list'];

        if (mounted) {
          setState(() {
            _members = list;
            _isOwner = (ownerId == widget.currentUserId); // 判断权限
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToAddMember() async {
    final existingIds = _members.map<int>((m) => m['id'] as int).toList();
    final result = await Navigator.push(context, MaterialPageRoute(
      builder: (context) => GroupAddMemberPage(
        currentUserId: widget.currentUserId,
        groupId: widget.groupId,
        existingMemberIds: existingIds,
      ),
    ));
    if (result == true) _fetchMembers();
  }

  // 👇 跳转踢人页面
  Future<void> _navigateToRemoveMember() async {
    final result = await Navigator.push(context, MaterialPageRoute(
      builder: (context) => GroupRemoveMemberPage(
        currentUserId: widget.currentUserId,
        groupId: widget.groupId,
        members: _members,
      ),
    ));
    if (result == true) _fetchMembers();
  }

  Future<void> _handleMemberTap(int targetUserId, String nickname, String avatar) async {
    if (targetUserId == widget.currentUserId) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(
        currentUserId: widget.currentUserId, targetUserId: targetUserId, nickname: nickname, avatarUrl: avatar, introduction: "", myAvatarUrl: "", isFriend: true,
      )));
      return;
    }
    try {
      final res = await http.get(Uri.parse('$_apiUrl/api/friendships/check?userIdA=${widget.currentUserId}&userIdB=$targetUserId'));
      bool isFriend = false;
      if (res.statusCode == 200) isFriend = jsonDecode(res.body)['isFriend'];
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(
          currentUserId: widget.currentUserId, targetUserId: targetUserId, nickname: nickname, avatarUrl: avatar, introduction: "", myAvatarUrl: "", isFriend: isFriend,
        )));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无法获取用户信息')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 列表项总数：成员数 + 1个加号 + (如果是群主 ? 1个减号 : 0)
    int itemCount = _members.length + 1 + (_isOwner ? 1 : 0);

    return Scaffold(
      appBar: AppBar(title: Text("群聊信息(${_members.length})")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.75,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // 1. 显示成员头像
          if (index < _members.length) {
            final member = _members[index];
            return GestureDetector(
              onTap: () => _handleMemberTap(member['id'], member['nickname'], member['avatar_url']),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(member['avatar_url'] ?? '', width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c,e,s)=>Container(color:Colors.grey,width:50,height:50)),
                  ),
                  const SizedBox(height: 4),
                  Text(member['nickname'], style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            );
          }

          // 2. 显示加号 (+)
          if (index == _members.length) {
            return GestureDetector(
              onTap: _navigateToAddMember,
              child: Column(
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey[400]!), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.add, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            );
          }

          // 3. 显示减号 (-) —— 只有群主能看见，且排在最后
          if (_isOwner && index == _members.length + 1) {
            return GestureDetector(
              onTap: _navigateToRemoveMember,
              child: Column(
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey[400]!), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.remove, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}