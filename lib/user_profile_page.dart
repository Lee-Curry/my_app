// === user_profile_page.dart (支持备注显示与设置版) ===
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'private_chat_page.dart';
import 'photo_gallery_page.dart';
import 'set_remark_page.dart'; // 👈 导入新页面

class UserProfilePage extends StatefulWidget {
  final int currentUserId; // 我
  final int targetUserId;  // 对方
  final String nickname;   // 原始昵称
  final String avatarUrl;
  final String introduction;
  final String myAvatarUrl;

  const UserProfilePage({
    super.key,
    required this.currentUserId,
    required this.targetUserId,
    required this.nickname,
    required this.avatarUrl,
    required this.introduction,
    required this.myAvatarUrl,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  List<String> _previewPhotos = [];
  String? _remark; // 👈 新增：存储备注
  final String _apiUrl = 'http://192.168.23.18:3000';

  @override
  void initState() {
    super.initState();
    _fetchPreviewPhotos();
    _fetchRemark(); // 👈 获取备注
  }

  // 获取备注
  Future<void> _fetchRemark() async {
    try {
      final res = await http.get(Uri.parse('$_apiUrl/api/friends/remark?myUserId=${widget.currentUserId}&friendUserId=${widget.targetUserId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _remark = data['data']; // 如果没备注返回 null
        });
      }
    } catch (e) {}
  }

  Future<void> _fetchPreviewPhotos() async {
    try {
      final res = await http.get(Uri.parse('$_apiUrl/api/photos/user/${widget.targetUserId}?currentUserId=${widget.currentUserId}'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body)['data'];
        setState(() {
          _previewPhotos = data
              .where((item) => item['media_type'] == 'image' || item['media_type'] == null)
              .take(4)
              .map<String>((item) => item['url'] ?? item['media_url'])
              .toList();
        });
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    // 👇 决定显示的主标题（有备注显备注，无备注显昵称）
    final String displayName = (_remark != null && _remark!.isNotEmpty) ? _remark! : widget.nickname;

    return Scaffold(
      appBar: AppBar(
        title: const Text("详细资料"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // 1. 个人信息卡片
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? [] : [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                ],
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.network(widget.avatarUrl, width: 70, height: 70, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width:70,height:70,color:Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 主标题
                        Text(
                          displayName,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                        ),

                        // 👇 如果有备注，下面显示真实昵称
                        if (_remark != null && _remark!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text("昵称: ${widget.nickname}", style: TextStyle(fontSize: 14, color: subTextColor)),
                          ),

                        const SizedBox(height: 8),
                        Text(
                          widget.introduction.isEmpty ? "暂无简介" : widget.introduction,
                          style: TextStyle(fontSize: 14, color: subTextColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. 照片墙入口
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => PhotoGalleryPage(
                    userId: widget.targetUserId, viewerId: widget.currentUserId, isMe: widget.targetUserId == widget.currentUserId,
                  )));
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("照片墙", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                          Icon(Icons.chevron_right, color: subTextColor),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_previewPhotos.isNotEmpty)
                        SizedBox(
                          height: 60,
                          child: Row(
                            children: _previewPhotos.map((url) {
                              return Container(
                                margin: const EdgeInsets.only(right: 10),
                                width: 60, height: 60,
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)),
                              );
                            }).toList(),
                          ),
                        )
                      else
                        Text("暂无公开照片", style: TextStyle(color: subTextColor, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3. 设置备注入口
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _buildSettingsItem(
                      context,
                      "设置备注和标签",
                      showDivider: true,
                      // 👇 点击跳转设置页
                      onTap: () async {
                        final newRemark = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SetRemarkPage(
                              myUserId: widget.currentUserId,
                              friendUserId: widget.targetUserId,
                              originalNickname: widget.nickname,
                              initialRemark: _remark,
                            ),
                          ),
                        );
                        // 如果返回了新备注，刷新 UI
                        if (newRemark != null) {
                          setState(() {
                            _remark = newRemark.toString().isEmpty ? null : newRemark;
                          });
                        }
                      }
                  ),
                  _buildSettingsItem(context, "更多信息", showDivider: false, onTap: (){}),
                ],
              ),
            ),

            const SizedBox(height: 40),

            if (widget.targetUserId != widget.currentUserId)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text("发消息", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrivateChatPage(
                            currentUserId: widget.currentUserId,
                            otherUserId: widget.targetUserId,
                            // 👇 传给聊天页的名字，优先用备注
                            otherUserNickname: displayName,
                            otherUserAvatar: widget.avatarUrl,
                            currentUserAvatar: widget.myAvatarUrl,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(BuildContext context, String title, {bool showDivider = true, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        ListTile(
          title: Text(title, style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
          trailing: Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[300]),
          onTap: onTap,
        ),
        if (showDivider)
          Divider(height: 1, indent: 16, endIndent: 16, color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ],
    );
  }
}