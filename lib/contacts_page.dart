// === contacts_page.dart (备注优先显示 + 双重搜索版) ===
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_profile_page.dart';
import 'config.dart';

class ContactsPage extends StatefulWidget {
  final int currentUserId;
  const ContactsPage({super.key, required this.currentUserId});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<dynamic> _allContacts = [];
  List<dynamic> _filteredContacts = [];

  bool _isLoading = true;
  String _myAvatarUrl = '';

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  final String _apiUrl = AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
    _fetchMyAvatar();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 👇👇👇 核心修改：搜索逻辑升级 👇👇👇
  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredContacts = List.from(_allContacts);
      } else {
        _filteredContacts = _allContacts.where((user) {
          // 获取原名和备注
          final nickname = (user['nickname'] ?? '').toString().toLowerCase();
          final remark = (user['remark'] ?? '').toString().toLowerCase();

          // 只要有一个包含搜索词，就保留 (OR 逻辑)
          return nickname.contains(query) || remark.contains(query);
        }).toList();
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredContacts = List.from(_allContacts);
      }
    });
  }

  Future<void> _fetchContacts() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/friends/list?userId=${widget.currentUserId}'));
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _allContacts = data['data'];
          _filteredContacts = List.from(_allContacts);
        });
      }
    } catch (e) {
      // error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMyAvatar() async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/profile/${widget.currentUserId}'));
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        setState(() => _myAvatarUrl = data['avatar_url'] ?? '');
      }
    } catch (e) { }
  }

  Future<void> _deleteFriend(int friendId, String name) async {
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
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已删除好友 $name')));
        _fetchContacts();
        if (_isSearching) _toggleSearch();
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除失败')));
    }
  }

  void _showDeleteConfirmDialog(int friendId, String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("删除联系人"),
          content: Text("确定要删除“$name”吗？同时将删除聊天记录。"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("取消", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteFriend(friendId, name);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchBgColor = isDark ? Colors.grey[800] : Colors.grey[200];

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? Container(
          height: 40,
          decoration: BoxDecoration(color: searchBgColor, borderRadius: BorderRadius.circular(20)),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: "搜索好友备注或昵称...",
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              suffixIcon: _searchController.text.isNotEmpty
                  ? GestureDetector(onTap: () => _searchController.clear(), child: const Icon(Icons.cancel, color: Colors.grey, size: 18))
                  : null,
            ),
          ),
        )
            : const Text('通讯录'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: _filteredContacts.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_search, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text(_isSearching ? "没有找到匹配的好友" : "暂无联系人", style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _fetchContacts,
              child: ListView.separated(
                itemCount: _filteredContacts.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
                itemBuilder: (context, index) {
                  final user = _filteredContacts[index];

                  // 👇👇👇 核心修改：显示逻辑 👇👇👇
                  final hasRemark = user['remark'] != null && user['remark'].toString().isNotEmpty;
                  final displayName = hasRemark ? user['remark'] : user['nickname'];

                  return Dismissible(
                    key: Key(user['id'].toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("删除好友"),
                          content: Text("确定删除“$displayName”吗？"),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("取消")),
                            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text("删除", style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) {
                      _deleteFriend(user['id'], displayName);
                    },
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(user['avatar_url'] ?? ''),
                      ),
                      // 主标题显示：优先备注
                      title: Text(
                          displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                      // 副标题显示：如果有备注，这里就显示原昵称 (仿微信)
                      subtitle: hasRemark
                          ? Text("昵称: ${user['nickname']}", style: TextStyle(color: Colors.grey[500], fontSize: 12))
                          : null,

                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfilePage(
                              currentUserId: widget.currentUserId,
                              targetUserId: user['id'],
                              nickname: user['nickname'],
                              avatarUrl: user['avatar_url'],
                              introduction: user['introduction'] ?? '',
                              myAvatarUrl: _myAvatarUrl,
                            ),
                          ),
                        ).then((_) {
                          // 从资料页回来后刷新一下，万一改了备注
                          _fetchContacts();
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}