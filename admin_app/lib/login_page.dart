import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'admin_otp_page.dart';
import 'forgot_password_page.dart';
import 'dashboard_page.dart';
import 'admin_session.dart';
import 'admin_session_storage.dart';

// --- AURUM THEME COLORS ---
class AurumColors {
  static const Color backgroundBlack = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color goldStart = Color(0xFFF2D06B);
  static const Color goldEnd = Color(0xFFC7930D);
  static const Color accentGold = Color(0xFFE5B80B);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFFAAAAAA);

  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldStart, goldEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();

  final String baseUrl = "https://skillsphere-2-qanz.onrender.com";
  bool loading = false;

  bool _obscurePassword = true;

  Future<void> loginAdmin() async {
    if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email and password required"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/admin/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailCtrl.text.trim(),
          "password": passCtrl.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      // OTP FLOW
      if (response.statusCode == 200 && data["otp_required"] == true) {
        setState(() => loading = false);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminOtpPage(
              email: emailCtrl.text.trim(),
            ),
          ),
        );
        return;
      }

      // DIRECT LOGIN
      if (response.statusCode == 200 && data.containsKey("token")) {
        await AdminSessionStorage.saveSession(data["token"], data["admin"]);
        setState(() => loading = false);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardPage(
              session: AdminSession.fromLogin(data["token"], data["admin"]),
            ),
          ),
        );
        return;
      }

      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data["error"] ?? "Login failed"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      debugPrint("Admin login error: $e");
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unable to connect to the server. Please try again."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      appBar: AppBar(
        title: const Text("Admin Access"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: AurumColors.textWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Welcome Back",
                style: TextStyle(
                  color: AurumColors.textWhite,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Enter your credentials to access the dashboard.",
                style: TextStyle(color: AurumColors.textGrey, fontSize: 14),
              ),
              const SizedBox(height: 40),
              _buildAurumTextField(
                controller: emailCtrl,
                label: "Email Address",
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 20),
              _buildAurumTextField(
                controller: passCtrl,
                label: "Password",
                icon: Icons.lock_outline,
                isPassword: true,
                isObscured: _obscurePassword,
                onToggleVisibility: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              const SizedBox(height: 40),
              InkWell(
                onTap: loading ? null : loginAdmin,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: AurumColors.goldGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AurumColors.accentGold.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: loading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          "LOGIN",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1.1,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 25),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ForgotPasswordPage(),
                      ),
                    );
                  },
                  child: const Text(
                    "Forgot Password?",
                    style: TextStyle(color: AurumColors.textGrey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAurumTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isObscured = false,
    VoidCallback? onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? isObscured : false,
      style: const TextStyle(color: AurumColors.textWhite),
      cursorColor: AurumColors.accentGold,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AurumColors.textGrey),
        prefixIcon: Icon(icon, color: AurumColors.accentGold),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  isObscured ? Icons.visibility_off : Icons.visibility,
                  color: AurumColors.textGrey,
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        filled: true,
        fillColor: AurumColors.surfaceDark,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AurumColors.accentGold),
        ),
      ),
    );
  }
}
