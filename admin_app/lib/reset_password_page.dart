import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

class ResetPasswordPage extends StatefulWidget {
  final String email;
  const ResetPasswordPage({super.key, required this.email});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final otpCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  final baseUrl = "https://skillsphere2-0.onrender.com";

  bool loading = false;

  // Visibility Toggles
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  Future<void> resetPassword() async {
    if (otpCtrl.text.isEmpty ||
        passCtrl.text.isEmpty ||
        confirmCtrl.text.isEmpty) {
      showError("All fields are required");
      return;
    }

    if (passCtrl.text != confirmCtrl.text) {
      showError("Passwords do not match");
      return;
    }

    setState(() => loading = true);

    try {
      // ---------------- VERIFY OTP ----------------
      final verify = await http.post(
        Uri.parse("$baseUrl/api/admin/verify_otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": widget.email,
          "otp": otpCtrl.text.trim(),
        }),
      );

      final verifyData = jsonDecode(verify.body);

      if (verify.statusCode != 200) {
        setState(() => loading = false);
        showError(verifyData["error"] ?? "OTP verification failed");
        return;
      }

      // ---------------- RESET PASSWORD ----------------
      final reset = await http.post(
        Uri.parse("$baseUrl/api/admin/reset_password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": widget.email,
          "new_password": passCtrl.text.trim(),
        }),
      );

      setState(() => loading = false);

      final resetData = jsonDecode(reset.body);

      if (reset.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Password reset successful"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        showError(resetData["error"] ?? "Password reset failed");
      }
    } catch (e) {
      debugPrint("Admin reset password error: $e");
      setState(() => loading = false);
      showError("Unable to connect to the server. Please try again.");
    }
  }

  void showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AurumColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AurumColors.accentGold.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mark_email_read,
                      color: AurumColors.accentGold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Resetting for: ${widget.email}",
                      style: const TextStyle(
                          color: AurumColors.textGrey, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // OTP Field
            _buildAurumTextField(
              controller: otpCtrl,
              label: "Enter OTP Code",
              icon: Icons.pin,
              inputType: TextInputType.number,
            ),
            const SizedBox(height: 20),

            // New Password Field
            _buildAurumTextField(
              controller: passCtrl,
              label: "New Password",
              icon: Icons.lock_outline,
              isPassword: true,
              isObscured: _obscurePass,
              onToggleVisibility: () =>
                  setState(() => _obscurePass = !_obscurePass),
            ),
            const SizedBox(height: 6),
            const Text(
              "8+ characters, with uppercase, lowercase, a digit and a special character.",
              style: TextStyle(color: AurumColors.textGrey, fontSize: 11),
            ),
            const SizedBox(height: 20),

            // Confirm Password Field
            _buildAurumTextField(
              controller: confirmCtrl,
              label: "Confirm Password",
              icon: Icons.lock_reset,
              isPassword: true,
              isObscured: _obscureConfirm,
              onToggleVisibility: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            const SizedBox(height: 40),

            // Gold Gradient Button
            InkWell(
              onTap: loading ? null : resetPassword,
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
                        "RESET PASSWORD",
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
    );
  }

  // --- Helper Widget for Fields ---
  Widget _buildAurumTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isObscured = false,
    TextInputType inputType = TextInputType.text,
    VoidCallback? onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? isObscured : false,
      keyboardType: inputType,
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
