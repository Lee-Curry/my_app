// === photo_gallery_page.dart (支持朋友圈逻辑 - 完整代码) ===

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'media_viewer_page.dart';

// 数据模型
class MediaItem {
  final int id;
  final String mediaUrl;
  final String mediaType;
  final String userNickname;
  final String userAvatarUrl;
  // 可以在列表页简单展示点赞数，如果后端没返回可以先不处理
  final int likeCount;

  MediaItem({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    required this.userNickname,
    required this.userAvatarUrl,
    this.likeCount = 0,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'],
      // 👇 重点：优先取 'url' (新接口)，取不到再取 'media_url' (旧接口)
      mediaUrl: json['url'] ?? json['media_url'] ?? '',
      mediaType: json['media_type'] ?? 'image',
      userNickname: json['nickname'] ?? '未知用户',
      userAvatarUrl: json['avatar_url'] ?? '',
      likeCount: json['like_count'] ?? 0,
    );
  }
}

// 视频播放器的小组件 (保持不变)
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {});
      });
    _controller.setLooping(true);
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller),
          FloatingActionButton(
            mini: true,
            heroTag: "btn_${widget.videoUrl}", // 防止 Hero 动画冲突
            onPressed: () {
              setState(() {
                _controller.value.isPlaying ? _controller.pause() : _controller.play();
              });
            },
            child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
          ),
        ],
      ),
    )
        : const Center(child: CircularProgressIndicator());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// 照片墙主页面
class PhotoGalleryPage extends StatefulWidget {
  final int userId;      // 目标用户 ID (看谁的)
  final int viewerId;    // 观看者 ID (我是谁)
  final bool isMe;       // 是否是看自己

  const PhotoGalleryPage({
    super.key,
    required this.userId,
    required this.viewerId,
    this.isMe = false, // 默认为 false
  });

  @override
  State<PhotoGalleryPage> createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends State<PhotoGalleryPage> {
  List<MediaItem> _mediaItems = [];
  bool _isLoading = true;
  final String _apiUrl = 'http://192.168.23.18:3000'; // 替换你的IP

  @override
  void initState() {
    super.initState();
    _fetchGallery();
  }

  // 获取照片列表
  Future<void> _fetchGallery() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    try {
      // 调用新的接口，传入 viewerId 以便后端做权限检查
      final uri = Uri.parse('$_apiUrl/api/photos/user/${widget.userId}?currentUserId=${widget.viewerId}');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (mounted && response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)['data'];
        setState(() {
          _mediaItems = data.map((item) => MediaItem.fromJson(item)).toList();
        });
      } else if (response.statusCode == 403) {
        // 权限被拒绝 (非好友)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('你们还不是好友，无法查看朋友圈')));
          setState(() => _mediaItems = []);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败: $e')));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // 上传功能 (只允许在看自己的时候上传)
  Future<void> _uploadMedia() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickMedia();

    if (pickedFile == null) return;

    final File file = File(pickedFile.path);
    final String? mimeType = lookupMimeType(file.path);
    final String mediaType = mimeType?.startsWith('image/') ?? false ? 'image' : 'video';

    // 假设你的上传接口还是 /api/gallery/upload，如果为了统一，可以考虑迁移到 /api/photos/upload
    // 这里暂时保持你原有的逻辑
    var request = http.MultipartRequest('POST', Uri.parse('$_apiUrl/api/gallery/upload'));

    request.fields['userId'] = widget.userId.toString();
    request.fields['mediaType'] = mediaType;
    request.files.add(await http.MultipartFile.fromPath(
      'media',
      file.path,
      contentType: MediaType.parse(mimeType ?? 'application/octet-stream'),
    ));

    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在上传...')));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (mounted && (response.statusCode == 201 || response.statusCode == 200)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('上传成功！')));
        _fetchGallery(); // 刷新
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传失败: ${response.body}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传出错: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isMe ? '我的照片墙' : 'TA的照片墙')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mediaItems.isEmpty
          ? Center(child: Text('暂无动态', style: TextStyle(color: Colors.grey[600])))
          : RefreshIndicator(
        onRefresh: _fetchGallery,
        child: GridView.builder(
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, // 朋友圈通常是3列
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: _mediaItems.length,
          itemBuilder: (context, index) {
            final item = _mediaItems[index];

            return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MediaViewerPage(
                        mediaItems: _mediaItems, // 列表
                        initialIndex: index,     // 当前点击的索引
                        viewerId: widget.viewerId, // 👈 新增：传入观看者ID
                        apiUrl: _apiUrl,           // 👈 新增：传入API地址
                      ),
                    ),
                  );
                },
                child: Hero(
                  tag: 'photo_${item.id}', // 添加 Hero 动画
                  child: item.mediaType == 'image'
                      ? Image.network(item.mediaUrl, fit: BoxFit.cover)
                      : Container(
                    color: Colors.black,
                    child: const Icon(Icons.play_circle_outline, color: Colors.white, size: 40),
                  ),
                )
            );
          },
        ),
      ),
      // 只有看自己的时候，才显示上传按钮
      floatingActionButton: widget.isMe
          ? FloatingActionButton(
        onPressed: _uploadMedia,
        child: const Icon(Icons.add_a_photo),
      )
          : null,
    );
  }
}