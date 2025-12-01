// === group_add_member_page.dart (邀请好友入群) ===
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GroupAddMemberPage extends StatefulWidget {
  final int currentUserId;
  final int groupId;
  final List<int> existingMemberIds; // 已经在群里的人

  const GroupAddMemberPage({
    super.key,
    required this.currentUserId,
    required this.groupId,
    required this.existingMemberIds,
  });

  @override
  State<GroupAddMemberPage> createState() => _GroupAddMemberPageState();
}

class _GroupAddMemberPageState extends State<GroupAddMemberPage> {
  List<dynamic> _contacts = [];
  Set<int> _selectedIds = {};
  final String _apiUrl = 'http://192.168.23.18:3000'; // 替换IP

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    try {
      final res = await http.get(Uri.parse('$_apiUrl/api/friends/list?userId=${widget.currentUserId}'));
      if (res.statusCode == 200) {
        final List<dynamic> allFriends = jsonDecode(res.body)['data'];

        // 过滤掉已经在群里的人
        if (mounted) {
          setState(() {
            _contacts = allFriends.where((u) => !widget.existingMemberIds.contains(u['id'])).toList();
          });
        }
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _submitAdd() async {
    if (_selectedIds.isEmpty) return;

    try {
      final res = await http.post(
          Uri.parse('$_apiUrl/api/groups/add-members'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'groupId': widget.groupId,
            'memberIds': _selectedIds.toList(),
            // 👇👇👇 新增这一行：告诉后端是谁发起的邀请 👇👇👇
            'operatorId': widget.currentUserId,
          })
      );

      if (res.statusCode == 200) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('邀请成功')));
          Navigator.pop(context, true); // 返回 true 表示需要刷新
        }
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('邀请失败')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("邀请好友"),
        actions: [
          TextButton(
            onPressed: _selectedIds.isEmpty ? null : _submitAdd,
            child: Text("确定(${_selectedIds.length})",
                style: TextStyle(color: _selectedIds.isEmpty ? Colors.grey : Colors.green, fontWeight: FontWeight.bold)
            ),
          )
        ],
      ),
      body: _contacts.isEmpty
          ? const Center(child: Text("没有可邀请的好友"))
          : ListView.builder(
        itemCount: _contacts.length,
        itemBuilder: (context, index) {
          final user = _contacts[index];
          final isSelected = _selectedIds.contains(user['id']);
          // 优先显示备注
          final displayName = (user['remark'] != null && user['remark'].toString().isNotEmpty)
              ? user['remark']
              : user['nickname'];

          return ListTile(
            leading: CircleAvatar(backgroundImage: NetworkImage(user['avatar_url'])),
            title: Text(displayName),
            trailing: Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? Colors.green : Colors.grey
            ),
            onTap: () {
              setState(() {
                if (isSelected) _selectedIds.remove(user['id']);
                else _selectedIds.add(user['id']);
              });
            },
          );
        },
      ),
    );
  }
}