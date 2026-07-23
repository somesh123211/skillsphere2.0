import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'reset_password_page.dart';

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

class ForgotPasswordPage extends StatefulWidget {
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailCtrl = TextEditingController();
  final baseUrl = "https://skillsphere-2-qanz.onrender.com"; // Updated to match your Login Page config

  Future<void> sendOtp() async {
    // Basic validation to prevent empty calls
    if (emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email")),
      );
      return;
    }

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/api/admin/forgot_password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": emailCtrl.text.trim()}),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordPage(email: emailCtrl.text.trim()),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data["error"] ?? "Error sending OTP"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint("Forgot password error: $e");
      if (!mounted) return;
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
        title: const Text("Reset Password"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: AurumColors.textWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
        iconTheme: const IconThemeData(color: AurumColors.accentGold),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               const Text(
                "Forgot Password?",
                style: TextStyle(
                  color: AurumColors.textWhite,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Enter your registered email address to receive an OTP.",
                style: TextStyle(color: AurumColors.textGrey, fontSize: 14),
              ),
              const SizedBox(height: 40),

              // Styled Email Field
              TextField(
                controller: emailCtrl,
                style: const TextStyle(color: AurumColors.textWhite),
                cursorColor: AurumColors.accentGold,
                decoration: InputDecoration(
                  labelText: "Admin Email",
                  labelStyle: const TextStyle(color: AurumColors.textGrey),
                  prefixIcon: const Icon(Icons.email_outlined, color: AurumColors.accentGold),
                  filled: true,
                  fillColor: AurumColors.surfaceDark,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AurumColors.accentGold),
                  ),
                ),
              ),
              
              const SizedBox(height: 30),

              // Gold Gradient Button
              InkWell(
                onTap: sendOtp,
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
                  child: const Text(
                    "SEND OTP",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}