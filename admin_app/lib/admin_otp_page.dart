import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dashboard_page.dart';
import 'admin_session.dart';

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

class AdminOtpPage extends StatefulWidget {
  final String email;

  const AdminOtpPage({Key? key, required this.email}) : super(key: key);

  @override
  State<AdminOtpPage> createState() => _AdminOtpPageState();
}

class _AdminOtpPageState extends State<AdminOtpPage> {
  final otpCtrl = TextEditingController();
  bool loading = false;

  final String baseUrl = "http://localhost:5000";

  Future<void> verifyOtp() async {
    if (otpCtrl.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter valid 6-digit OTP"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/admin/verify-login-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": widget.email,
          "otp": otpCtrl.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        if (!mounted) return;
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data["error"] ?? "Invalid OTP"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      debugPrint("OTP verify error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unable to connect to the server. Please try again."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      appBar: AppBar(
        title: const Text("Two-Step Verification"),
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
            children: [
              // Icon Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AurumColors.accentGold.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  size: 60,
                  color: AurumColors.accentGold,
                ),
              ),
              const SizedBox(height: 30),

              const Text(
                "Verification Code",
                style: TextStyle(
                  color: AurumColors.textWhite,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "We have sent a One Time Password (OTP) to:",
                style:
                    const TextStyle(color: AurumColors.textGrey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 5),
              Text(
                widget.email,
                style: const TextStyle(
                  color: AurumColors.accentGold,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // OTP Input Field
              TextField(
                controller: otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(
                  color: AurumColors.textWhite,
                  fontSize: 18,
                  letterSpacing: 4.0, // Space out the numbers
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                cursorColor: AurumColors.accentGold,
                decoration: InputDecoration(
                  labelText: "Enter 6-Digit OTP",
                  labelStyle: const TextStyle(
                      color: AurumColors.textGrey, letterSpacing: 1.0),
                  counterStyle: const TextStyle(color: AurumColors.textGrey),
                  filled: true,
                  fillColor: AurumColors.surfaceDark,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AurumColors.accentGold, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Gold Gradient Button
              InkWell(
                onTap: loading ? null : verifyOtp,
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
                          "VERIFY & LOGIN",
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
