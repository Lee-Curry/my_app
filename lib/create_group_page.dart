// === create_group_page.dart (新建) ===
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CreateGroupPage extends StatefulWidget {
  final int currentUserId;
  const CreateGroupPage({super.key, required this.currentUserId});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  List<dynamic> _contacts = [];
  Set<int> _selectedIds = {}; // 选中的人
  final String _apiUrl = 'http://192.168.23.18:3000';

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    final res = await http.get(Uri.parse('$_apiUrl/api/friends/list?userId=${widget.currentUserId}'));
    if (res.statusCode == 200) {
      setState(() {
        _contacts = jsonDecode(res.body)['data'];
      });
    }
  }

  Future<void> _createGroup() async {
    if (_selectedIds.isEmpty) return;

    final nameController = TextEditingController();
    // 弹窗输入群名
    await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("输入群名称"),
          content: TextField(controller: nameController, decoration: const InputDecoration(hintText: "例如：周末约球群")),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
            ElevatedButton(onPressed: () async {
              Navigator.pop(ctx);
              await _submitGroup(nameController.text.isEmpty ? "未命名群聊" : nameController.text);
            }, child: const Text("创建")),
          ],
        )
    );
  }

  Future<void> _submitGroup(String name) async {
    try {
      final res = await http.post(
          Uri.parse('$_apiUrl/api/groups/create'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'ownerId': widget.currentUserId,
            'name': name,
            'memberIds': _selectedIds.toList()
          })
      );
      if (res.statusCode == 200) {
        Navigator.pop(context); // 退出建群页
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('建群成功')));
      }
    } catch(e) { print(e); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("发起群聊"),
        actions: [
          TextButton(
            onPressed: _selectedIds.isEmpty ? null : _createGroup,
            child: Text("确定(${_selectedIds.length})", style: TextStyle(color: _selectedIds.isEmpty ? Colors.grey : Colors.green, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: ListView.builder(
        itemCount: _contacts.length,
        itemBuilder: (context, index) {
          final user = _contacts[index];
          final isSelected = _selectedIds.contains(user['id']);
          return ListTile(
            leading: CircleAvatar(backgroundImage: NetworkImage(user['avatar_url'])),
            title: Text(user['remark'] ?? user['nickname']),
            trailing: Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? Colors.green : Colors.grey),
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