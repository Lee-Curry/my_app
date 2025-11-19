// === private_chat_page.dart (最终异步流程修复版 - 完整代码) ===

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

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

  final String _apiUrl = 'http://192.168.23.18:3000'; // ！！！！请务必替换为您自己的IP地址！！！！

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _timer?.cancel(); // 【修复1】确保定时器被正确取消
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    await _fetchConversationId();
    if (_conversationId != null) {
      await _fetchMessages(isInitialLoad: true);
      // 只有在初始化成功后才启动定时器
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
        print("--- [前端探针] 获取到对话ID: $_conversationId");
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

        // 【核心改造 1】在 setState 之后，再次确保滚动
        if (jsonEncode(_messages) != jsonEncode(newMessages)) {
          setState(() {
            _messages = newMessages;
          });
          // 我们在这里调用滚动，而不是在 setState 内部
          _scrollToBottom(isAnimated: !isInitialLoad && newMessages.isNotEmpty);
        } else if (isInitialLoad) {
          // 如果是首次加载，即使消息没变，也要滚一次
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

  // --- 【核心改造】_sendMessage 函数 ---
  Future<void> _sendMessage() async {
    if (_textController.text.trim().isEmpty || _isSending) return;
    if (_conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在建立连接，请稍后重试...')));
      return;
    }

    final content = _textController.text.trim();
    _textController.clear();
    setState(() { _isSending = true; });

    // 【修复2】不再做乐观更新，避免状态混乱。直接发送请求。
    // 我们将在发送成功后通过 _fetchMessages 来获取最准确的数据。

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
          // 【修复3】发送成功后，立即主动获取一次最新消息列表
          // 这会覆盖掉可能存在的旧状态，并显示包含你新消息的准确列表
          // 【核心改造 1】
          // 不再调用 isInitialLoad: true，避免不必要的加载动画和状态重置
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

  // === 在 private_chat_page.dart 中，用这个新函数替换旧的 _scrollToBottom 函数 ===

  void _scrollToBottom({bool isAnimated = true}) {
    // 【核心改造】使用 addPostFrameCallback，确保滚动在UI渲染完成后执行
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

  @override
  Widget build(BuildContext context) {
    // 【核心改造 2】在 build 完成后，如果这是首次加载，就强制滚动到底部
    if (_isLoading) {
      // 正在加载时，什么都不做
    } else {
      // 加载完成后，（再次）调用滚动
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(isAnimated: false); // 首次进入无动画
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.otherUserNickname)),
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
    final children = <Widget>[
      CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(isMe ? widget.currentUserAvatar : widget.otherUserAvatar),
      ),
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