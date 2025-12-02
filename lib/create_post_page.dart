// === create_post_page.dart (图文发布编辑器) ===
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

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

  final String _apiUrl = 'http://192.168.23.18:3000';

  // 选择媒体
  Future<void> _pickMedia() async {
    final List<AssetEntity>? result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 9 - _selectedFiles.length, // 剩余可选数量
        requestType: RequestType.common,
      ),
    );

    if (result != null) {
      for (var asset in result) {
        final File? file = await asset.file;
        if (file != null) {
          setState(() {
            _selectedFiles.add(file);
          });
        }
      }
    }
  }

  // 发布逻辑
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

      // 多文件添加
      for (var file in _selectedFiles) {
        final mimeType = lookupMimeType(file.path);
        request.files.add(await http.MultipartFile.fromPath(
          'files', // 后端接收的字段名是 files (数组)
          file.path,
          contentType: MediaType.parse(mimeType ?? 'application/octet-stream'),
        ));
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        if(mounted) {
          Navigator.pop(context, true); // 返回 true 表示需刷新
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
            // 1. 媒体选择区 (九宫格)
            _buildMediaGrid(),

            const SizedBox(height: 20),

            // 2. 标题输入
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

            // 3. 正文输入
            TextField(
              controller: _contentController,
              style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87),
              maxLines: null, // 自动增高
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
      itemCount: _selectedFiles.length + 1, // +1 是加号按钮
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        if (index == _selectedFiles.length) {
          // 加号按钮
          return GestureDetector(
            onTap: _pickMedia,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add, size: 40, color: Colors.grey[400]),
            ),
          );
        }

        // 已选图片展示
        final file = _selectedFiles[index];
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(file, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
            ),
            Positioned(
              top: 4, right: 4,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFiles.removeAt(index);
                  });
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