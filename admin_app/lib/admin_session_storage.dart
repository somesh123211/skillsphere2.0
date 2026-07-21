import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSessionStorage {
  static const _tokenKey = "admin_token";
  static const _adminDataKey = "admin_data";

  static Future<void> saveSession(String token, Map<String, dynamic> adminData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_adminDataKey, jsonEncode(adminData));
  }

  static Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<Map<String, dynamic>?> loadAdminData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_adminDataKey);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_adminDataKey);
  }
}
