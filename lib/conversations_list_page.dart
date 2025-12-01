// === conversations_list_page.dart (群聊+私聊 完美显示版) ===

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:my_app/wechat_group_avatar.dart';
import 'private_chat_page.dart';
import 'group_chat_page.dart'; // 👈 必须导入群聊页面
import 'users_list_page.dart';
import 'friend_requests_page.dart';
import 'web_socket_service.dart';
import 'create_group_page.dart';

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

  int _friendRequestCount = 0;
  // ！！！！请务必替换为您自己的IP地址！！！！
  final String _apiUrl = 'http://192.168.23.18:3000';

  @override
  void initState() {
    super.initState();
    _refreshAllData();
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

  Future<void> _refreshAllData() async {
    await Future.wait([
      _fetchConversations(),
      _fetchFriendRequestCount(),
      if (_myAvatarUrl.isEmpty) _fetchMyAvatar(),
    ]);
  }

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
      // ignore
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
          _isLoading = false;
        });
      }
    } catch (e) {
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
    } catch (e) {}
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline, size: 28),
            offset: const Offset(0, 50),
            onSelected: (value) {
              if (value == 'group') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CreateGroupPage(currentUserId: widget.currentUserId)),
                ).then((_) => _fetchConversations());
              } else if (value == 'add_friend') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UsersListPage(currentUserId: widget.currentUserId)),
                ).then((_) => _fetchConversations());
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'group',
                child: Row(children: [Icon(Icons.chat_bubble_outline), SizedBox(width: 10), Text('发起群聊')]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'add_friend',
                child: Row(children: [Icon(Icons.person_add_alt_1), SizedBox(width: 10), Text('添加朋友')]),
              ),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // 新朋友入口
          InkWell(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => FriendRequestsPage(currentUserId: widget.currentUserId)));
              _refreshAllData();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)))),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.orange[400], borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person_add, color: Colors.white, size: 28)),
                      if (_friendRequestCount > 0)
                        Positioned(
                          top: -5, right: -5,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2)),
                            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                            alignment: Alignment.center,
                            child: Text(_friendRequestCount > 99 ? '99+' : _friendRequestCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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

          // 会话列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _refreshAllData,
              child: _conversations.isEmpty
                  ? Center(child: Text('暂无聊天消息', style: TextStyle(color: Colors.grey[600])))
                  : ListView.builder(
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  final convo = _conversations[index];

                  // 1. 【核心解析】区分群聊和私聊
                  final String type = convo['type'] ?? 'private'; // 'private' or 'group'
                  final String name = convo['name'] ?? '未知';
                  final String avatar = convo['avatar'] ?? '';
                  final int targetId = convo['otherUserId']; // 这里的 otherUserId 在群聊时就是 groupId

                  // 2. 解析最后一条消息内容
                  String lastMsg = convo['lastMessageContent'] ?? '';
                  final String msgType = convo['lastMessageType'] ?? 'text';
                  if (msgType == 'image') lastMsg = '[图片]';
                  else if (msgType == 'video') lastMsg = '[视频]';
                  else if (msgType == 'recalled') lastMsg = '撤回了一条消息';

                  // 群聊默认文案
                  if (lastMsg.isEmpty && type == 'group') lastMsg = '群聊已创建';

                  final int unreadCount = int.tryParse(convo['unreadCount']?.toString() ?? '0') ?? 0;

                  // 1. 解析群头像 URL 字符串
                  List<String> groupAvatars = [];
                  if (type == 'group') {
                    final String urlsStr = convo['groupAvatarUrls'] ?? '';
                    if (urlsStr.isNotEmpty) {
                      groupAvatars = urlsStr.split(',');
                    }
                  }

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 3. 【核心修改】头像展示逻辑
                        type == 'group'
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(4), // 微信群头像是圆角矩形
                          child: WeChatGroupAvatar(
                              avatars: groupAvatars,
                              size: 50
                          ),
                        )
                            : CircleAvatar( // 私聊还是圆形头像
                          radius: 25,
                          backgroundImage: NetworkImage(avatar),
                          backgroundColor: Colors.grey[200],
                        ),

                        if (unreadCount > 0)
                          Positioned(
                            top: -2, right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              alignment: Alignment.center,
                              child: Text(unreadCount > 99 ? '99+' : unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600])),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_formatTimestamp(convo['lastMessageTime']), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                    onTap: () async {
                      // 4. 【核心跳转】根据类型跳不同页面
                      if (type == 'group') {
                        // 跳转群聊
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupChatPage(
                              currentUserId: widget.currentUserId,
                              groupId: targetId, // 群聊时 otherUserId 就是 groupId
                              groupName: name,
                              currentUserAvatar: _myAvatarUrl,
                            ),
                          ),
                        );
                      } else {
                        // 跳转私聊
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PrivateChatPage(
                              currentUserId: widget.currentUserId,
                              otherUserId: targetId,
                              otherUserNickname: name,
                              otherUserAvatar: avatar,
                              currentUserAvatar: _myAvatarUrl,
                            ),
                          ),
                        );
                      }
                      _refreshAllData(); // 返回后刷新列表
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