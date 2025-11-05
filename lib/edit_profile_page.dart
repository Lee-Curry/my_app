import 'dart:io'; // 用于处理文件
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart'; // 导入我们新加的库
import 'package:intl/intl.dart';
import 'package:mime/mime.dart'; // 1. 导入 mime 包
import 'package:http_parser/http_parser.dart'; // 用于设置文件类型



// 1. 创建一个简单的数据模型类，方便传递数据
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
  // 2. 添加一个属性，用来接收从 ProfilePage 传过来的初始数据
  final UserProfileData initialData;

  const EditProfilePage({super.key, required this.initialData});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // 3. 控制器不再写死初始值，而是在 initState 中初始化
  late final TextEditingController _nicknameController;
  late final TextEditingController _introController;
  DateTime? _birthDate;
  File? _imageFile;

  final String _apiUrl = 'http://10.61.193.166:3000'; // ！！！！请务必替换为您自己的IP地址！！！！

  @override
  void initState() {
    super.initState();
    // 4. 【核心修正】在页面初始化时，用传递过来的数据设置输入框的初始内容
    _nicknameController = TextEditingController(text: widget.initialData.nickname);
    _introController = TextEditingController(text: widget.initialData.introduction);
    if (widget.initialData.birthDate != null) {
      _birthDate = DateTime.tryParse(widget.initialData.birthDate!);
    }
  }
  // --- 1. 新增：从相册选择图片的函数 ---
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // --- 2. 新增：保存个人资料的函数 ---
  // === 在 edit_profile_page.dart 中，替换旧的 _saveProfile 方法 ===


// ...

  Future<void> _saveProfile() async {
    print('--- 保存按钮被点击！ ---');

    // 2. 创建一个 MultipartRequest (多部分请求)
    // 这种请求类型可以同时发送文本字段和文件
    var request = http.MultipartRequest(
      'PUT', // 请求方法是 PUT
      Uri.parse('$_apiUrl/api/profile'),
    );

    // 3. 添加所有的文本字段
    request.fields['nickname'] = _nicknameController.text;
    request.fields['introduction'] = _introController.text;
    if (_birthDate != null) {
      request.fields['birthDate'] = DateFormat('yyyy-MM-dd').format(_birthDate!);
    }

    // 4. 【核心】检查是否有新的图片文件，并将其添加到请求中
    if (_imageFile != null) {
      print('--- 检测到新图片，准备上传！ ---');
      // 获取文件的 MIME 类型 (例如 'image/jpeg')
      final mimeType = lookupMimeType(_imageFile!.path);

      // 将文件添加到请求中，字段名为 'avatar' (必须和后端 upload.single('avatar') 里的名字一致！)
      request.files.add(
        await http.MultipartFile.fromPath(
          'avatar',
          _imageFile!.path,
          contentType: MediaType.parse(mimeType ?? 'application/octet-stream'),
        ),
      );
    }

    try {
      // 5. 发送这个构造好的复杂请求
      final streamedResponse = await request.send();
      // 将响应转换为常规的 Response 对象
      final response = await http.Response.fromStream(streamedResponse);

      print('--- 后端响应状态码: ${response.statusCode} ---');
      print('--- 后端响应内容: ${response.body} ---');

      if (mounted && response.statusCode == 200) {
        print('--- 个人资料保存成功！准备返回上一页... ---');
        final updatedData = json.decode(response.body)['data'];

        final resultData = UserProfileData(
          nickname: updatedData['nickname'] ?? '',
          introduction: updatedData['introduction'] ?? '',
          birthDate: updatedData['birthDate'],
          avatarUrl: updatedData['avatarUrl'] ?? '',
        );
        Navigator.pop(context, resultData);

      } else if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存失败')));
      }
    } catch (e) {
      print('--- 在 _saveProfile 中捕获到异常: $e ---');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('网络错误: $e')));
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _introController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _birthDate) {
      setState(() { _birthDate = picked; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑个人信息'),
        actions: [
          TextButton(
            onPressed: () => _saveProfile(),
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
                // --- 3. 改造：让头像可以显示新选择的图片 ---
                CircleAvatar(
                  radius: 60,
                  // 5. 【核心修正】初始头像也使用传递过来的数据
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
                      onPressed: _pickImage, // 绑定选择图片函数
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              _birthDate == null ? '请选择出生年月日' : DateFormat('yyyy 年 MM 月 dd 日').format(_birthDate!),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}