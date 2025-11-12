// === edit_profile_page.dart (最终版 - 完整代码) ===

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 引入以便未来使用

// 数据模型类
class UserProfileData {
  final int? id; // 新增ID
  final String nickname;
  final String introduction;
  final String? birthDate;
  final String avatarUrl;

  UserProfileData({
    this.id,
    required this.nickname,
    required this.introduction,
    this.birthDate,
    required this.avatarUrl,
  });
}

class EditProfilePage extends StatefulWidget {
  final UserProfileData initialData;
  final int userId; // 接收 userId

  const EditProfilePage({super.key, required this.initialData, required this.userId}); // 在构造函数中接收

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _introController;
  DateTime? _birthDate;
  File? _imageFile;
  bool _isSaving = false;

  final String _apiUrl =
      'http://192.168.23.18:3000'; // ！！！！请务必替换为您自己的IP地址！！！！

  @override
  void initState() {
    super.initState();
    _nicknameController =
        TextEditingController(text: widget.initialData.nickname);
    _introController =
        TextEditingController(text: widget.initialData.introduction);
    if (widget.initialData.birthDate != null &&
        widget.initialData.birthDate!.isNotEmpty) {
      _birthDate = DateTime.tryParse(widget.initialData.birthDate!);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _introController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80); // 压缩图片质量

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _birthDate) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  // === 请用这个新函数，替换你文件中旧的 _saveProfile 函数 ===

  Future<void> _saveProfile() async {
    // 在函数开始时就打印状态，用于调试
    print("--- [前端探针] 点击保存按钮, _imageFile 是否为空: ${_imageFile == null}");

    if (_isSaving) return;
    setState(() { _isSaving = true; });

    final uri = Uri.parse('$_apiUrl/api/profile/${widget.userId}');
    http.Response response; // 声明一个 response 变量来接收结果

    try {
      // 【核心改造】根据 _imageFile 是否为空，决定发送哪种请求
      if (_imageFile == null) {
        // --- 情况1: 没有新图片，发送普通的 JSON 请求 ---
        print("--- [前端探针] 正在发送 JSON PUT 请求...");
        final headers = {'Content-Type': 'application/json'};
        final body = json.encode({
          'nickname': _nicknameController.text,
          'introduction': _introController.text,
          if (_birthDate != null) 'birthDate': DateFormat('yyyy-MM-dd').format(_birthDate!),
        });
        // 直接使用 http.put 发送请求
        response = await http.put(uri, headers: headers, body: body).timeout(const Duration(seconds: 30));

      } else {
        // --- 情况2: 选择了新图片，使用你原来的 Multipart 请求逻辑 ---
        print("--- [前端探针] 正在发送 Multipart PUT 请求...");
        var request = http.MultipartRequest('PUT', uri);
        request.fields['nickname'] = _nicknameController.text;
        request.fields['introduction'] = _introController.text;
        if (_birthDate != null) {
          request.fields['birthDate'] = DateFormat('yyyy-MM-dd').format(_birthDate!);
        }

        final mimeType = lookupMimeType(_imageFile!.path);
        request.files.add(
          await http.MultipartFile.fromPath(
            'avatar',
            _imageFile!.path,
            contentType: MediaType.parse(mimeType ?? 'application/octet-stream'),
          ),
        );
        // 发送 Multipart 请求
        final streamedResponse = await request.send().timeout(const Duration(seconds: 90)); // 延长上传超时时间
        response = await http.Response.fromStream(streamedResponse);
      }

      // --- 统一处理两种请求的响应结果 ---
      if (mounted && response.statusCode == 200) {
        final updatedData = json.decode(response.body)['data'];
        print('--- [前端探针] 后端返回的新头像URL是: ${updatedData['avatar_url']}');
        Navigator.pop(
          context,
          UserProfileData(
            id: updatedData['id'],
            nickname: updatedData['nickname'] ?? '',
            introduction: updatedData['introduction'] ?? '',
            birthDate: updatedData['birth_date'],
            avatarUrl: updatedData['avatar_url'] ?? '',
          ),
        );
      } else if (mounted) {
        print("--- [前端探针][错误] 保存失败，状态码: ${response.statusCode}, 响应体: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: ${response.body}')));
      }

    } catch (e) {
      print("--- [前端探针][错误] 发生网络异常: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('网络错误: $e')));
      }
    } finally {
      if (mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑个人信息'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2,)) : const Text('保存', style: TextStyle(fontSize: 16)),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          const SizedBox(height: 20),
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: _imageFile != null
                      ? FileImage(_imageFile!) as ImageProvider
                      : NetworkImage(widget.initialData.avatarUrl),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: IconButton(
                      icon: Icon(Icons.edit,
                          color: Theme.of(context).colorScheme.onPrimary),
                      onPressed: _pickImage,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _nicknameController,
            decoration: InputDecoration(
              labelText: '昵称',
              prefixIcon: const Icon(Icons.person_outline),
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            leading: const Icon(Icons.cake_outlined),
            title: Text(
              _birthDate == null
                  ? '请选择出生年月日'
                  : DateFormat('yyyy 年 MM 月 dd 日').format(_birthDate!),
            ),
            onTap: () => _selectDate(context),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _introController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '个人介绍',
              alignLabelWithHint: true,
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}