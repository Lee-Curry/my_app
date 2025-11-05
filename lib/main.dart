// === main.dart (黄金版 - 功能完整，非持久化 - 完整代码) ===

import 'package:flutter/material.dart';
import 'login_page.dart';
import 'edit_profile_page.dart';
import 'ai_chat_page.dart';

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
  bool _isLoggedIn = false;

  void _toggleTheme() {
    setState(() {
      _themeMode =
      _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  void _handleLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
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
      home: _isLoggedIn
          ? MainScreen(onThemeModeChanged: _toggleTheme, onLogout: _handleLogout)
          : WelcomePage(onLoginSuccess: _handleLoginSuccess),
    );
  }
}

// --- App 主框架 ---
class MainScreen extends StatefulWidget {
  final VoidCallback onThemeModeChanged;
  final VoidCallback onLogout;
  const MainScreen(
      {super.key, required this.onThemeModeChanged, required this.onLogout});

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
            onPressed: widget.onThemeModeChanged,
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: <Widget>[
          const HomePage(),
          ProfilePage(onLogout: widget.onLogout),
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

// --- 首页 ---
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
                    Icon(Icons.photo_library,
                        size: 48, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    const Text('照片墙',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
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
                print('点击了AI助手');
                // 【核心改动】
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AiChatPage()),
                );
              },
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.secondary),
                    const SizedBox(height: 16),
                    const Text('AI 助手',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
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

// --- “我”的页面 (带状态管理和数据传递) ---
class ProfilePage extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfilePage({super.key, required this.onLogout});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // 初始的、写死的默认数据
  UserProfileData _profileData = UserProfileData(
    nickname: '科技爱好者',
    introduction: '这家伙很酷，什么也没留下...',
    avatarUrl: 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?q=80&w=1887&auto-format=fit=crop',
    birthDate: '1999-10-01',
  );

  // 跳转到编辑页，并等待返回结果
  Future<void> _navigateToEditProfile() async {
    final result = await Navigator.push<UserProfileData>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(initialData: _profileData),
      ),
    );
    // 如果有结果返回，就用新数据更新UI
    if (result != null) {
      setState(() {
        _profileData = result;
      });
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
              CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(_profileData.avatarUrl)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_profileData.nickname,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_profileData.introduction,
                        style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context).hintColor)),
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
                onTap: () => print('点击设置'),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('关于我们'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => print('点击关于我们'),
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