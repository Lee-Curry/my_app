import 'package:flutter/material.dart';
import 'biometric_service.dart';

class AppLockWrapper extends StatefulWidget {
  final Widget child;
  const AppLockWrapper({super.key, required this.child});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> with WidgetsBindingObserver {
  bool _isLocked = false; // 当前是否处于锁定显示状态
  bool _isAuthenticating = false; // 防止验证过程中重复触发
  bool _isInBackground = false; // 标记是否在后台

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 监听开关变化（如果在设置页关了，立马解锁）
    BiometricService.appLockEnabledNotifier.addListener(_onSettingChanged);

    // 启动时检查：如果开启了，且不是第一次启动(这里简单处理，启动默认先不锁，切后台才锁)
    // 如果你想启动就锁，这里可以设 _isLocked = BiometricService.appLockEnabledNotifier.value;
    if (BiometricService.appLockEnabledNotifier.value) {
      _verify(); // 启动立刻验证
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    BiometricService.appLockEnabledNotifier.removeListener(_onSettingChanged);
    super.dispose();
  }

  void _onSettingChanged() {
    if (mounted) {
      // 如果用户关掉了开关，立马解锁
      if (!BiometricService.appLockEnabledNotifier.value) {
        setState(() => _isLocked = false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!BiometricService.appLockEnabledNotifier.value) return;

    // 1. 切后台 -> 立即上锁
    if (state == AppLifecycleState.paused) {
      _isInBackground = true;
      // 只有当前没在验证时，才上锁（防止验证弹窗本身导致的 pause）
      if (!_isAuthenticating) {
        setState(() => _isLocked = true);
      }
    }
    // 2. 切前台 -> 发起验证
    else if (state == AppLifecycleState.resumed) {
      _isInBackground = false;
      if (_isLocked) {
        _verify();
      }
    }
  }

  Future<void> _verify() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;

    // 稍微延迟一点，确保页面渲染完成
    await Future.delayed(const Duration(milliseconds: 200));

    final success = await BiometricService.authenticate();

    if (mounted) {
      setState(() {
        // 只有验证成功，且当前不在后台（防止验证完秒切后台导致解开），才解锁
        if (success && !_isInBackground) {
          _isLocked = false;
        } else {
          _isLocked = true; // 失败继续锁着
        }
      });
      _isAuthenticating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. 底层：原本的 App 内容 (导航器)
        widget.child,

        // 2. 顶层：锁屏界面 (如果锁定了，就盖在上面)
        if (_isLocked && BiometricService.appLockEnabledNotifier.value)
          Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 80, color: Colors.white),
                  const SizedBox(height: 24),
                  const Text("晗伴已锁定", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.fingerprint),
                    label: const Text("点击验证", style: TextStyle(fontSize: 16)),
                    onPressed: _verify,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}