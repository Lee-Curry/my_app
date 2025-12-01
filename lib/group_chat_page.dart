// === group_chat_page.dart (修复消息消失 + 群信息入口版) ===

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';
import 'user_profile_page.dart';
import 'photo_gallery_page.dart'; // 导入 GalleryVideoThumbnail
import 'media_viewer_page.dart';
import 'web_socket_service.dart';
import 'group_info_page.dart'; // 👈 导入新页面

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

// 1. 混入 Observer 监听键盘
class _GroupChatPageState extends State<GroupChatPage> with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _showSendButton = false;

  // 2. 隐形加载控制
  double _listOpacity = 0.0;

  Timer? _timer;
  final String _apiUrl = 'http://192.168.23.18:3000';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchMessages(isInitialLoad: true);

    _textController.addListener(() {
      setState(() {
        _showSendButton = _textController.text
            .trim()
            .isNotEmpty;
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
    super.dispose();
  }

  // 键盘弹出处理
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients &&
            _scrollController.position.maxScrollExtent >
                _scrollController.offset) {
          _scrollToBottom(animated: true);
        }
      });
    }
  }

  void _onWsEvent() {
    // 简单判断一下是不是群消息（如果后端WS没带groupId，全量刷新也没事）
    final event = WebSocketService().newMessageNotifier.value;
    if (mounted) _fetchMessages(isWsTrigger: true);
  }

  Future<void> _fetchMessages(
      {bool isInitialLoad = false, bool isWsTrigger = false}) async {
    try {
      final response = await http.get(
          Uri.parse('$_apiUrl/api/messages/group/${widget.groupId}'));

      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body)['data'];

        // 3. 正序排列 [旧 -> 新] (之前你是 reversed，导致逻辑反了)
        final List newMessages = data as List;

        if (jsonEncode(_messages) != jsonEncode(newMessages)) {
          setState(() {
            _messages = newMessages;
          });

          if (isInitialLoad) {
            // 4. 首次加载瞬移逻辑
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(
                    _scrollController.position.maxScrollExtent);
              }
              await Future.delayed(const Duration(milliseconds: 50));
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _listOpacity = 1.0;
                });
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent);
                }
              }
            });
          } else if (isWsTrigger || newMessages.length > _messages.length) {
            _scrollToBottom(animated: true);
          }
        } else if (isInitialLoad) {
          setState(() {
            _isLoading = false;
            _listOpacity = 1.0;
          });
        }
      }
    } catch (e) {
      if (isInitialLoad && mounted) setState(() {
        _isLoading = false;
        _listOpacity = 1.0;
      });
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 50));
      if (_scrollController.hasClients) {
        final position = _scrollController.position.maxScrollExtent;
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

  Future<void> _sendMessage() async {
    if (!_showSendButton) return;
    final content = _textController.text.trim();
    _textController.clear();
    setState(() {
      _showSendButton = false;
    });

    // A. 乐观更新
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
      _messages.add(tempMessage);
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('发送失败')));
    }
  }

  // 隐私跳转
  Future<void> _checkFriendAndJump(int targetUserId, String nickname,
      String avatar) async {
    if (targetUserId == widget.currentUserId) {
      Navigator.push(context, MaterialPageRoute(builder: (_) =>
          UserProfilePage(
            currentUserId: widget.currentUserId,
            targetUserId: targetUserId,
            nickname: nickname,
            avatarUrl: avatar,
            introduction: "",
            myAvatarUrl: widget.currentUserAvatar,
            isFriend: true,
          )));
      return;
    }
    try {
      final res = await http.get(Uri.parse(
          '$_apiUrl/api/friendships/check?userIdA=${widget
              .currentUserId}&userIdB=$targetUserId'));
      bool isFriend = false;
      if (res.statusCode == 200) {
        isFriend = jsonDecode(res.body)['isFriend'];
      }
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) =>
            UserProfilePage(
              currentUserId: widget.currentUserId,
              targetUserId: targetUserId,
              nickname: nickname,
              avatarUrl: avatar,
              introduction: "",
              myAvatarUrl: widget.currentUserAvatar,
              isFriend: isFriend,
            )));
      }
    } catch (e) {}
  }

  // 多媒体发送 (保持原样，仅简化展示)
  Future<void> _pickAndSendMedia({required bool isCamera}) async {
    List<File> filesToSend = [];
    if (isCamera) {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
          source: ImageSource.camera, imageQuality: 80);
      if (file != null) filesToSend.add(File(file.path));
    } else {
      final List<AssetEntity>? result = await AssetPicker.pickAssets(context,
          pickerConfig: const AssetPickerConfig(
              maxAssets: 9, requestType: RequestType.common));
      if (result != null) {
        for (var asset in result) {
          final File? file = await asset.file;
          if (file != null) filesToSend.add(file);
        }
      }
    }
    if (filesToSend.isEmpty) return;

    final bool confirm = await showDialog(context: context,
        builder: (ctx) =>
            AlertDialog(
            title: Text("发送 ${filesToSend.length} 个文件？"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("取消")),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("发送"))
            ])) ?? false;
    if (!confirm) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('正在后台发送...'),
        duration: Duration(milliseconds: 1000)));

    int successCount = 0;
    for (var file in filesToSend) {
      final mime = lookupMimeType(file.path);
      final type = (mime != null && mime.startsWith('video/'))
          ? 'video'
          : 'image';
      final bool success = await _uploadOneFile(file, type);
      if (success) successCount++;
    }
    if (mounted && successCount > 0) {
      await _fetchMessages();
      _scrollToBottom(animated: true);
    }
  }

  Future<bool> _uploadOneFile(File file, String type) async {
    try {
      var request = http.MultipartRequest(
          'POST', Uri.parse('$_apiUrl/api/messages/upload'));
      request.fields['senderId'] = widget.currentUserId.toString();
      request.fields['groupId'] = widget.groupId.toString();
      request.fields['messageType'] = type;
      request.files.add(await http.MultipartFile.fromPath('file', file.path,
          contentType: MediaType.parse(
              lookupMimeType(file.path) ?? 'application/octet-stream')));
      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void _showMediaPicker() {
    showModalBottomSheet(context: context,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            Container(height: 120,
                decoration: BoxDecoration(color: Theme
                    .of(context)
                    .cardColor,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20))),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [_buildOptionItem(Icons.image, "相册", () {
                      Navigator.pop(context);
                      _pickAndSendMedia(isCamera: false);
                    }), _buildOptionItem(Icons.camera_alt, "拍摄", () {
                      Navigator.pop(context);
                      _pickAndSendMedia(isCamera: true);
                    })
                    ])));
  }

  Widget _buildOptionItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(15)),
                  child: Icon(icon, size: 30, color: Colors.black87)),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey))
            ]));
  }

  void _viewMedia(String currentUrl) {
    // 这里保持正序
    final mediaMessages = _messages.where((m) {
      final type = m['message_type'];
      return (type == 'image' || type == 'video') && m['media_url'] != null;
    }).toList();

    final List<MediaItem> galleryItems = mediaMessages.map((m) {
      return MediaItem(id: m['id'],
          mediaUrl: m['media_url'],
          mediaType: m['message_type'],
          userNickname: m['nickname'] ?? '未知',
          userAvatarUrl: m['avatar_url'] ?? '');
    }).toList();

    final initialIndex = galleryItems.indexWhere((item) =>
    item.mediaUrl == currentUrl);
    if (initialIndex == -1) return;

    Navigator.push(context, MaterialPageRoute(builder: (_) =>
        MediaViewerPage(
        mediaItems: galleryItems,
        initialIndex: initialIndex,
        viewerId: widget.currentUserId,
        apiUrl: _apiUrl,
        isPureView: true)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.groupName}"),
        actions: [
          // 👇👇👇 核心修改：连接 GroupInfoPage 👇👇👇
          IconButton(
              icon: const Icon(Icons.more_horiz),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) =>
                    GroupInfoPage(
                        currentUserId: widget.currentUserId,
                        groupId: widget.groupId,
                        groupName: widget.groupName
                    )));
              }
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Opacity(
                  opacity: _listOpacity,
                  child: ListView.builder(
                    reverse: false,
                    // 保持正序
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 12.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message['sender_id'] == widget.currentUserId;
                      return _buildMessageItem(isMe, message);
                    },
                  ),
                ),
                if (_isLoading) const Center(
                    child: CircularProgressIndicator()),
              ],
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8.0, vertical: 8.0),
              decoration: BoxDecoration(color: Theme
                  .of(context)
                  .scaffoldBackgroundColor,
                  border: Border(
                      top: BorderSide(color: Colors.grey.withOpacity(0.2)))),
              child: Row(
                children: [
                  Expanded(
                      child: Container(decoration: BoxDecoration(color: Theme
                          .of(context)
                          .brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.white,
                          borderRadius: BorderRadius.circular(24)),
                          child: TextField(controller: _textController,
                              minLines: 1,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                  hintText: '发送消息...',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 10))))),
                  const SizedBox(width: 8),
                  _showSendButton
                      ? IconButton(icon: const Icon(Icons.send),
                      onPressed: _isSending ? null : _sendMessage,
                      style: IconButton.styleFrom(backgroundColor: Colors.blue,
                          foregroundColor: Colors.white))
                      : IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 30),
                      color: Colors.grey[600],
                      onPressed: _showMediaPicker),
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

    // 1. 【核心修改】处理 'recalled' (撤回) 和 'system' (系统通知)
    // 这两种消息样式一样：灰色小字，居中显示
    if (type == 'recalled' || type == 'system') {
      String displayContent = content;
      if (type == 'recalled') {
        displayContent = isMe ? "你撤回了一条消息" : "\"${message['nickname'] ??
            '对方'}\" 撤回了一条消息";
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10), // 增加一点垂直间距
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2), // 可选：加个极淡的背景块，像微信那样
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              displayContent,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ),
      );
    }

    // ... 下面的代码保持不变 (处理 avatarUrl, mediaUrl, contentWidget 等) ...
    final avatarUrl = isMe
        ? widget.currentUserAvatar
        : (message['avatar_url'] ?? '');
    // ...
    // (请确保你保留了之前的图片、视频、文本气泡逻辑)
    // ...

    // 为了方便你直接复制，下面是该函数的剩余完整部分：
    final userId = message['sender_id'];
    final String? mediaUrl = message['media_url'];

    Widget contentWidget;
    if (type == 'image' && mediaUrl != null) {
      contentWidget = GestureDetector(
        onTap: () => _viewMedia(mediaUrl),
        child: Hero(tag: mediaUrl,
            child: ClipRRect(borderRadius: BorderRadius.circular(8),
                child: SizedBox(width: 200,
                    height: 250,
                    child: Image.network(mediaUrl, fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, loading) =>
                        loading == null
                            ? child
                            : Container(color: Colors.grey[200],
                            child: const Center(
                                child: CircularProgressIndicator())))))),
      );
    } else if (type == 'video' && mediaUrl != null) {
      contentWidget = GestureDetector(
        onTap: () => _viewMedia(mediaUrl),
        child: SizedBox(width: 200,
            height: 250,
            child: GalleryVideoThumbnail(videoUrl: mediaUrl)),
      );
    } else {
      contentWidget = Container(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        decoration: BoxDecoration(color: isMe ? Colors.blue[100] : (Theme
            .of(context)
            .brightness == Brightness.dark ? Colors.grey[800] : Colors.white),
            borderRadius: BorderRadius.circular(8)),
        child: Text(content, style: TextStyle(color: isMe ? Colors.black : Theme
            .of(context)
            .colorScheme
            .onSurface, fontSize: 16)),
      );
    }

    Widget avatarWidget = GestureDetector(
      onTap: () =>
          _checkFriendAndJump(userId, message['nickname'] ?? '未知', avatarUrl),
      child: CircleAvatar(radius: 20, backgroundImage: NetworkImage(avatarUrl)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment
            .start,
        children: [
          if (!isMe)
            Padding(padding: const EdgeInsets.only(left: 50, bottom: 2),
                child: Text(message['nickname'] ?? '未知',
                    style: const TextStyle(fontSize: 10, color: Colors.grey))),
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment
                .start,
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