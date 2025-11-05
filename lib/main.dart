// === main.dart (V-Final 最终版) ===

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'login_page.dart'; // 引入登录页面
import 'edit_profile_page.dart'; // 引入编辑页面

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
  bool _isLoggedIn = false; // 唯一的用户状态

  // 切换主题的方法
  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  // 登录成功时调用的方法
  void _handleLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  // 退出登录时调用的方法
  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '我的AI助手App',
      // --- Material 3 亮色主题 (最简洁、最现代的写法) ---
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      // --- Material 3 暗色主题 ---
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

      // --- 【核心逻辑】---
      // MyApp 作为“大脑”，根据登录状态，决定显示哪个页面
      home: _isLoggedIn
          ? MainScreen(onThemeModeChanged: _toggleTheme, onLogout: _handleLogout) // 已登录：显示主页，并把“真遥控器”传下去
          : WelcomePage(onLoginSuccess: _handleLoginSuccess), // 未登录：显示欢迎页，并把“登录成功”的通知器传下去
    );
  }
}

// === App 主框架 (保持简洁) ===
class MainScreen extends StatefulWidget {
  final VoidCallback onThemeModeChanged;
  final VoidCallback onLogout;
  const MainScreen({super.key, required this.onThemeModeChanged, required this.onLogout});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

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
            onPressed: widget.onThemeModeChanged, // 直接使用从 MyApp 传来的“真遥控器”
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: <Widget>[
          const HomePage(),
          ProfilePage(onLogout: widget.onLogout), // 将登出回调传递给“我”的页面
        ],
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

// === 替换旧的 HomePage ===
class HomePage extends StatelessWidget {
  const HomePage({super.key});
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
              onTap: () => print('点击照片墙'),
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
              onTap: () => print('点击AI助手'),
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

// === 在 main.dart 中，用下面的代码替换旧的 ProfilePage ===

class ProfilePage extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfilePage({super.key, required this.onLogout});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

// === 在 main.dart 中，用下面的代码替换旧的 _ProfilePageState ===

class _ProfilePageState extends State<ProfilePage> {
  // 1. 使用 UserProfileData 模型来统一管理状态
  UserProfileData _profileData = UserProfileData(
    nickname: '科技爱好者',
    introduction: '这家伙很酷，什么也没留下...',
    avatarUrl: 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?q=80&w=1887&auto=format=fit-crop',
    birthDate: null,
  );

  // 2. 【核心修正】改造跳转方法
  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push<UserProfileData>( // 明确返回类型
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(initialData: _profileData), // 3. 把当前的状态数据传过去！
      ),
    );

    // 4. 当有新数据返回时，直接用新数据更新整个状态
    if (result != null) {
      setState(() {
        _profileData = result;
      });
    }
  }

  // --- 新增：页面首次加载时，从后端获取一次数据 ---
  @override
  void initState() {
    super.initState();
    _fetchProfile(); // 页面一显示就去加载数据
  }

  Future<void> _fetchProfile() async {
    final String apiUrl = 'http://10.61.193.166:3000'; // ！！！！请务必替换为您自己的IP地址！！！！
    try {
      final response = await http.get(Uri.parse('$apiUrl/api/profile'));
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body)['data'];
        setState(() {
          _profileData = UserProfileData(
            nickname: data['nickname'],
            introduction: data['introduction'],
            birthDate: data['birthDate'],
            avatarUrl: data['avatarUrl'],
          );
        });
      }
    } catch (e) {
      print('获取个人信息失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 5. 使用新的数据模型来显示UI
              CircleAvatar(radius: 40, backgroundImage: NetworkImage(_profileData.avatarUrl)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_profileData.nickname, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_profileData.introduction, style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Theme.of(context).hintColor)),
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
                onTap: _navigateToEditProfile, // 7. 绑定新的跳转方法
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('设置'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => print('点击设置'),
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