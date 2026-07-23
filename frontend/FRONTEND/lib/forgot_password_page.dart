import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  // ================= CONTROLLERS =================
  final uidCtrl = TextEditingController();
  final otpCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  // ================= FOCUS NODES (ANDROID FIX) =================
  final FocusNode uidFocus = FocusNode();
  final FocusNode otpFocus = FocusNode();
  final FocusNode newPassFocus = FocusNode();
  final FocusNode confirmPassFocus = FocusNode();

  int step = 1;
  bool loading = false;

  bool _showPass = false;
  bool _showConfirm = false;

  final baseUrl = "https://skillsphere-2-qanz.onrender.com";

  void showMsg(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ================= API CALLS =================

  Future<void> sendOtp() async {
    if (uidCtrl.text.isEmpty) {
      showMsg("Please enter UID", isError: true);
      return;
    }

    setState(() => loading = true);

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/forgot_password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"uid": uidCtrl.text.trim()}),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        showMsg("OTP sent to your email");
        setState(() => step = 2);
        Future.delayed(const Duration(milliseconds: 100), () {
          otpFocus.requestFocus();
        });
      } else {
        showMsg(data["error"] ?? "Failed to send OTP", isError: true);
      }
    } catch (_) {
      showMsg("Network Error", isError: true);
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> verifyOtp() async {
    if (otpCtrl.text.isEmpty) {
      showMsg("Please enter OTP", isError: true);
      return;
    }

    setState(() => loading = true);

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/verify_forgot_otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "uid": uidCtrl.text.trim(),
          "otp": otpCtrl.text.trim(),
        }),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        showMsg("OTP Verified Successfully");

        // 🔥 ANDROID KEYBOARD RESET (CRITICAL)
        FocusScope.of(context).unfocus();

        setState(() => step = 3);

        // 🔥 FORCE ALPHANUMERIC KEYBOARD
        Future.delayed(const Duration(milliseconds: 150), () {
          newPassFocus.requestFocus();
        });
      } else {
        showMsg(data["error"] ?? "Invalid OTP", isError: true);
      }
    } catch (_) {
      showMsg("Network Error", isError: true);
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> resetPassword() async {
    final pw = passCtrl.text;
    if (pw.length < 8) {
      showMsg("Password must be at least 8 characters", isError: true);
      return;
    }
    if (!RegExp(r'[A-Z]').hasMatch(pw)) {
      showMsg("Password needs at least one uppercase letter", isError: true);
      return;
    }
    if (!RegExp(r'[a-z]').hasMatch(pw)) {
      showMsg("Password needs at least one lowercase letter", isError: true);
      return;
    }
    if (!RegExp(r'[0-9]').hasMatch(pw)) {
      showMsg("Password needs at least one digit", isError: true);
      return;
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) {
      showMsg("Password needs at least one special character", isError: true);
      return;
    }

    if (passCtrl.text != confirmCtrl.text) {
      showMsg("Passwords do not match", isError: true);
      return;
    }

    setState(() => loading = true);

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/reset_password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "uid": uidCtrl.text.trim(),
          "new_password": passCtrl.text,
          "confirm_password": confirmCtrl.text,
        }),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        showMsg("Password reset successful! Please login.");
        if (mounted) Navigator.pop(context);
      } else {
        showMsg(data["error"] ?? "Reset failed", isError: true);
      }
    } catch (_) {
      showMsg("Network Error", isError: true);
    } finally {
      setState(() => loading = false);
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a1a3e),
              Color(0xFF0f1e3e),
              Color(0xFF1a0f3e),
              Color(0xFF2d1b4e),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (step == 1) ...[
                          _GlassField(
                            controller: uidCtrl,
                            hint: "Enter UID",
                            icon: Icons.badge_outlined,
                            isNumber: true,
                            focusNode: uidFocus,
                          ),
                          const SizedBox(height: 20),
                          _ActionButton(
                            text: "SEND OTP",
                            loading: loading,
                            onTap: sendOtp,
                          ),
                        ],
                        if (step == 2) ...[
                          _GlassField(
                            controller: otpCtrl,
                            hint: "Enter OTP",
                            icon: Icons.vpn_key_outlined,
                            isNumber: true,
                            focusNode: otpFocus,
                          ),
                          const SizedBox(height: 20),
                          _ActionButton(
                            text: "VERIFY OTP",
                            loading: loading,
                            onTap: verifyOtp,
                          ),
                        ],
                        if (step == 3) ...[
                          _GlassField(
                            controller: passCtrl,
                            hint: "New Password",
                            icon: Icons.lock_outline,
                            isPass: true,
                            focusNode: newPassFocus,
                            showPass: _showPass,
                            onToggle: () =>
                                setState(() => _showPass = !_showPass),
                          ),
                          const SizedBox(height: 4),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "8+ characters, with uppercase, lowercase, a digit and a special character.",
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _GlassField(
                            controller: confirmCtrl,
                            hint: "Confirm Password",
                            icon: Icons.lock_reset,
                            isPass: true,
                            focusNode: confirmPassFocus,
                            showPass: _showConfirm,
                            onToggle: () =>
                                setState(() => _showConfirm = !_showConfirm),
                          ),
                          const SizedBox(height: 20),
                          _ActionButton(
                            text: "RESET PASSWORD",
                            loading: loading,
                            onTap: resetPassword,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================= SUPPORT WIDGETS =================

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final IconData icon;
  final bool isPass;
  final bool showPass;
  final VoidCallback? onToggle;
  final bool isNumber;

  const _GlassField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.isPass = false,
    this.showPass = false,
    this.onToggle,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      focusNode: focusNode,
      controller: controller,
      obscureText: isPass && !showPass,

      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(
              signed: false,
              decimal: false,
            )
          : TextInputType.visiblePassword,

      enableSuggestions: false,
      autocorrect: false,
      textInputAction: TextInputAction.done,

      inputFormatters:
          isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,

      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: isPass
            ? IconButton(
                icon: Icon(
                  showPass ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54,
                ),
                onPressed: onToggle,
              )
            : null,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool loading;

  const _ActionButton({
    required this.text,
    required this.onTap,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        child: loading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(text),
      ),
    );
  }
}
