// === edit_profile_page.dart (黄金版 - 真实文件上传 - 完整代码) ===

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

// 数据模型类，用于在页面间方便地传递数据
class UserProfileData {
  final String nickname;
  final String introduction;
  final String? birthDate;
  final String avatarUrl;

  UserProfileData({
    required this.nickname,
    required this.introduction,
    this.birthDate,
    required this.avatarUrl,
  });
}

class EditProfilePage extends StatefulWidget {
  final UserProfileData initialData;

  const EditProfilePage({super.key, required this.initialData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _introController;
  DateTime? _birthDate;
  File? _imageFile; // 用于存储用户从相册选择的图片文件

  final String _apiUrl =
      'http://192.168.23.128:3000'; // ！！！！请务必替换为您自己的IP地址！！！！

  @override
  void initState() {
    super.initState();
    // 在页面初始化时，用传递过来的数据设置输入框的初始内容
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

  // 从相册选择图片的函数
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // 弹出日期选择器的函数
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

  // 保存个人资料的函数 (真实文件上传逻辑)
  Future<void> _saveProfile() async {
    var request = http.MultipartRequest(
      'PUT',
      Uri.parse('$_apiUrl/api/profile'),
    );

    // 添加文本字段
    request.fields['nickname'] = _nicknameController.text;
    request.fields['introduction'] = _introController.text;
    if (_birthDate != null) {
      request.fields['birthDate'] = DateFormat('yyyy-MM-dd').format(_birthDate!);
    }

    // 检查是否有新的图片文件，并将其添加到请求中
    if (_imageFile != null) {
      final mimeType = lookupMimeType(_imageFile!.path);
      request.files.add(
        await http.MultipartFile.fromPath(
          'avatar',
          _imageFile!.path,
          contentType:
          MediaType.parse(mimeType ?? 'application/octet-stream'),
        ),
      );
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (mounted && response.statusCode == 200) {
        final updatedData = json.decode(response.body)['data'];
        // 将后端返回的最新数据打包成 UserProfileData 对象并返回
        Navigator.pop(
            context,
            UserProfileData(
              nickname: updatedData['nickname'] ?? '',
              introduction: updatedData['introduction'] ?? '',
              birthDate: updatedData['birthDate'],
              avatarUrl: updatedData['avatarUrl'] ?? '',
            ));
      } else if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存失败')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('网络错误: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑个人信息'),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: const Text('保存', style: TextStyle(fontSize: 16)),
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