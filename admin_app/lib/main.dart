import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'login_page.dart';
import 'dashboard_page.dart';
import 'admin_session.dart';
import 'admin_session_storage.dart';

void main() {
  runApp(AdminApp());
}

class AdminApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AdminSplashGate(),
    );
  }
}

class AdminSplashGate extends StatefulWidget {
  const AdminSplashGate({Key? key}) : super(key: key);

  @override
  State<AdminSplashGate> createState() => _AdminSplashGateState();
}

class _AdminSplashGateState extends State<AdminSplashGate> {
  final String baseUrl = "https://skillsphere2-0.onrender.com";

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final token = await AdminSessionStorage.loadToken();
    final adminData = await AdminSessionStorage.loadAdminData();

    if (token == null || adminData == null) {
      _goToLogin();
      return;
    }

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/admin/me"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _goToDashboard(token, adminData);
      } else {
        await AdminSessionStorage.clearSession();
        _goToLogin();
      }
    } catch (_) {
      // If network fails temporarily, load dashboard from saved session
      _goToDashboard(token, adminData);
    }
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _goToDashboard(String token, Map<String, dynamic> adminData) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DashboardPage(
          session: AdminSession.fromLogin(token, adminData),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF121212),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFFE5B80B)),
      ),
    );
  }
}
