import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';

class StorageService {
  static const String _keyUsername = 'saved_username';
  static const String _keyPassword = 'saved_password';
  static const String _keyToken = 'saved_token';
  static const String _keyExpiresAt = 'token_expires_at';
  static const String _keyUserInfo = 'user_info';

  static SharedPreferences? _prefs;

  /// 检查是否已初始化
  static bool get isInitialized => _prefs != null;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ==================== 账号密码 ====================
  static Future<void> saveCredentials(String username, String password) async {
    await _prefs?.setString(_keyUsername, username);
    await _prefs?.setString(_keyPassword, password);
  }

  static String? getSavedUsername() => _prefs?.getString(_keyUsername);
  static String? getSavedPassword() => _prefs?.getString(_keyPassword);

  // ==================== Token ====================
  static Future<void> saveToken(String token, DateTime expiresAt) async {
    await _prefs?.setString(_keyToken, token);
    await _prefs?.setString(_keyExpiresAt, expiresAt.toIso8601String());
  }

  static String? getToken() => _prefs?.getString(_keyToken);

  static DateTime? getTokenExpiresAt() {
    final str = _prefs?.getString(_keyExpiresAt);
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  static bool isTokenValid() {
    final token = getToken();
    final expiresAt = getTokenExpiresAt();
    if (token == null || expiresAt == null) return false;
    return DateTime.now().isBefore(expiresAt);
  }

  // ==================== 用户信息 ====================
  static Future<void> saveUserInfo(UserInfo user) async {
    final json = {
      'id': user.id,
      'username': user.username,
      'real_name': user.realName,
      'role': user.role,
      'team_id': user.teamId,
      'team_name': user.teamName,
      'status': user.status,
    };
    await _prefs?.setString(_keyUserInfo, jsonEncode(json));
  }

  static UserInfo? getUserInfo() {
    final str = _prefs?.getString(_keyUserInfo);
    if (str == null) return null;
    try {
      final json = jsonDecode(str);
      return UserInfo.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  // ==================== 清除登录信息 ====================
  static Future<void> clearAuth() async {
    await _prefs?.remove(_keyToken);
    await _prefs?.remove(_keyExpiresAt);
    await _prefs?.remove(_keyUserInfo);
    // 保留账号密码
  }

  static Future<void> clearAll() async {
    await _prefs?.clear();
  }
}