// === main.dart (最终整合版 - 完整代码) ===

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_page.dart';
import 'edit_profile_page.dart' as edit_page; // 1. 使用别名导入，避免类名冲突
import 'auth_service.dart';
import 'main.dart' as edit_page;
import 'photo_gallery_page.dart';
import 'settings_page.dart';
import 'about_us_page.dart';
import 'chat_sessions_list_page.dart';
import 'set_password_page.dart'; // 2. 【新增】导入新页面
import 'conversations_list_page.dart'; // 1. 【新增】导入新页面
// --- 新的数据模型 (UserProfileData) ---
// 在 main.dart 的顶部

// --- 【最终完整版】数据模型 (UserProfileData) ---
class UserProfileData {
  final int id;
  final String? username; // 1. 【新增】接收 username，设为可空
  final String nickname;
  final String introduction;
  final String? birthDate;
  final String avatarUrl;
  final bool hasPassword;

  UserProfileData({
    required this.id,
    this.username, // 2. 【新增】在构造函数里添加
    required this.nickname,
    required this.introduction,
    this.birthDate,
    required this.avatarUrl,
    required this.hasPassword,
  });
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  late Future<Map<String, dynamic>?> _checkLoginFuture;

  @override
  void initState() {
    super.initState();
    _checkLoginFuture = AuthService.getLoginInfo();
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  void _handleLogout() async {
    await AuthService.clearLoginInfo();
    setState(() {
      _checkLoginFuture = AuthService.getLoginInfo();
    });
  }

  void _onLoginSuccess() {
    setState(() {
      _checkLoginFuture = AuthService.getLoginInfo();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '晗伴',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<Map<String, dynamic>?>(
        future: _checkLoginFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData && snapshot.data != null) {
            final loginInfo = snapshot.data!;
            return MainScreen(
              onThemeModeChanged: _toggleTheme,
              onLogout: _handleLogout,
              userId: loginInfo['userId'],
            );
          }
          return WelcomePage(onLoginSuccess: _onLoginSuccess);
        },
      ),
    );
  }
}

// --- 【核心改造】App 主框架 ---
class MainScreen extends StatefulWidget {
  final VoidCallback onThemeModeChanged;
  final VoidCallback onLogout;
  final int userId;
  const MainScreen({
    super.key,
    required this.onThemeModeChanged,
    required this.onLogout,
    required this.userId,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

// === 在 main.dart 中，用这个新版本替换旧的 _MainScreenState ===

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // 【核心修复】不再使用 late final。我们将在 build 方法中构建 _pages 列表，
  // 或者直接在声明时构建，但这需要访问 widget，所以 build 方法是最佳位置。

  // initState 保持原样，或者如果 _pages 是唯一的初始化内容，也可以暂时留空。
  @override
  void initState() {
    super.initState();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 【核心修复】在这里构建 _pages 列表
    final List<Widget> pages = <Widget>[
      HomePage(userId: widget.userId),
      ConversationsListPage(currentUserId: widget.userId),
      ProfilePage(onLogout: widget.onLogout, userId: widget.userId),
    ];

    String getTitle() {
      switch (_selectedIndex) {
        case 0: return '首页';
        case 1: return ''; // 聊天页自己有标题
        case 2: return '我';
        default: return '晗伴';
      }
    }

    final showAppBar = _selectedIndex != 1;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
        title: Text(getTitle()),
        actions: [
          IconButton(
            icon: Icon(Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            onPressed: widget.onThemeModeChanged,
          ),
        ],
      )
          : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: pages, // 使用我们刚刚在 build 方法里创建的列表
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: '聊天'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: '我'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final int userId;
  const HomePage({super.key, required this.userId});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PhotoGalleryPage(userId: userId)),
                );
              },
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library, size: 48, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    const Text('照片墙', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChatSessionsListPage(userId: userId)),
                );
              },
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 48, color: Theme.of(context).colorScheme.secondary),
                    const SizedBox(height: 16),
                    const Text('AI 助手', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  final VoidCallback onLogout;
  final int userId;
  const ProfilePage({super.key, required this.onLogout, required this.userId});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserProfileData? _profileData;
  // ！！！！请务必替换为您自己的IP地址！！！！
  final String _apiUrl = 'http://192.168.23.18:3000';

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  // 4. 【已升级】_fetchProfile 函数
  Future<void> _fetchProfile() async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/profile/${widget.userId}'));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        setState(() {
          _profileData = UserProfileData(
            id: data['id'],
            username: data['username'], // 3. 【新增】在这里接收后端传来的 username
            nickname: data['nickname'] ?? '未设置昵称',
            introduction: data['introduction'] ?? '这家伙很酷，什么也没留下...',
            birthDate: data['birth_date'],
            avatarUrl: data['avatar_url'] ?? '',
            hasPassword: data['password_hash'] != null && data['password_hash'].isNotEmpty,
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('加载个人信息失败')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('网络错误，无法加载信息')));
    }
  }

  // 在 main.dart 的 _ProfilePageState 内部

  Future<void> _navigateToEditProfile() async {
    if (_profileData == null) return;

    final result = await Navigator.push<UserProfileData>(
      context,
      MaterialPageRoute(
        builder: (context) => edit_page.EditProfilePage(
          initialData: _profileData!,
          userId: widget.userId,
          // 4. 【新增】把当前的密码状态传递给编辑页
          hasPassword: _profileData!.hasPassword,
        ),
      ),
    );

    if (result != null) {
      // 这里就不需要再手动拼接了，因为返回的 result 已经是一个完整的 UserProfileData 对象
      setState(() {
        _profileData = result;
      });
    }
  }

  Future<void> _navigateToSetPassword() async {
    if (_profileData == null) return;

    final bool? passwordHasBeenSet = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SetPasswordPage(
          userId: widget.userId,
          currentUsername: _profileData!.username, // 【修改】把用户名传过去
          hasPassword: _profileData!.hasPassword, // 【修改】把密码状态传过去
        ),
      ),
    );

    if (passwordHasBeenSet == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在刷新用户信息...')));
      _fetchProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_profileData == null) {
      return const Center(child: CircularProgressIndicator());
    } else {
      return Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 40, backgroundImage: NetworkImage(_profileData!.avatarUrl)),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_profileData!.nickname, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_profileData!.introduction, style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Theme.of(context).hintColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 40, indent: 16, endIndent: 16),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('编辑资料'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _navigateToEditProfile,
                ),

                // 7. 【新增】智能显示“设置密码”入口
                if (!_profileData!.hasPassword)
                  ListTile(
                    leading: Icon(Icons.password, color: Theme.of(context).colorScheme.primary),
                    title: Text('设置登录密码', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                    subtitle: const Text('为您的账号增加一道安全防线'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _navigateToSetPassword,
                  ),

                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('设置'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsPage(userId: widget.userId)),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('关于我们'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AboutUsPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('退出登录'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: widget.onLogout,
                ),
              ],
            ),
          ),
        ],
      );
    }
  }
}