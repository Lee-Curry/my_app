// === main.dart (最终修复版 V-Final-Plus) ===

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_page.dart';
import 'edit_profile_page.dart';
import 'ai_chat_page.dart';
import 'auth_service.dart';
import 'photo_gallery_page.dart';
import 'settings_page.dart';
import 'about_us_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

// === 在 main.dart 中，用这份完整的代码替换旧的 _MyAppState 类 ===

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  // 这个 Future 用于 FutureBuilder，确保检查登录状态的操作只在必要时执行
  late Future<Map<String, dynamic>?> _checkLoginFuture;

  @override
  void initState() {
    super.initState();
    // App 启动时，初始化这个 Future
    _checkLoginFuture = AuthService.getLoginInfo();
  }

  // 切换主题的方法 (这个逻辑是正确的)
  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  // 【核心修正】我们现在明确地定义 _handleLogout 方法
  void _handleLogout() async {
    // 1. 首先，调用 AuthService 清除手机上保存的所有登录信息
    await AuthService.clearLoginInfo();

    // 2. 然后，我们更新状态，让 FutureBuilder 重新运行检查
    //    这一次，因为信息已被清除，AuthService.getLoginInfo() 将返回 null
    //    FutureBuilder 就会自动切换到 WelcomePage
    setState(() {
      _checkLoginFuture = AuthService.getLoginInfo();
    });
  }

  // 当登录成功时，我们也需要用同样的方式来刷新 FutureBuilder
  void _onLoginSuccess() {
    setState(() {
      _checkLoginFuture = AuthService.getLoginInfo();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '我的AI助手App',
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
          // 【核心修正】将正确的方法名传递给 WelcomePage
          return WelcomePage(onLoginSuccess: _onLoginSuccess);
        },
      ),
    );
  }
}

// --- App 主框架 ---
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

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      HomePage(userId: widget.userId),
      ProfilePage(onLogout: widget.onLogout, userId: widget.userId),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? '首页' : '我'),
        actions: [
          IconButton(
            icon: Icon(Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
            onPressed: widget.onThemeModeChanged,
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages, // 使用持久化的列表
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// --- 首页 (UI代码已恢复) ---
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
                print('点击照片墙, 用户ID: ${userId}');
                // 【核心改动】
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
                  MaterialPageRoute(builder: (context) => AiChatPage(userId: userId)),
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

// --- “我”的页面 (UI代码已恢复) ---
class ProfilePage extends StatefulWidget {
  final VoidCallback onLogout;
  final int userId;
  const ProfilePage({super.key, required this.onLogout, required this.userId});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserProfileData? _profileData;
  final String _apiUrl = 'http://192.168.23.18:3000'; // ！！！！请务必替换为您自己的IP地址！！！！

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  // === 在 main.dart 的 _ProfilePageState 中，替换旧的 _fetchProfile 方法 ===

  Future<void> _fetchProfile() async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/api/profile/${widget.userId}'));

      if (!mounted) return; // 检查页面是否还存在

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        setState(() {
          _profileData = UserProfileData(
            nickname: data['nickname'],
            introduction: data['introduction'] ?? '这家伙很酷，什么也没留下...',
            birthDate: data['birth_date'],
            avatarUrl: data['avatar_url'],
          );
        });
      } else if (response.statusCode == 404) {
        // 【核心修正】如果后端明确告诉我们“用户不存在”(404)
        print('用户ID ${widget.userId} 在数据库中不存在，执行强制登出！');
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('您的账户信息异常，请重新登录。'))
        );
        // 直接调用从 MyApp 传过来的 onLogout 方法！
        widget.onLogout();
      } else {
        // 其他网络错误
        throw Exception('Failed to load profile');
      }
    } catch (e) {
      print('获取个人信息失败: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('加载个人信息失败')));

      // 【可选优化】在加载失败时，也可以考虑强制登出
      // widget.onLogout();
    }
  }

  Future<void> _navigateToEditProfile() async {
    if (_profileData == null) return;
    final result = await Navigator.push<UserProfileData>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(initialData: _profileData!, userId: widget.userId),
      ),
    );
    if (result != null) {
      setState(() {
        _profileData = result;
      });
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
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('设置'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // 【核心改动】跳转到设置页面时，传入 userId
                    Navigator.push(
                      context,
                      // 修改这一行
                      MaterialPageRoute(builder: (context) => SettingsPage(userId: widget.userId)),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('关于我们'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // 【核心改动】跳转到关于我们页面
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