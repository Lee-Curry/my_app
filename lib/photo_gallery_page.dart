// === photo_gallery_page.dart (视频封面修复版 - 完整代码) ===

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'media_viewer_page.dart'; // 导入大图/视频查看器

// 数据模型
class MediaItem {
  final int id;
  final String mediaUrl;
  final String mediaType;
  final String userNickname;
  final String userAvatarUrl;
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
      mediaUrl: json['url'] ?? json['media_url'] ?? '',
      mediaType: json['media_type'] ?? 'image',
      userNickname: json['nickname'] ?? '未知用户',
      userAvatarUrl: json['avatar_url'] ?? '',
      likeCount: json['like_count'] ?? 0,
    );
  }
}

// 【核心修改】视频缩略图组件 (代替原来的 VideoPlayerWidget)
// 【核心修正】视频缩略图组件 (带裁剪功能，防止溢出)
class GalleryVideoThumbnail extends StatefulWidget {
  final String videoUrl;
  const GalleryVideoThumbnail({super.key, required this.videoUrl});

  @override
  State<GalleryVideoThumbnail> createState() => _GalleryVideoThumbnailState();
}

class _GalleryVideoThumbnailState extends State<GalleryVideoThumbnail> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      })
      ..setVolume(0);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      // 👇👇👇 关键修改：加上 ClipRect，强制裁剪超出格子的内容 👇👇👇
      child: ClipRect(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isInitialized && _controller != null)
              SizedBox.expand( // 强迫子组件填满父容器（格子）
                child: FittedBox(
                  // BoxFit.cover 保证画面填满正方形，多余的会被 ClipRect 剪掉
                  fit: BoxFit.cover,
                  child: SizedBox(
                    // 这里必须指定视频的原始宽高，FittedBox 才能正确计算比例
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),

            // 播放图标
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
            ),
          ],
        ),
      ),
    );
  }
}

// 照片墙主页面
class PhotoGalleryPage extends StatefulWidget {
  final int userId;
  final int viewerId;
  final bool isMe;

  const PhotoGalleryPage({
    super.key,
    required this.userId,
    required this.viewerId,
    this.isMe = false,
  });

  @override
  State<PhotoGalleryPage> createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends State<PhotoGalleryPage> {
  List<MediaItem> _mediaItems = [];
  bool _isLoading = true;
  final String _apiUrl = 'http://192.168.23.18:3000';

  @override
  void initState() {
    super.initState();
    _fetchGallery();
  }

  Future<void> _fetchGallery() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    try {
      final uri = Uri.parse('$_apiUrl/api/photos/user/${widget.userId}?currentUserId=${widget.viewerId}');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (mounted && response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)['data'];
        setState(() {
          _mediaItems = data.map((item) => MediaItem.fromJson(item)).toList();
        });
      } else if (response.statusCode == 403) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('你们还不是好友，无法查看照片墙')));
          setState(() => _mediaItems = []);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败: $e')));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _uploadMedia() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickMedia();

    if (pickedFile == null) return;

    final File file = File(pickedFile.path);
    final String? mimeType = lookupMimeType(file.path);
    final String mediaType = mimeType?.startsWith('image/') ?? false ? 'image' : 'video';

    // 上传前简单Loading提示
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在上传...')));

    var request = http.MultipartRequest('POST', Uri.parse('$_apiUrl/api/gallery/upload')); // 这里的接口地址如果后端统一了可以用 messages/upload 那个，或者保留原来的

    request.fields['userId'] = widget.userId.toString(); // 兼容旧接口
    // 如果你统一了后端，可能需要传 senderId 等，这里假设你保留了旧上传接口或者做了兼容
    request.fields['mediaType'] = mediaType;
    request.files.add(await http.MultipartFile.fromPath(
      'media', // 注意：旧接口可能是 'media'，新聊天接口是 'file'，请确认后端 multer 配置
      file.path,
      contentType: MediaType.parse(mimeType ?? 'application/octet-stream'),
    ));

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (mounted && (response.statusCode == 201 || response.statusCode == 200)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('上传成功！')));
        _fetchGallery(); // 刷新列表
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
            crossAxisCount: 3, // 3列
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: _mediaItems.length,
          itemBuilder: (context, index) {
            final item = _mediaItems[index];

            return GestureDetector(
                onTap: () {
                  // 点击进入大图查看
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MediaViewerPage(
                        mediaItems: _mediaItems,
                        initialIndex: index,
                        viewerId: widget.viewerId,
                        apiUrl: _apiUrl,
                        // 照片墙模式：isPureView = false (显示点赞评论)
                        isPureView: false,
                      ),
                    ),
                  );
                },
                child: Hero(
                  tag: 'photo_${item.id}', // Hero 动画
                  child: item.mediaType == 'image'
                  // 图片处理
                      ? Image.network(item.mediaUrl, fit: BoxFit.cover)
                  // 视频处理：使用新的缩略图组件
                      : GalleryVideoThumbnail(videoUrl: item.mediaUrl),
                )
            );
          },
        ),
      ),
      floatingActionButton: widget.isMe
          ? FloatingActionButton(
        onPressed: _uploadMedia,
        child: const Icon(Icons.add_a_photo),
      )
          : null,
    );
  }
}