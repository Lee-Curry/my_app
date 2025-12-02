// === group_chat_page.dart (逻辑完全对齐私聊版) ===

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 震动
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart'; // 微信相册
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'user_profile_page.dart';
import 'photo_gallery_page.dart';
import 'media_viewer_page.dart';
import 'web_socket_service.dart';
import 'group_info_page.dart';

class GroupChatPage extends StatefulWidget {
  final int currentUserId;
  final int groupId;
  final String groupName;
  final String currentUserAvatar;

  const GroupChatPage({
    super.key,
    required this.currentUserId,
    required this.groupId,
    required this.groupName,
    required this.currentUserAvatar,
  });

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _showSendButton = false;

  Timer? _timer;
  // ！！！！请务必替换为您自己的IP地址！！！！
  final String _apiUrl = 'http://192.168.23.18:3000';

  get _conversationId => null;

  @override
  void initState() {
    super.initState();
    _fetchMessages(isInitialLoad: true);

    _textController.addListener(() {
      setState(() {
        _showSendButton = _textController.text.trim().isNotEmpty;
      });
    });

    WebSocketService().newMessageNotifier.addListener(_onWsEvent);

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _fetchMessages();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    WebSocketService().newMessageNotifier.removeListener(_onWsEvent);
    _textController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients &&
            _scrollController.position.maxScrollExtent > _scrollController.offset) {
          _scrollToBottom(animated: true);
        }
      });
    }
  }

  void _onWsEvent() {
    if (mounted) _fetchMessages(isWsTrigger: true);
  }

  // --- 核心消息获取 ---
  Future<void> _fetchMessages({bool isInitialLoad = false, bool isWsTrigger = false}) async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/messages/group/${widget.groupId}'));

      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body)['data'];

        // 1. 【核心】倒序排列 (最新消息在 Index 0)
        final List newMessages = (data as List).reversed.toList();

        if (jsonEncode(_messages) != jsonEncode(newMessages)) {
          setState(() { _messages = newMessages; });

          // 如果收到新消息，平滑滚动到底部(0.0)
          // 首次加载不需要滚，因为 reverse:true 默认就在底部
          if (isWsTrigger) {
            _scrollToBottom();
          }
        }
        // 👇👇👇 【核心新增】调用群聊标记已读接口 👇👇👇
        // 只要拉取成功，说明我看过了，就告诉后端把红点消掉
        if (_messages.isNotEmpty) {
          _markGroupRead();
        }
        // 👆👆👆 新增结束 👆👆👆
      }


      if (isInitialLoad) {
        if (mounted) setState(() { _isLoading = false; });
      }
    } catch (e) {
      if (isInitialLoad && mounted) setState(() { _isLoading = false; });
    }
  }

  // 👇👇👇 新增：标记已读函数 👇👇👇
  Future<void> _markGroupRead() async {
    try {
      await http.post(
        Uri.parse('$_apiUrl/api/groups/mark-read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': widget.currentUserId,
          'groupId': widget.groupId,
        }),
      );
      // 这里不需要 setState，因为这只影响外面的列表页红点
    } catch (e) {
      print("标记已读失败: $e");
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final position = 0.0;
        if (animated) {
          _scrollController.animateTo(
            position,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuad,
          );
        } else {
          _scrollController.jumpTo(position);
        }
      }
    });
  }

  // --- 发送消息 ---
  Future<void> _sendMessage() async {
    if (!_showSendButton) return;
    final content = _textController.text.trim();
    _textController.clear();
    setState(() { _showSendButton = false; });

    final tempMessage = {
      'id': -1,
      'sender_id': widget.currentUserId,
      'group_id': widget.groupId,
      'content': content,
      'message_type': 'text',
      'media_url': null,
      'created_at': DateTime.now().toString(),
      'nickname': '我',
      'avatar_url': widget.currentUserAvatar
    };

    setState(() {
      _messages.add(tempMessage); // 正序是 add
    });

    _scrollToBottom(animated: true);

    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/messages/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'senderId': widget.currentUserId,
          'groupId': widget.groupId,
          'content': content,
        }),
      );
      if (mounted && response.statusCode == 201) {
        await _fetchMessages();
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('发送失败')));
    }
  }

  // --- 多媒体发送 (完全复刻私聊逻辑) ---
  Future<void> _pickAndSendMedia({required bool isVideo, required bool isCamera}) async {
    List<File> filesToSend = [];

    if (isCamera) {
      // 拍照/录像
      final picker = ImagePicker();
      XFile? file;
      if (isVideo) {
        file = await picker.pickVideo(source: ImageSource.camera);
      } else {
        file = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      }
      if (file != null) filesToSend.add(File(file.path));
    } else {
      // 相册选择 (微信风格)
      try {
        // 👇👇👇 核心逻辑：根据是否点击了“视频”按钮，决定相册里显示什么 👇👇👇
        final RequestType requestType = isVideo ? RequestType.video : RequestType.common;

        final List<AssetEntity>? result = await AssetPicker.pickAssets(
          context,
          pickerConfig: AssetPickerConfig(
            maxAssets: 9,
            requestType: requestType, // 👈 这里控制只显示视频还是显示全部
          ),
        );

        if (result != null) {
          for (var asset in result) {
            final File? file = await asset.file;
            if (file != null) filesToSend.add(file);
          }
        }
      } catch (e) {
        debugPrint("AssetPicker error: $e");
      }
    }

    if (filesToSend.isEmpty) return;

    final bool confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
            title: Text("发送 ${filesToSend.length} 个文件？"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("取消")),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("发送"))
            ]
        )
    ) ?? false;

    if (!confirm) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在后台发送...'), duration: Duration(milliseconds: 1000)));

    int successCount = 0;
    for (var file in filesToSend) {
      final mime = lookupMimeType(file.path);
      // 自动判断类型，或者根据入口强制指定
      final type = (mime != null && mime.startsWith('video/')) ? 'video' : 'image';

      final bool success = await _uploadOneFile(file, type);
      if (success) successCount++;
    }

    if (mounted) {
      if (successCount > 0) {
        await _fetchMessages();
        _scrollToBottom(animated: true);
      }
    }
  }

  Future<bool> _uploadOneFile(File file, String type) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_apiUrl/api/messages/upload'));
      request.fields['senderId'] = widget.currentUserId.toString();
      request.fields['groupId'] = widget.groupId.toString();
      request.fields['messageType'] = type;
      request.files.add(await http.MultipartFile.fromPath('file', file.path, contentType: MediaType.parse(lookupMimeType(file.path) ?? 'application/octet-stream')));
      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 180, // 高度够放三个
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 按钮 1：相册 (图片+视频)
            _buildOptionItem(Icons.image, "相册", () {
              Navigator.pop(ctx);
              _pickAndSendMedia(isVideo: false, isCamera: false);
            }),
            // 按钮 2：拍摄 (默认拍图，可扩展拍视频)
            _buildOptionItem(Icons.camera_alt, "拍摄", () {
              Navigator.pop(ctx);
              _pickAndSendMedia(isVideo: false, isCamera: true);
            }),
            // 按钮 3：视频 (只看视频文件)
            _buildOptionItem(Icons.videocam, "视频", () {
              Navigator.pop(ctx);
              _pickAndSendMedia(isVideo: true, isCamera: false); // 👈 这里的 true 会触发 RequestType.video
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15)), child: Icon(icon, size: 30, color: Colors.black87)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))
        ])
    );
  }

  // --- 撤回 ---
  Future<void> _recallMessage(int messageId) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/messages/recall'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'messageId': messageId, 'userId': widget.currentUserId}),
      );
      if (response.statusCode == 200) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已撤回')));
        _fetchMessages();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('撤回失败')));
    }
  }

  void _showMessageOptions(int messageId) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(margin: const EdgeInsets.only(top: 10, bottom: 20), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ListTile(leading: const Icon(Icons.undo, color: Colors.orange), title: const Text("撤回消息", style: TextStyle(fontWeight: FontWeight.bold)), onTap: () => _recallMessage(messageId)),
            const Divider(height: 1),
            ListTile(leading: const Icon(Icons.close), title: const Text("取消"), onTap: () => Navigator.pop(context)),
            const SizedBox(height: 10),
          ]),
        ),
      ),
    );
  }

  // --- 隐私 & 跳转 ---
  Future<void> _checkFriendAndJump(int targetUserId, String nickname, String avatar) async {
    if (targetUserId == widget.currentUserId) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(
        currentUserId: widget.currentUserId, targetUserId: targetUserId, nickname: nickname, avatarUrl: avatar, introduction: "", myAvatarUrl: widget.currentUserAvatar, isFriend: true,
      )));
      return;
    }
    try {
      final res = await http.get(Uri.parse('$_apiUrl/api/friendships/check?userIdA=${widget.currentUserId}&userIdB=$targetUserId'));
      bool isFriend = false;
      if (res.statusCode == 200) isFriend = jsonDecode(res.body)['isFriend'];
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(
          currentUserId: widget.currentUserId, targetUserId: targetUserId, nickname: nickname, avatarUrl: avatar, introduction: "", myAvatarUrl: widget.currentUserAvatar, isFriend: isFriend,
        )));
      }
    } catch (e) {}
  }

  void _handleAtUser(String nickname) {
    HapticFeedback.mediumImpact();
    setState(() {
      final currentText = _textController.text;
      final textToAdd = "@$nickname ";
      _textController.text = "$currentText$textToAdd";
      _textController.selection = TextSelection.fromPosition(TextPosition(offset: _textController.text.length));
      _showSendButton = true;
    });
    FocusScope.of(context).requestFocus(_inputFocusNode);
  }

  void _viewMedia(String currentUrl) {
    // 查看图片逻辑
    final mediaMessages = _messages.where((m) {
      final type = m['message_type']; return (type == 'image' || type == 'video') && m['media_url'] != null;
    }).toList(); // 正序列表

    final List<MediaItem> galleryItems = mediaMessages.map((m) {
      return MediaItem(
          id: m['id'],
          mediaUrl: m['media_url'],
          mediaType: m['message_type'],
          userNickname: m['nickname'] ?? '未知',
          userAvatarUrl: m['avatar_url'] ?? ''
      );
    }).toList();

    final initialIndex = galleryItems.indexWhere((item) => item.mediaUrl == currentUrl);
    if (initialIndex == -1) return;

    Navigator.push(context, MaterialPageRoute(builder: (_) => MediaViewerPage(mediaItems: galleryItems, initialIndex: initialIndex, viewerId: widget.currentUserId, apiUrl: _apiUrl, isPureView: true)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.groupName}"),
        actions: [
          IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => GroupInfoPage(currentUserId: widget.currentUserId, groupId: widget.groupId, groupName: widget.groupName)));
              }
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            // 3. 【核心布局魔法】Align + ShrinkWrap + Reverse
            child: Align(
              alignment: Alignment.topCenter, // 列表内容少时，强制靠上！
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                reverse: true, // 倒序：保证键盘顶起无延迟，长对话自动到底
                shrinkWrap: true, // 收缩：保证短对话能被 Align 拉到顶部
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
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2)))),
              child: Row(
                children: [
                  Expanded(child: Container(decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white, borderRadius: BorderRadius.circular(24)), child: TextField(controller: _textController, focusNode: _inputFocusNode, minLines: 1, maxLines: 5, decoration: const InputDecoration(hintText: '发送消息...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10))))),
                  const SizedBox(width: 8),
                  _showSendButton
                      ? IconButton(icon: const Icon(Icons.send), onPressed: _isSending ? null : _sendMessage, style: IconButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white))
                      : IconButton(icon: const Icon(Icons.add_circle_outline, size: 30), color: Colors.grey[600], onPressed: _showMediaPicker),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(bool isMe, dynamic message) {
    final String type = message['message_type'] ?? 'text';
    final String content = message['content'] ?? '';

    if (type == 'recalled' || type == 'system') {
      String displayContent = content;
      if (type == 'recalled') displayContent = isMe ? "你撤回了一条消息" : "\"${message['nickname'] ?? '对方'}\" 撤回了一条消息";
      return Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: Text(displayContent, style: const TextStyle(color: Colors.grey, fontSize: 12)))));
    }

    final avatarUrl = isMe ? widget.currentUserAvatar : (message['avatar_url'] ?? '');
    final userId = message['sender_id'];
    final String? mediaUrl = message['media_url'];

    Widget contentWidget;
    if (type == 'image' && mediaUrl != null) {
      contentWidget = GestureDetector(
        onTap: () => _viewMedia(mediaUrl),
        child: Hero(tag: mediaUrl, child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 200, height: 250, child: Image.network(mediaUrl, fit: BoxFit.cover, loadingBuilder: (ctx, child, loading) => loading == null ? child : Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())))))),
      );
    } else if (type == 'video' && mediaUrl != null) {
      contentWidget = GestureDetector(
        onTap: () => _viewMedia(mediaUrl),
        child: SizedBox(width: 200, height: 250, child: GalleryVideoThumbnail(videoUrl: mediaUrl)),
      );
    } else {
      contentWidget = Container(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        decoration: BoxDecoration(color: isMe ? Colors.blue[100] : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white), borderRadius: BorderRadius.circular(8)),
        child: Text(content, style: TextStyle(color: isMe ? Colors.black : Theme.of(context).colorScheme.onSurface, fontSize: 16)),
      );
    }

    if (isMe) {
      contentWidget = GestureDetector(
        onLongPress: () => _showMessageOptions(message['id']),
        child: contentWidget,
      );
    }

    Widget avatarWidget = GestureDetector(
      onTap: () => _checkFriendAndJump(userId, message['nickname'] ?? '未知', avatarUrl),
      onLongPress: isMe ? null : () {
        _handleAtUser(message['nickname'] ?? '未知用户');
      },
      child: CircleAvatar(radius: 20, backgroundImage: NetworkImage(avatarUrl)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(padding: const EdgeInsets.only(left: 50, bottom: 2), child: Text(message['nickname'] ?? '未知', style: const TextStyle(fontSize: 10, color: Colors.grey))),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) ...[avatarWidget, const SizedBox(width: 10)],
              Flexible(child: contentWidget),
              if (isMe) ...[const SizedBox(width: 10), avatarWidget],
            ],
          ),
        ],
      ),
    );
  }
}