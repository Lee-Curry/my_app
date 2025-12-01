import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GroupRemoveMemberPage extends StatefulWidget {
  final int currentUserId; // 群主ID (我)
  final int groupId;
  final List<dynamic> members; // 当前群成员列表

  const GroupRemoveMemberPage({
    super.key,
    required this.currentUserId,
    required this.groupId,
    required this.members,
  });

  @override
  State<GroupRemoveMemberPage> createState() => _GroupRemoveMemberPageState();
}

class _GroupRemoveMemberPageState extends State<GroupRemoveMemberPage> {
  Set<int> _selectedIds = {};
  final String _apiUrl = 'http://192.168.23.18:3000'; // 替换IP

  Future<void> _submitRemove() async {
    if (_selectedIds.isEmpty) return;

    try {
      final res = await http.post(
          Uri.parse('$_apiUrl/api/groups/remove-members'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'groupId': widget.groupId,
            'ownerId': widget.currentUserId, // 身份验证
            'memberIds': _selectedIds.toList(),
          })
      );

      if (res.statusCode == 200) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('移除成功')));
          Navigator.pop(context, true); // 返回 true 刷新
        }
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败，可能无权限')));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('网络错误')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 过滤掉自己 (群主不能踢自己)
    final selectableMembers = widget.members.where((m) => m['id'] != widget.currentUserId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("移除成员"),
        actions: [
          TextButton(
            onPressed: _selectedIds.isEmpty ? null : _submitRemove,
            child: Text("确定(${_selectedIds.length})",
                style: TextStyle(color: _selectedIds.isEmpty ? Colors.grey : Colors.red, fontWeight: FontWeight.bold)
            ),
          )
        ],
      ),
      body: selectableMembers.isEmpty
          ? const Center(child: Text("群里没有其他成员"))
          : ListView.builder(
        itemCount: selectableMembers.length,
        itemBuilder: (context, index) {
          final user = selectableMembers[index];
          final isSelected = _selectedIds.contains(user['id']);

          return ListTile(
            leading: CircleAvatar(backgroundImage: NetworkImage(user['avatar_url'])),
            title: Text(user['nickname']),
            trailing: Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? Colors.red : Colors.grey
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