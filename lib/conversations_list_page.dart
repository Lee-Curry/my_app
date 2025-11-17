// === conversations_list_page.dart (最终防崩溃版 v2 - 完整代码) ===

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'private_chat_page.dart';
import 'users_list_page.dart';

class ConversationsListPage extends StatefulWidget {
  final int currentUserId;
  final ValueNotifier<int> unreadCountNotifier; // 【新增】
  const ConversationsListPage({
    super.key,
    required this.currentUserId,
    required this.unreadCountNotifier, // 【新增】
  });


  @override
  State<ConversationsListPage> createState() => _ConversationsListPageState();
}

class _ConversationsListPageState extends State<ConversationsListPage> {
  List<dynamic> _conversations = [];
  bool _isLoading = true;
  String _myAvatarUrl = '';

  final String _apiUrl = 'http://192.168.23.18:3000'; // ！！！！请务必替换为您自己的IP地址！！！！

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    if (mounted && !_isLoading) {
      setState(() { _isLoading = true; });
    }
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/conversations/${widget.currentUserId}'));
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> conversations = data['data'] ?? [];

        // --- 【核心改造】计算总未读数 ---
        int totalUnread = 0;
        for (var convo in conversations) {
          totalUnread += (int.tryParse(convo['unreadCount']?.toString() ?? '0') ?? 0);
        }

        // --- “投递”到信箱 ---
        widget.unreadCountNotifier.value = totalUnread;

        setState(() {
          _conversations = conversations;
        });
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载对话列表失败: $e')));
    } finally {
      if (_myAvatarUrl.isEmpty) await _fetchMyAvatar();
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _fetchMyAvatar() async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/profile/${widget.currentUserId}'));
      if(mounted && response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        if(mounted) setState(() {
          _myAvatarUrl = data['avatar_url'] ?? 'https://images.unsplash.com/photo-1599566150163-29194dcaad36'; // 提供一个安全的默认头像
        });
      }
    } catch (e) {
      print("在对话列表页，获取自己头像失败: $e");
      if(mounted) setState(() {
        _myAvatarUrl = 'https://images.unsplash.com/photo-1599566150163-29194dcaad36'; // 失败时也给一个默认头像
      });
    }
  }

  String _formatTimestamp(dynamic isoTime) {
    if (isoTime == null || isoTime.toString().isEmpty) return '';
    try {
      final time = DateTime.parse(isoTime.toString()).toLocal();
      final now = DateTime.now();

      if (now.year == time.year && now.month == time.month && now.day == time.day) {
        return DateFormat('HH:mm').format(time); // 今天
      } else if (now.difference(time).inDays < 2 && now.day == time.day + 1) {
        return '昨天';
      } else {
        return DateFormat('M/d').format(time); // 更早
      }
    } catch(e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: '发起新聊天',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UsersListPage(currentUserId: widget.currentUserId),
                ),
              );
              // 从用户列表页返回后，也刷新一下对话列表
              _fetchConversations();
            },
          )
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text('还没有任何对话', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 10),
            const Text('点击右上角发起聊天吧！', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchConversations,
      child: ListView.builder(
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final convo = _conversations[index];

          if (convo == null || !(convo is Map)) return Container();

          final int otherUserId = int.tryParse(convo['otherUserId']?.toString() ?? '-1') ?? -1;
          if (otherUserId == -1) return Container();

          final String otherUserNickname = convo['otherUserNickname']?.toString() ?? '未知用户';
          final String otherUserAvatar = convo['otherUserAvatar']?.toString() ?? 'https://images.unsplash.com/photo-1599566150163-29194dcaad36';
          final String lastMessageContent = convo['lastMessageContent']?.toString() ?? '...';
          final int unreadCount = int.tryParse(convo['unreadCount']?.toString() ?? '0') ?? 0;

          return ListTile(
            // --- 【核心改造】leading 部分 ---
            leading: Stack(
              // 允许子组件超出 Stack 的边界
              clipBehavior: Clip.none,
              children: [
                // 1. 底层是我们的头像
                CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(otherUserAvatar),
                  onBackgroundImageError: (_, __) {},
                ),

                // 2. 顶层是未读红点，通过 Positioned 来精确定位
                if (unreadCount > 0)
                  Positioned(
                    top: -4,  // 向上偏移4个像素
                    right: -4, // 向右偏移4个像素
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20), // 确保红点是圆的
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle, // 使用圆形
                        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2), // 添加一个与背景色相同的描边，产生“悬浮”感
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(otherUserNickname, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(lastMessageContent, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: SizedBox(
              width: 80,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTimestamp(convo['lastMessageTime']),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  // 我们把红点从这里移走了，所以这里留一个占位符，保持时间文本的垂直居中
                  const SizedBox(height: 20),
                ],
              ),
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
              _fetchConversations();
            },
          );
        },
      ),
    );
  }
}