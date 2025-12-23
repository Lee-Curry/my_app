// === create_post_page.dart (修复视频预览红叉版) ===

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart'; // 👈 必须导入
import 'config.dart';

class CreatePostPage extends StatefulWidget {
  final int userId;
  const CreatePostPage({super.key, required this.userId});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  List<File> _selectedFiles = [];
  bool _isPublishing = false;

  // ！！！！请务必替换为您自己的IP地址！！！！
  final String _apiUrl = AppConfig.baseUrl;

  Future<void> _pickMedia({required bool isVideo, required bool isCamera}) async {
    int maxCount = 9 - _selectedFiles.length;
    if (maxCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('最多只能传9个哦')));
      return;
    }

    if (isCamera) {
      final picker = ImagePicker();
      XFile? xFile;
      if (isVideo) {
        xFile = await picker.pickVideo(source: ImageSource.camera);
      } else {
        xFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      }
      if (xFile != null) {
        setState(() { _selectedFiles.add(File(xFile!.path)); });
      }
    } else {
      final RequestType requestType = isVideo ? RequestType.video : RequestType.common;
      final List<AssetEntity>? result = await AssetPicker.pickAssets(
        context,
        pickerConfig: AssetPickerConfig(maxAssets: maxCount, requestType: requestType),
      );
      if (result != null) {
        for (var asset in result) {
          final File? file = await asset.file;
          if (file != null) {
            setState(() { _selectedFiles.add(file); });
          }
        }
      }
    }
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 180,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildOptionItem(Icons.image, "相册", () {
              Navigator.pop(ctx);
              _pickMedia(isVideo: false, isCamera: false);
            }),
            _buildOptionItem(Icons.camera_alt, "拍摄", () {
              Navigator.pop(ctx);
              _pickMedia(isVideo: false, isCamera: true);
            }),
            _buildOptionItem(Icons.videocam, "视频", () {
              Navigator.pop(ctx);
              _pickMedia(isVideo: true, isCamera: false);
            }),
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
            decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(15)
            ),
            child: Icon(icon, size: 30, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Future<void> _publish() async {
    if (_selectedFiles.isEmpty && _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('总得写点什么或发张图吧~')));
      return;
    }

    setState(() => _isPublishing = true);

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_apiUrl/api/posts/create'));

      request.fields['userId'] = widget.userId.toString();
      request.fields['title'] = _titleController.text;
      request.fields['content'] = _contentController.text;

      for (var file in _selectedFiles) {
        final mimeType = lookupMimeType(file.path);
        request.files.add(await http.MultipartFile.fromPath(
          'files',
          file.path,
          contentType: MediaType.parse(mimeType ?? 'application/octet-stream'),
        ));
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        if(mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('发布成功！')));
        }
      } else {
        throw Exception('Status ${response.statusCode}');
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('发布失败，请重试')));
    } finally {
      if(mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            child: ElevatedButton(
              onPressed: _isPublishing ? null : _publish,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: _isPublishing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("发布", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMediaGrid(),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: "填写标题会有更多赞哦~",
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 20, fontWeight: FontWeight.bold),
                border: InputBorder.none,
              ),
            ),
            const Divider(),
            TextField(
              controller: _contentController,
              style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87),
              maxLines: null,
              minLines: 5,
              decoration: InputDecoration(
                hintText: "添加正文...",
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
                border: InputBorder.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _selectedFiles.length + 1,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        if (index == _selectedFiles.length) {
          return GestureDetector(
            onTap: _showMediaPicker,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add, size: 40, color: Colors.grey[400]),
            ),
          );
        }

        final file = _selectedFiles[index];
        // 👇👇👇 核心逻辑：判断文件类型 👇👇👇
        final mime = lookupMimeType(file.path);
        final isVideo = mime != null && mime.startsWith('video/');

        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox.expand(
                child: isVideo
                // 如果是视频，使用本地视频缩略图组件
                    ? _LocalVideoThumbnail(file: file)
                // 如果是图片，继续用 Image.file
                    : Image.file(file, fit: BoxFit.cover),
              ),
            ),

            // 删除按钮
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: () {
                  setState(() { _selectedFiles.removeAt(index); });
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            )
          ],
        );
      },
    );
  }
}

// 👇👇👇 【核心新增】本地视频缩略图组件 👇👇👇
// 专门用于显示本地 File 视频的第一帧，带播放图标
class _LocalVideoThumbnail extends StatefulWidget {
  final File file;
  const _LocalVideoThumbnail({required this.file});

  @override
  State<_LocalVideoThumbnail> createState() => _LocalVideoThumbnailState();
}

class _LocalVideoThumbnailState extends State<_LocalVideoThumbnail> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // 使用 .file() 方法加载本地文件
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        // 往后跳一点点，避开黑屏片头
        _controller!.seekTo(const Duration(milliseconds: 100));
        if (mounted) setState(() { _isInitialized = true; });
      });
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isInitialized && _controller != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
          // 播放图标
          const Icon(Icons.play_circle_outline, color: Colors.white, size: 40),
        ],
      ),
    );
  }
}