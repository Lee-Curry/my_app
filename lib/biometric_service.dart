import 'package:local_auth/local_auth.dart';
import 'package:flutter/material.dart'; // 引入 Material
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  // 👇 1. 全局状态监听器 (默认 false)
  static final ValueNotifier<bool> appLockEnabledNotifier = ValueNotifier(false);

  // 👇 2. 初始化：App 启动时读取本地设置
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('app_lock_enabled') ?? false;
    appLockEnabledNotifier.value = enabled;
  }

  // 👇 3. 更新设置：设置页调用这个
  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', value);
    appLockEnabledNotifier.value = value;
  }

  static Future<bool> canAuthenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      if (!await canAuthenticate()) return true;
      return await _auth.authenticate(
        localizedReason: '请验证身份以进入晗伴',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (e) {
      print("认证错误: $e");
      return false;
    }
  }
}