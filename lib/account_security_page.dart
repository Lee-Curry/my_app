// === account_security_page.dart (完整代码) ===

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AccountSecurityPage extends StatefulWidget {
  final int userId;
  const AccountSecurityPage({super.key, required this.userId});

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  bool _isLoading = true;
  String? _phoneNumber;
  String? _registrationDate;
  String _errorMessage = '';

  // 你的后端API地址
  final String _apiUrl = 'http://192.168.23.18:3000'; // ！！！！请务必替换为您自己的IP地址！！！！

  @override
  void initState() {
    super.initState();
    _fetchAccountInfo();
  }

  Future<void> _fetchAccountInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/api/account/security/${widget.userId}'),
      ).timeout(const Duration(seconds: 10));

      if (mounted) {
        if (response.statusCode == 200) {
          final data = json.decode(response.body)['data'];
          setState(() {
            _phoneNumber = data['phoneNumber'];
            _registrationDate = data['registrationDate'];
            _isLoading = false;
          });
        } else {
          throw Exception('加载失败，请稍后再试');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账号与安全'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(child: Text('出错了: $_errorMessage'))
          : ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_iphone),
                  title: const Text('手机号码'),
                  subtitle: Text(
                    _phoneNumber ?? '未获取到',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const Divider(height: 1, indent: 16),
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('注册日期'),
                  subtitle: Text(
                    _registrationDate ?? '未获取到',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}