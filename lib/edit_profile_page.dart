// === edit_profile_page.dart (完整修改版) ===

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart'; // 引入以便使用 UserProfileData

class EditProfilePage extends StatefulWidget {
  final UserProfileData initialData;
  final int userId;
  final bool hasPassword;

  const EditProfilePage({
    super.key,
    required this.initialData,
    required this.userId,
    required this.hasPassword,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _introController;
  late final TextEditingController _regionController; // 1. 【新增】地区控制器

  DateTime? _birthDate;
  File? _imageFile;
  bool _isSaving = false;

  // 2. 【新增】性别变量
  String _selectedGender = "保密";
  final List<String> _genderOptions = ["男", "女", "保密"];

  // ！！！！请务必替换为您自己的IP地址！！！！
  final String _apiUrl = 'http://192.168.23.18:3000';

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.initialData.nickname);
    _introController = TextEditingController(text: widget.initialData.introduction);

    // 初始化地区
    _regionController = TextEditingController(text: widget.initialData.region);

    // 初始化性别 (如果没有值，默认保密)
    _selectedGender = widget.initialData.gender.isEmpty ? "保密" : widget.initialData.gender;

    if (widget.initialData.birthDate != null && widget.initialData.birthDate!.isNotEmpty) {
      _birthDate = DateTime.tryParse(widget.initialData.birthDate!);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _introController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

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

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    setState(() { _isSaving = true; });

    final uri = Uri.parse('$_apiUrl/api/profile/${widget.userId}');
    http.Response response;

    try {
      // 准备好所有文本字段
      final Map<String, String> fields = {
        'nickname': _nicknameController.text,
        'introduction': _introController.text,
        'gender': _selectedGender,          // 3. 【新增】发送性别
        'region': _regionController.text,   // 4. 【新增】发送地区
      };

      if (_birthDate != null) {
        fields['birthDate'] = DateFormat('yyyy-MM-dd').format(_birthDate!);
      }

      if (_imageFile == null) {
        // --- 情况1: 普通 JSON 请求 ---
        final headers = {'Content-Type': 'application/json'};
        // 合并字段到 JSON body
        final body = json.encode(fields);
        response = await http.put(uri, headers: headers, body: body).timeout(const Duration(seconds: 30));

      } else {
        // --- 情况2: Multipart 请求 (带图片) ---
        var request = http.MultipartRequest('PUT', uri);

        // 批量添加文本字段
        request.fields.addAll(fields);

        final mimeType = lookupMimeType(_imageFile!.path);
        request.files.add(
          await http.MultipartFile.fromPath(
            'avatar',
            _imageFile!.path,
            contentType: MediaType.parse(mimeType ?? 'application/octet-stream'),
          ),
        );
        final streamedResponse = await request.send().timeout(const Duration(seconds: 90));
        response = await http.Response.fromStream(streamedResponse);
      }

      if (mounted && response.statusCode == 200) {
        final updatedData = json.decode(response.body)['data'];

        // 返回新的 UserProfileData 对象给上一页
        Navigator.pop(
          context,
          UserProfileData(
            id: updatedData['id'],
            nickname: updatedData['nickname'] ?? '',
            introduction: updatedData['introduction'] ?? '',
            birthDate: updatedData['birth_date'],
            avatarUrl: updatedData['avatar_url'] ?? '',
            hasPassword: widget.hasPassword,
            gender: updatedData['gender'] ?? _selectedGender, // 5. 【新增】更新返回
            region: updatedData['region'] ?? _regionController.text, // 6. 【新增】更新返回
            username: widget.initialData.username, // 保持原样
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: ${response.body}')));
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('网络错误: $e')));
      }
    } finally {
      if (mounted) setState(() { _isSaving = false; });
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
          // 头像
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
                      icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.onPrimary),
                      onPressed: _pickImage,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // 昵称
          TextField(
            controller: _nicknameController,
            decoration: InputDecoration(
              labelText: '昵称',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),

          // 7. 【新增】性别选择器
          DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: InputDecoration(
              labelText: '性别',
              prefixIcon: const Icon(Icons.wc),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _genderOptions.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedGender = newValue!;
              });
            },
          ),
          const SizedBox(height: 20),

          // 8. 【新增】地区输入框
          TextField(
            controller: _regionController,
            decoration: InputDecoration(
              labelText: '地区',
              prefixIcon: const Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),

          // 生日
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

          // 简介
          TextField(
            controller: _introController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: '个人介绍',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}