// === user_profile_page.dart (自动拉取最新资料版) ===
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'private_chat_page.dart';
import 'photo_gallery_page.dart';
import 'set_remark_page.dart';
import 'avatar_viewer_page.dart';

class UserProfilePage extends StatefulWidget {
  final int currentUserId;
  final int targetUserId;
  final String nickname;
  final String avatarUrl;
  final String introduction; // 这里的可能是空的
  final String myAvatarUrl;
  final bool isFriend;

  const UserProfilePage({
    super.key,
    required this.currentUserId,
    required this.targetUserId,
    required this.nickname,
    required this.avatarUrl,
    required this.introduction,
    required this.myAvatarUrl,
    this.isFriend = true,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  List<String> _previewPhotos = [];
  String? _remark;

  // 👇👇👇 新增：用于动态显示的变量 👇👇👇
  late String _displayIntroduction;
  late String _displayAvatar;
  late String _displayNickname;

  // ！！！！请务必替换为您自己的IP地址！！！！
  final String _apiUrl = 'http://192.168.23.18:3000';

  @override
  void initState() {
    super.initState();
    // 1. 先用传进来的数据兜底
    _displayIntroduction = widget.introduction;
    _displayAvatar = widget.avatarUrl;
    _displayNickname = widget.nickname;

    // 2. 立即去后端拉取最新的详细资料 (解决简介为空的问题)
    _fetchLatestUserInfo();

    if (widget.isFriend) {
      _fetchPreviewPhotos();
      _fetchRemark();
    }
  }

  // 👇👇👇 核心新增：获取目标用户最新详情 👇👇👇
  Future<void> _fetchLatestUserInfo() async {
    try {
      final res = await http.get(Uri.parse('$_apiUrl/api/profile/${widget.targetUserId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        if (mounted) {
          setState(() {
            // 更新简介
            _displayIntroduction = data['introduction'] ?? '';
            // 顺便更新一下头像和昵称，万一对方刚好改了
            _displayAvatar = data['avatar_url'] ?? widget.avatarUrl;
            _displayNickname = data['nickname'] ?? widget.nickname;
          });
        }
      }
    } catch (e) {
      print("获取详情失败: $e");
    }
  }

  Future<void> _fetchRemark() async {
    try {
      final res = await http.get(Uri.parse('$_apiUrl/api/friends/remark?myUserId=${widget.currentUserId}&friendUserId=${widget.targetUserId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _remark = data['data'];
          });
        }
      }
    } catch (e) {}
  }

  Future<void> _fetchPreviewPhotos() async {
    try {
      final res = await http.get(Uri.parse('$_apiUrl/api/photos/user/${widget.targetUserId}?currentUserId=${widget.currentUserId}'));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body)['data'];
        if (mounted) {
          setState(() {
            _previewPhotos = data
                .where((item) => item['media_type'] == 'image' || item['media_type'] == null)
                .take(4)
                .map<String>((item) => item['url'] ?? item['media_url'])
                .toList();
          });
        }
      }
    } catch (e) {}
  }

  Future<void> _sendFriendRequest() async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/api/friends/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requesterId': widget.currentUserId,
          'addresseeId': widget.targetUserId,
        }),
      );

      final body = jsonDecode(response.body);
      if (mounted) {
        if (response.statusCode == 200 && body['code'] == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('好友申请已发送')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(body['msg'] ?? '发送失败')));
        }
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('网络错误')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    // 显示名称逻辑：有备注显示备注，没备注显示最新昵称
    final String displayName = (_remark != null && _remark!.isNotEmpty) ? _remark! : _displayNickname;

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
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AvatarViewerPage(imageUrl: _displayAvatar, heroTag: 'profile_avatar')));
                    },
                    child: Hero(
                      tag: 'profile_avatar',
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor, width: 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          // 👇 使用动态更新的头像
                          child: Image.network(_displayAvatar, width: 70, height: 70, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width:70,height:70,color:Colors.grey)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        if (_remark != null && _remark!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            // 👇 使用动态更新的昵称
                            child: Text("昵称: $_displayNickname", style: TextStyle(fontSize: 14, color: subTextColor)),
                          ),
                        const SizedBox(height: 8),
                        // 👇👇👇 核心：使用动态获取的简介 👇👇👇
                        Text(
                          (_displayIntroduction.isEmpty) ? "暂无简介" : _displayIntroduction,
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
            if (widget.isFriend)
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
            if (widget.isFriend)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    _buildSettingsItem(
                        context,
                        "设置备注和标签",
                        showDivider: true,
                        onTap: () async {
                          final newRemark = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SetRemarkPage(
                                myUserId: widget.currentUserId,
                                friendUserId: widget.targetUserId,
                                originalNickname: _displayNickname, // 传最新的昵称
                                initialRemark: _remark,
                              ),
                            ),
                          );
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

            // 4. 底部按钮
            if (widget.targetUserId != widget.currentUserId)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: widget.isFriend
                      ? ElevatedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text("发消息", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PrivateChatPage(
                            currentUserId: widget.currentUserId,
                            otherUserId: widget.targetUserId,
                            otherUserNickname: displayName,
                            otherUserAvatar: _displayAvatar, // 传最新的头像
                            currentUserAvatar: widget.myAvatarUrl,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                      : ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text("添加好友", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    onPressed: _sendFriendRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
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