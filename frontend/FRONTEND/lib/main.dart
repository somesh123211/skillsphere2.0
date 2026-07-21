import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'login_signup_page.dart';
import 'student_dashboard.dart';
import 'session_storage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skill Sphere',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const SplashGate(),
      routes: {
        // You can define named routes if needed later
      },
    );
  }
}

// Checks for a saved session on launch so a student isn't forced to log in
// again every time the app/tab is closed and reopened. The token is always
// re-verified against the server (not just trusted from local storage) -
// if it's expired or invalid, the saved session is cleared and the student
// lands on the normal login screen instead.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  final String baseUrl = "http://localhost:5000";

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final token = await SessionStorage.loadToken();
    final studentData = await SessionStorage.loadStudentData();

    if (token == null || studentData == null) {
      _goToLogin();
      return;
    }

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/get_student_profile"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _goToDashboard(token, studentData);
      } else {
        await SessionStorage.clearSession();
        _goToLogin();
      }
    } catch (_) {
      // Network hiccup on launch - don't strand the student on a blank
      // screen or force a fresh login for what might just be a slow
      // connection; let them straight into the dashboard with the saved
      // session, same as before this feature existed. Any real auth
      // problem still gets caught by the dashboard's own API calls.
      _goToDashboard(token, studentData);
    }
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginSignupPage()),
    );
  }

  void _goToDashboard(String token, Map<String, dynamic> studentData) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => StudentDashboard(token: token, studentData: studentData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F0F13),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
      ),
    );
  }
}
