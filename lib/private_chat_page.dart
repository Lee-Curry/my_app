// === private_chat_page.dart (神级布局：兼容长短对话 + 完美键盘) ===

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';
import 'user_profile_page.dart';
import 'photo_gallery_page.dart';
import 'media_viewer_page.dart';
import 'web_socket_service.dart';

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
  bool _showSendButton = false;

  Timer? _timer;
  int? _conversationId;
  // ！！！！请务必替换为您自己的IP地址！！！！
  final String _apiUrl = 'http://192.168.23.18:3000';

  @override
  void initState() {
    super.initState();
    // 不需要 WidgetsBindingObserver 了，reverse: true 原生支持键盘
    _initializeChat();
    _textController.addListener(() {
      setState(() { _showSendButton = _textController.text.trim().isNotEmpty; });
    });
    WebSocketService().newMessageNotifier.addListener(_onWsEvent);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WebSocketService().newMessageNotifier.removeListener(_onWsEvent);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onWsEvent() {
    if (mounted) _fetchMessages(isWsTrigger: true);
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
        setState(() { _conversationId = data['conversationId']; });
      }
    } catch (e) {}
  }

  Future<void> _fetchMessages({bool isInitialLoad = false, bool isWsTrigger = false}) async {
    if (_conversationId == null) {
      if(isInitialLoad && mounted) setState(() { _isLoading = false; });
      return;
    }
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/messages/$_conversationId'));
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
      }

      if (isInitialLoad) {
        await http.put(Uri.parse('$_apiUrl/api/messages/mark-read/$_conversationId/${widget.currentUserId}'));
        if (mounted) setState(() { _isLoading = false; });
      }
    } catch (e) {
      if (isInitialLoad && mounted) setState(() { _isLoading = false; });
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            0.0, // 倒序模式下，0.0 就是最底部
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuad,
          );
        } else {
          _scrollController.jumpTo(0.0);
        }
      }
    });
  }

  // 2. 【核心】发送消息：乐观更新 + 秒滑到底
  Future<void> _sendMessage() async {
    if (!_showSendButton) return;
    final content = _textController.text.trim();
    _textController.clear();
    setState(() { _showSendButton = false; });

    final tempMessage = {
      'id': -1,
      'sender_id': widget.currentUserId,
      'receiver_id': widget.otherUserId,
      'content': content,
      'message_type': 'text',
      'media_url': null,
      'created_at': DateTime.now().toString(),
    };

    // 插入到列表头 (即屏幕最下方)
    setState(() {
      _messages.insert(0, tempMessage);
    });

    // 立即滚动到 0.0
    _scrollToBottom(animated: true);

    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/messages/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'senderId': widget.currentUserId,
          'receiverId': widget.otherUserId,
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

  Future<bool> _confirmSendMultiMedia(List<XFile> files, {bool isVideo = false}) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("发送 ${files.length} 个${isVideo ? '视频' : '图片'}？"),
        content: SizedBox(
          width: double.maxFinite,
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: files.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: isVideo
                      ? Container(width: 100, color: Colors.black, child: const Icon(Icons.videocam, color: Colors.white))
                      : Image.file(File(files[index].path), width: 100, height: 100, fit: BoxFit.cover),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消", style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("发送")),
        ],
      ),
    ) ?? false;
  }

  Future<void> _pickAndSendMedia({required bool isVideo, required bool isCamera}) async {
    final picker = ImagePicker();
    List<XFile> selectedFiles = [];

    if (isCamera) {
      final XFile? file = isVideo
          ? await picker.pickVideo(source: ImageSource.camera)
          : await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (file != null) selectedFiles.add(file);
    } else {
      if (isVideo) {
        final XFile? file = await picker.pickVideo(source: ImageSource.gallery);
        if (file != null) selectedFiles.add(file);
      } else {
        selectedFiles = await picker.pickMultiImage(imageQuality: 80);
      }
    }

    if (selectedFiles.isEmpty) return;

    final bool confirm = await _confirmSendMultiMedia(selectedFiles, isVideo: isVideo);
    if (!confirm) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在后台发送...'), duration: Duration(milliseconds: 1000)));

    int successCount = 0;
    for (var xfile in selectedFiles) {
      final bool success = await _uploadOneFile(File(xfile.path), isVideo ? 'video' : 'image');
      if (success) successCount++;
    }

    if (mounted) {
      if (successCount > 0) {
        await _fetchMessages();
        _scrollToBottom(animated: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('发送失败')));
      }
    }
  }

  Future<bool> _uploadOneFile(File file, String type) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_apiUrl/api/messages/upload'));
      request.fields['senderId'] = widget.currentUserId.toString();
      request.fields['receiverId'] = widget.otherUserId.toString();
      request.fields['messageType'] = type;

      final mimeType = lookupMimeType(file.path);
      request.files.add(await http.MultipartFile.fromPath('file', file.path, contentType: MediaType.parse(mimeType ?? 'application/octet-stream')));

      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(margin: const EdgeInsets.only(top: 10, bottom: 20), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ListTile(leading: const Icon(Icons.undo, color: Colors.orange), title: const Text("撤回消息", style: TextStyle(fontWeight: FontWeight.bold)), onTap: () => _recallMessage(messageId)),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.close), title: const Text("取消"), onTap: () => Navigator.pop(context)),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 180,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildOptionItem(Icons.image, "相册", () { Navigator.pop(context); _pickAndSendMedia(isVideo: false, isCamera: false); }),
            _buildOptionItem(Icons.camera_alt, "拍照", () { Navigator.pop(context); _pickAndSendMedia(isVideo: false, isCamera: true); }),
            _buildOptionItem(Icons.videocam, "视频", () { Navigator.pop(context); _pickAndSendMedia(isVideo: true, isCamera: false); }),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, size: 30, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }


  void _navigateToProfile(int userId, String nickname, String avatar) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage(
      currentUserId: widget.currentUserId, targetUserId: userId, nickname: nickname, avatarUrl: avatar, introduction: "", myAvatarUrl: widget.currentUserAvatar,
    )));
  }

  void _viewMedia(String currentUrl) {
    final mediaMessages = _messages.where((m) {
      final type = m['message_type'];
      return (type == 'image' || type == 'video') && m['media_url'] != null;
    }).toList().reversed.toList();
    // 注意：_messages是[新->旧]，这里需要reversed变成[旧->新]给ViewMedia，这样左滑才是历史图片

    final List<MediaItem> galleryItems = mediaMessages.map((m) {
      final isMe = m['sender_id'] == widget.currentUserId;
      return MediaItem(
        id: m['id'], mediaUrl: m['media_url'], mediaType: m['message_type'],
        userNickname: isMe ? "我" : widget.otherUserNickname,
        userAvatarUrl: isMe ? widget.currentUserAvatar : widget.otherUserAvatar,
      );
    }).toList();

    final initialIndex = galleryItems.indexWhere((item) => item.mediaUrl == currentUrl);
    if (initialIndex == -1) return;

    Navigator.push(context, MaterialPageRoute(builder: (_) =>
        MediaViewerPage(
            mediaItems: galleryItems,
            initialIndex: initialIndex,
            viewerId: widget.currentUserId,
            apiUrl: _apiUrl,
            isPureView: true
        )
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _navigateToProfile(widget.otherUserId, widget.otherUserNickname, widget.otherUserAvatar),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _textController,
                        minLines: 1, maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: '发送消息...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
                        ),
                      ),
                    ),
                  ),
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

    if (type == 'recalled') {
      return Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(isMe ? "你撤回了一条消息" : "\"${widget.otherUserNickname}\" 撤回了一条消息", style: const TextStyle(color: Colors.grey, fontSize: 12))));
    }

    final avatarUrl = isMe ? widget.currentUserAvatar : widget.otherUserAvatar;
    final userId = isMe ? widget.currentUserId : widget.otherUserId;
    final String? mediaUrl = message['media_url'];

    Widget contentWidget;

    if (type == 'image' && mediaUrl != null) {
      contentWidget = GestureDetector(
        onTap: () => _viewMedia(mediaUrl),
        // 固定宽高，防止抖动
        child: Hero(tag: mediaUrl, child: ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 200, height: 250, child: Image.network(mediaUrl, fit: BoxFit.cover, loadingBuilder: (ctx, child, loading) => loading == null ? child : Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())))))),
      );
    } else if (type == 'video' && mediaUrl != null) {
      contentWidget = GestureDetector(
        onTap: () => _viewMedia(mediaUrl),
        child: SizedBox(width: 200, height: 250, child: VideoMessageBubble(videoUrl: mediaUrl)),
      );
    } else {
      contentWidget = Container(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue[100] : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(message['content'] ?? '', style: TextStyle(color: isMe ? Colors.black : Theme.of(context).colorScheme.onSurface, fontSize: 16)),
      );
    }

    if (isMe) {
      contentWidget = GestureDetector(
        onLongPress: () => _showMessageOptions(message['id']),
        child: contentWidget,
      );
    }

    Widget avatarWidget = GestureDetector(onTap: () => _navigateToProfile(userId, isMe ? "我" : widget.otherUserNickname, avatarUrl), child: CircleAvatar(radius: 20, backgroundImage: NetworkImage(avatarUrl)));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[avatarWidget, const SizedBox(width: 10)],
          Flexible(child: contentWidget),
          if (isMe) ...[const SizedBox(width: 10), avatarWidget],
        ],
      ),
    );
  }
}

// VideoMessageBubble (保持不变)
class VideoMessageBubble extends StatefulWidget {
  final String videoUrl;
  const VideoMessageBubble({super.key, required this.videoUrl});
  @override
  State<VideoMessageBubble> createState() => _VideoMessageBubbleState();
}
class _VideoMessageBubbleState extends State<VideoMessageBubble> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }
  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await _controller!.initialize();
      if (mounted) setState(() { _isInitialized = true; });
    } catch (e) {}
  }
  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 200, height: 250, color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isInitialized && _controller != null)
              SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _controller!.value.size.width, height: _controller!.value.size.height, child: VideoPlayer(_controller!)))),
            Container(decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle), padding: const EdgeInsets.all(12), child: const Icon(Icons.play_arrow, color: Colors.white, size: 40)),
          ],
        ),
      ),
    );
  }
}