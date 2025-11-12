// === photo_gallery_page.dart (完整代码) ===

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

  MediaItem({
    required this.id,
    required this.mediaUrl,
    required this.mediaType,
    required this.userNickname,
    required this.userAvatarUrl,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'],
      mediaUrl: json['media_url'],
      mediaType: json['media_type'],
      userNickname: json['nickname'],
      userAvatarUrl: json['avatar_url'],
    );
  }
}

// 视频播放器的小组件
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
            onPressed: () {
              setState(() {
                _controller.value.isPlaying
                    ? _controller.pause()
                    : _controller.play();
              });
            },
            child: Icon(
              _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            ),
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
  final int userId;
  const PhotoGalleryPage({super.key, required this.userId});

  @override
  State<PhotoGalleryPage> createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends State<PhotoGalleryPage> {
  List<MediaItem> _mediaItems = [];
  bool _isLoading = true;
  final String _apiUrl = 'http://192.168.23.18:3000'; // ！！！！请务必替换为您自己的IP地址！！！！

  @override
  void initState() {
    super.initState();
    _fetchGallery();
  }

  // === 在 photo_gallery_page.dart 中，修改 _fetchGallery 函数 ===

  Future<void> _fetchGallery() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    try {
      // 核心改动：在API路径的末尾，加上当前用户的ID
      final response = await http.get(Uri.parse('$_apiUrl/api/gallery/${widget.userId}'))
          .timeout(const Duration(seconds: 15));

      if (mounted && response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body)['data'];
        setState(() {
          _mediaItems = data.map((item) => MediaItem.fromJson(item)).toList();
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载失败: $e')));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // 【核心改造】实现真正的上传功能！
  Future<void> _uploadMedia() async {
    final picker = ImagePicker();
    // 1. 让用户选择图片或视频
    final XFile? pickedFile = await picker.pickMedia(); // pickMedia 可以同时选择图片和视频

    if (pickedFile == null) {
      print('用户取消了选择');
      return;
    }

    final File file = File(pickedFile.path);
    final String? mimeType = lookupMimeType(file.path);
    final String mediaType = mimeType?.startsWith('image/') ?? false ? 'image' : 'video';

    // 2. 准备上传请求
    var request = http.MultipartRequest(
      'POST', // 使用 POST 方法
      Uri.parse('$_apiUrl/api/gallery/upload'),
    );

    // 3. 添加字段
    request.fields['userId'] = widget.userId.toString();
    request.fields['mediaType'] = mediaType;

    // 4. 添加文件
    request.files.add(
      await http.MultipartFile.fromPath(
        'media', // 与后端 multer 的 .single('media') 对应
        file.path,
        contentType: MediaType.parse(mimeType ?? 'application/octet-stream'),
      ),
    );

    // 5. 发送请求并处理结果
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在上传...')));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (mounted && (response.statusCode == 201 || response.statusCode == 200)) {
        print('上传成功！');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('上传成功！')));
        // 上传成功后，立刻刷新列表以显示新内容
        _fetchGallery();
      } else if (mounted) {
        print('上传失败: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传失败: ${response.body}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传出错: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('照片墙')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchGallery, // 支持下拉刷新
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 每行显示2个
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: _mediaItems.length,
          itemBuilder: (context, index) {
            final item = _mediaItems[index];

            // 【核心改动】在 Card 外面包裹 GestureDetector
            return GestureDetector(
                onTap: () {
                  print('点击了第 $index 项, ID: ${item.id}');
                  // 跳转到预览页面
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MediaViewerPage(
                        mediaItems: _mediaItems, // 把整个列表传过去
                        initialIndex: index,     // 把当前点击的索引传过去
                      ),
                    ),
                  );
                },
                child: Card( // 您原来的 Card 代码保持不变
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                children: [
                  // 根据类型显示图片或视频
                  if (item.mediaType == 'image')
                    Image.network(item.mediaUrl, fit: BoxFit.cover)
                  else if (item.mediaType == 'video')
                    VideoPlayerWidget(videoUrl: item.mediaUrl),

                  // 底部用户信息遮罩
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(radius: 12, backgroundImage: NetworkImage(item.userAvatarUrl)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.userNickname,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
                ),
            );

          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadMedia,
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}