// === private_chat_page.dart (支持点击头像跳转版 - 完整代码) ===

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'user_profile_page.dart'; // 👈 导入新页面

class PrivateChatPage extends StatefulWidget {
  final int currentUserId;
  final int otherUserId;
  final String otherUserNickname;
  final String otherUserAvatar;
  final String currentUserAvatar;

  const PrivateChatPage({
    super.key,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUserNickname,
    required this.otherUserAvatar,
    required this.currentUserAvatar,
  });

  @override
  State<PrivateChatPage> createState() => _PrivateChatPageState();
}

class _PrivateChatPageState extends State<PrivateChatPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _timer;
  int? _conversationId;

  // ！！！！请务必替换为您自己的IP地址！！！！
  final String _apiUrl = 'http://192.168.23.18:3000';

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    await _fetchConversationId();
    if (_conversationId != null) {
      await _fetchMessages(isInitialLoad: true);
      _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (mounted) _fetchMessages();
      });
    } else {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _fetchConversationId() async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/conversation/find-or-create/${widget.currentUserId}/${widget.otherUserId}'));
      if(mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _conversationId = data['conversationId'];
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('进入对话失败: $e')));
    }
  }

  Future<void> _fetchMessages({bool isInitialLoad = false}) async {
    if (_conversationId == null) {
      if(isInitialLoad && mounted) setState(() { _isLoading = false; });
      return;
    }
    if (isInitialLoad && mounted) setState(() { _isLoading = true; });

    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/messages/$_conversationId'));

      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        final newMessages = data as List;

        if (jsonEncode(_messages) != jsonEncode(newMessages)) {
          setState(() {
            _messages = newMessages;
          });
          _scrollToBottom(isAnimated: !isInitialLoad && newMessages.isNotEmpty);
        } else if (isInitialLoad) {
          _scrollToBottom(isAnimated: false);
        }
      }

      if (isInitialLoad) {
        await http.put(Uri.parse('$_apiUrl/api/messages/mark-read/$_conversationId/${widget.currentUserId}'));
      }
    } catch (e) {
      if (!isInitialLoad) return;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载消息失败: $e')));
    } finally {
      if (isInitialLoad && mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _sendMessage() async {
    if (_textController.text.trim().isEmpty || _isSending) return;
    if (_conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在建立连接，请稍后重试...')));
      return;
    }

    final content = _textController.text.trim();
    _textController.clear();
    setState(() { _isSending = true; });

    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/messages/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'senderId': widget.currentUserId,
          'receiverId': widget.otherUserId,
          'content': content,
        }),
      ).timeout(const Duration(seconds: 20));

      if (mounted) {
        if (response.statusCode == 201) {
          await _fetchMessages();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('发送失败')));
        }
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('网络错误，发送失败: $e')));
    } finally {
      if(mounted) setState(() { _isSending = false; });
    }
  }

  void _scrollToBottom({bool isAnimated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _scrollController.position.hasContentDimensions) {
        final position = _scrollController.position.maxScrollExtent;
        if (isAnimated) {
          _scrollController.animateTo(
            position,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(position);
        }
      }
    });
  }

  // 封装跳转到资料页的方法
  void _navigateToProfile(int userId, String nickname, String avatar) {
    Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UserProfilePage(
          currentUserId: widget.currentUserId,
          targetUserId: userId,
          nickname: nickname,
          avatarUrl: avatar,
          introduction: "", // 聊天页暂时不传简介，进页面后再获取
          myAvatarUrl: widget.currentUserAvatar,
        ))
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // 保持加载状态
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(isAnimated: false);
      });
    }

    return Scaffold(
      // 👇👇👇 核心修改 1：点击标题栏跳转资料页 👇👇👇
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _navigateToProfile(widget.otherUserId, widget.otherUserNickname, widget.otherUserAvatar),
          child: Row(
            mainAxisSize: MainAxisSize.min, // 紧凑布局
            children: [
              Text(widget.otherUserNickname),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? const Center(child: Text('还没有消息，打个招呼吧！'))
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message['sender_id'] == widget.currentUserId;
                return _buildMessageItem(isMe, message);
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: '发送消息...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      ),
                      onSubmitted: _isSending ? null : (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _isSending ? null : _sendMessage,
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(bool isMe, dynamic message) {
    // 确定头像对应的用户信息
    final avatarUrl = isMe ? widget.currentUserAvatar : widget.otherUserAvatar;
    final userId = isMe ? widget.currentUserId : widget.otherUserId;
    final nickname = isMe ? "我" : widget.otherUserNickname;

    // 👇👇👇 核心修改 2：点击头像跳转 👇👇👇
    Widget avatarWidget = GestureDetector(
      onTap: () => _navigateToProfile(userId, nickname, avatarUrl),
      child: CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(avatarUrl),
      ),
    );

    final children = <Widget>[
      avatarWidget,
      const SizedBox(width: 10),
      Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
          decoration: BoxDecoration(
            color: isMe
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
            ),
          ),
          child: Text(
            message['content'],
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
            ),
          ),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: isMe ? children.reversed.toList() : children,
      ),
    );
  }
}