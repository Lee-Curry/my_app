import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// 确保 main.dart 里有路由定义，或者根据你的实际路由跳转逻辑修改
import 'config.dart';
import 'main.dart';

class UserInfoMorePage extends StatefulWidget {
  final int currentUserId;
  final int targetUserId;
  final String nickname;     // 传入当前显示的名称
  final String introduction; // 传入完整的简介
  final String avatarUrl;

  const UserInfoMorePage({
    super.key,
    required this.currentUserId,
    required this.targetUserId,
    required this.nickname,
    required this.introduction,
    required this.avatarUrl,
  });

  @override
  State<UserInfoMorePage> createState() => _UserInfoMorePageState();
}

class _UserInfoMorePageState extends State<UserInfoMorePage> {
  bool _isBlacklisted = false;
  bool _isLoading = false;

  // 1. 用于存储详细信息的变量
  String _gender = "加载中...";
  String _region = "加载中...";
  String _fullIntroduction = "";

  // ！！！！请务必替换为您自己的IP地址！！！！
  final String _apiUrl = AppConfig.baseUrl;

  @override
  void initState() {
    super.initState();
    _fullIntroduction = widget.introduction;
    _fetchTargetUserInfo(); // 拉取详细资料
    _checkBlacklistStatus(); // 检查黑名单状态
  }

  // --- 3. 【核心修复】获取目标用户的详细信息 ---
  Future<void> _fetchTargetUserInfo() async {
    print("--- [前端探针] 正在获取用户 ${widget.targetUserId} 的详情...");
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/profile/${widget.targetUserId}'));

      // 打印后端返回的数据，方便调试
      print("--- [前端探针] API返回: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];

        if (mounted) {
          setState(() {
            // 1. 处理地区 (region)
            // 逻辑：如果不是null，且不是空字符串，就显示；否则显示"未知"
            if (data['region'] != null && data['region'].toString().trim().isNotEmpty) {
              _region = data['region'].toString();
            } else {
              _region = "未知";
            }

            // 2. 处理性别 (gender)
            _gender = data['gender'] ?? '保密';

            // 3. 处理简介
            _fullIntroduction = data['introduction'] ?? '暂无签名';
          });
        }
      }
    } catch (e) {
      print("--- [前端探针][错误] 获取详情失败: $e");
      if(mounted) setState(() { _gender = "未知"; _region = "获取失败"; });
    }
  }

  // --- 查询初始黑名单状态 ---
  Future<void> _checkBlacklistStatus() async {
    try {
      final uri = Uri.parse('$_apiUrl/api/blacklist/check?userId=${widget.currentUserId}&targetId=${widget.targetUserId}');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _isBlacklisted = data['isBlacklisted'] == true;
          });
        }
      }
    } catch (e) {
      print("检查黑名单状态失败: $e");
    }
  }

  // --- 【修复版】功能 1: 加入/移出黑名单 ---
  Future<void> _toggleBlacklist(bool value) async {
    // 1. 乐观更新 UI
    setState(() => _isBlacklisted = value);

    try {
      // 2. 调用后端 API
      final response = await http.post(
        Uri.parse('$_apiUrl/api/blacklist/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': widget.currentUserId,
          'targetId': widget.targetUserId,
          'action': value ? 'block' : 'unblock',
        }),
      );

      // 3. 检查结果
      if (response.statusCode != 200) {
        // 失败回滚
        if (mounted) {
          setState(() => _isBlacklisted = !value);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("操作失败，请检查网络")));
        }
      } else {
        // 成功提示 (移到了这里，只有成功才弹)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(value ? "已加入黑名单，将不再接收对方消息" : "已移出黑名单")),
          );
        }
      }
    } catch (e) {
      // 网络异常回滚
      if (mounted) {
        setState(() => _isBlacklisted = !value);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("网络错误")));
      }
    }
  }

  // --- 功能 2: 删除好友 (保留之前的逻辑) ---
  Future<void> _deleteFriend() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("删除联系人"),
          content: Text("将联系人“${widget.nickname}”删除，同时删除与该联系人的聊天记录。"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("取消", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("删除", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.delete(
        Uri.parse('$_apiUrl/api/friends/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'myUserId': widget.currentUserId,
          'friendUserId': widget.targetUserId,
        }),
      );

      final resBody = jsonDecode(response.body);

      if (response.statusCode == 200 && resBody['code'] == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已删除好友")));
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      } else {
        throw Exception(resBody['msg'] ?? "删除失败");
      }
    } catch (e) {
      if (!mounted) return;
      print("删除错误: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("操作失败，请检查网络")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      appBar: AppBar(title: const Text("更多信息")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          const SizedBox(height: 10),

          // --- 第一组：基础信息 ---
          Container(
            color: cardColor,
            child: Column(
              children: [
                ListTile(
                  title: Text("个性签名", style: TextStyle(fontSize: 15, color: textColor)),
                  subtitle: Text(
                      _fullIntroduction.isEmpty ? "暂无签名" : _fullIntroduction,
                      style: TextStyle(fontSize: 13, color: subTextColor)
                  ),
                ),
                _buildDivider(context),

                // 性别
                _buildInfoRow(context, "性别", _gender),
                _buildDivider(context),

                // 地区 (这里会显示 _region 变量的值)
                _buildInfoRow(context, "地区", _region),
                _buildDivider(context),

                // ID
                ListTile(
                  title: Text("晗伴号", style: TextStyle(fontSize: 15, color: textColor)),
                  trailing: Text("${widget.targetUserId}", style: TextStyle(color: subTextColor, fontSize: 14)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- 第二组：权限管理 ---
          Container(
            color: cardColor,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text("加入黑名单", style: TextStyle(fontSize: 15, color: textColor)),
                  value: _isBlacklisted,
                  onChanged: _toggleBlacklist,
                  activeColor: Theme.of(context).primaryColor,
                ),
                _buildDivider(context),
                ListTile(
                  title: Text("投诉", style: TextStyle(fontSize: 15, color: textColor)),
                  trailing: Icon(Icons.arrow_forward_ios, size: 14, color: subTextColor),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("投诉功能开发中")));
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // --- 第三组：危险操作 ---
          if (widget.currentUserId != widget.targetUserId) // 防止自己删自己
            Container(
              color: cardColor,
              child: ListTile(
                title: const Center(
                  child: Text("删除好友", style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                onTap: _deleteFriend,
              ),
            ),

          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      title: Text(label, style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
      trailing: Text(value, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(height: 1, indent: 16, color: Theme.of(context).dividerColor.withOpacity(0.1));
  }
}