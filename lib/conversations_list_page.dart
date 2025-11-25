// === conversations_list_page.dart (带好友申请红点版 - 完整代码) ===

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'private_chat_page.dart';
import 'users_list_page.dart';
import 'friend_requests_page.dart';
import 'web_socket_service.dart';

class ConversationsListPage extends StatefulWidget {
  final int currentUserId;
  final ValueNotifier<int> unreadCountNotifier;
  const ConversationsListPage({
    super.key,
    required this.currentUserId,
    required this.unreadCountNotifier,
  });

  @override
  State<ConversationsListPage> createState() => _ConversationsListPageState();
}

class _ConversationsListPageState extends State<ConversationsListPage> {
  List<dynamic> _conversations = [];
  bool _isLoading = true;
  String _myAvatarUrl = '';

  // 1. 【新增】用来存好友申请的数量
  int _friendRequestCount = 0;

  final String _apiUrl = 'http://192.168.23.18:3000'; // 替换你的IP

  @override
  void initState() {
    super.initState();
    _refreshAllData(); // 统一加载数据
    WebSocketService().newMessageNotifier.addListener(_onNewMessageReceived);
  }

  @override
  void dispose() {
    WebSocketService().newMessageNotifier.removeListener(_onNewMessageReceived);
    super.dispose();
  }

  void _onNewMessageReceived() {
    if (WebSocketService().newMessageNotifier.value != null) {
      _refreshAllData();
    }
  }

  // 封装一个刷新所有数据的方法
  Future<void> _refreshAllData() async {
    await Future.wait([
      _fetchConversations(),
      _fetchFriendRequestCount(), // 2. 【新增】每次刷新也获取好友申请数
      if (_myAvatarUrl.isEmpty) _fetchMyAvatar(),
    ]);
  }

  // 3. 【新增】获取好友申请数量的函数
  Future<void> _fetchFriendRequestCount() async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/friends/requests/count?userId=${widget.currentUserId}'));
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _friendRequestCount = data['data']['count'] ?? 0;
        });
      }
    } catch (e) {
      print("获取好友申请数失败: $e");
    }
  }

  Future<void> _fetchConversations() async {
    if (mounted && _conversations.isEmpty) {
      setState(() { _isLoading = true; });
    }
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/conversations/${widget.currentUserId}'));
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> conversations = data['data'] ?? [];

        int totalUnread = 0;
        for (var convo in conversations) {
          totalUnread += (int.tryParse(convo['unreadCount']?.toString() ?? '0') ?? 0);
        }
        widget.unreadCountNotifier.value = totalUnread;

        setState(() {
          _conversations = conversations;
        });
      }
    } catch (e) {
      // error
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

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
      // ignore
    }
  }

  String _formatTimestamp(dynamic isoTime) {
    if (isoTime == null || isoTime.toString().isEmpty) return '';
    try {
      final time = DateTime.parse(isoTime.toString()).toLocal();
      final now = DateTime.now();
      if (now.year == time.year && now.month == time.month && now.day == time.day) {
        return DateFormat('HH:mm').format(time);
      } else if (now.difference(time).inDays < 2 && now.day == time.day + 1) {
        return '昨天';
      } else {
        return DateFormat('M/d').format(time);
      }
    } catch(e) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: '发现好友',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UsersListPage(currentUserId: widget.currentUserId),
                ),
              );
              _refreshAllData();
            },
          )
        ],
      ),
      body: Column(
        children: [
          // === 新朋友入口 (带红点) ===
          InkWell(
            onTap: () async {
              // 点击跳转到申请列表
              await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FriendRequestsPage(currentUserId: widget.currentUserId))
              );
              // 返回时刷新一下，因为可能处理了申请，红点数量要变
              _refreshAllData();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5))),
              ),
              child: Row(
                children: [
                  // 4. 【核心修改】这里使用 Stack 来叠加红点
                  Stack(
                    clipBehavior: Clip.none, // 允许红点超出图标范围
                    children: [
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(color: Colors.orange[400], borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.person_add, color: Colors.white, size: 28),
                      ),

                      // 如果有申请，显示红点
                      if (_friendRequestCount > 0)
                        Positioned(
                          top: -5,
                          right: -5,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2), // 白色描边，增强立体感
                            ),
                            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                            alignment: Alignment.center,
                            child: Text(
                              _friendRequestCount > 99 ? '99+' : _friendRequestCount.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(width: 15),
                  const Text("新朋友", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),

          // === 对话列表 (保持不变) ===
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _refreshAllData, // 下拉刷新时，也会刷新好友红点
              child: _conversations.isEmpty
                  ? Center(child: Text('暂无聊天消息', style: TextStyle(color: Colors.grey[600])))
                  : ListView.builder(
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  final convo = _conversations[index];
                  if (convo == null || !(convo is Map)) return Container();

                  final int otherUserId = int.tryParse(convo['otherUserId']?.toString() ?? '-1') ?? -1;
                  if (otherUserId == -1) return Container();

                  final String otherUserNickname = convo['otherUserNickname']?.toString() ?? '未知用户';
                  final String otherUserAvatar = convo['otherUserAvatar']?.toString() ?? '';
                  final String lastMessageContent = convo['lastMessageContent']?.toString() ?? '...';
                  final int unreadCount = int.tryParse(convo['unreadCount']?.toString() ?? '0') ?? 0;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundImage: NetworkImage(otherUserAvatar),
                          onBackgroundImageError: (_, __) {},
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: -2, right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              alignment: Alignment.center,
                              child: Text(
                                unreadCount > 99 ? '99+' : unreadCount.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(otherUserNickname, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(lastMessageContent, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600])),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_formatTimestamp(convo['lastMessageTime']), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrivateChatPage(
                            currentUserId: widget.currentUserId,
                            otherUserId: otherUserId,
                            otherUserNickname: otherUserNickname,
                            otherUserAvatar: otherUserAvatar,
                            currentUserAvatar: _myAvatarUrl,
                          ),
                        ),
                      );
                      _refreshAllData();
                    },
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