// === set_password_page.dart (升级版 - 完整代码) ===

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SetPasswordPage extends StatefulWidget {
  final int userId;
  final String? currentUsername; // 接收当前用户名，如果为null或空字符串，说明没有
  final bool hasPassword;      // 接收当前是否有密码

  const SetPasswordPage({
    super.key,
    required this.userId,
    this.currentUsername,
    required this.hasPassword,
  });

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final String _apiUrl = 'http://192.168.23.18:3000'; // ！！！！请务必替换为您自己的IP地址！！！！

  Future<void> _setPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() { _isSaving = true; });

    try {
      // 动态构建请求体
      final Map<String, dynamic> body = {
        'userId': widget.userId,
        'password': _passwordController.text,
      };

      // 如果是老用户（没有用户名），就把新设置的用户名也加上
      final bool canSetUsername = widget.currentUsername == null || widget.currentUsername!.isEmpty;
      if(canSetUsername && _usernameController.text.isNotEmpty) {
        body['username'] = _usernameController.text;
      }

      final response = await http.post(
        Uri.parse('$_apiUrl/api/user/set-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (!mounted) return;
      final responseBody = json.decode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.hasPassword ? '密码修改成功！' : '密码设置成功！'), backgroundColor: Colors.green),
        );
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.of(context).pop(true); // 返回 true 表示操作成功
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: ${responseBody['message']}')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('网络错误: $e')));
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 判断是否是首次设置密码（即没有用户名的情况）
    final bool isFirstTimeSetting = widget.currentUsername == null || widget.currentUsername!.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFirstTimeSetting ? '首次设置密码和用户名' : '修改密码'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isFirstTimeSetting
                    ? '为了账户统一，请设置一个登录用户名和密码。'
                    : '请输入您的新密码。',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),

              // 【智能UI】只有在老用户首次设置时，才显示这个输入框
              if (isFirstTimeSetting)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: '设置用户名',
                      prefixIcon: const Icon(Icons.person_add_alt_1),
                      helperText: '设置后将作为您的主要登录凭据',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return '请设置一个用户名';
                      if (value.length < 3) return '用户名至少需要3个字符';
                      return null;
                    },
                  ),
                ),

              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: widget.hasPassword ? '新密码' : '设置密码',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return '请输入密码';
                  if (value.length < 6) return '密码至少需要6个字符';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: '确认密码',
                  prefixIcon: const Icon(Icons.lock_person_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value != _passwordController.text) return '两次输入的密码不一致';
                  return null;
                },
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isSaving ? null : _setPassword,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('确认提交'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}