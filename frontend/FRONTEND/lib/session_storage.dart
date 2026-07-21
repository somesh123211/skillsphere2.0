import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Keeps the student logged in across app restarts/browser refreshes.
// The token itself is still verified fresh on every app launch (see
// main.dart's SplashGate) against /get_student_profile - this only avoids
// making the student type their password in again when the token is
// still valid.
class SessionStorage {
  static const _tokenKey = "student_token";
  static const _studentDataKey = "student_data";

  static Future<void> saveSession(String token, Map<String, dynamic> studentData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_studentDataKey, jsonEncode(studentData));
  }

  static Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<Map<String, dynamic>?> loadStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_studentDataKey);
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
    await prefs.remove(_studentDataKey);
  }
}
