import 'dart:async';
import 'dart:convert';
import 'dart:ui'; // Required for BackdropFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'student_dashboard.dart';
import 'forgot_password_page.dart';
import 'session_storage.dart';

class LoginSignupPage extends StatefulWidget {
  const LoginSignupPage({super.key});

  @override
  State<LoginSignupPage> createState() => _LoginSignupPageState();
}

class _LoginSignupPageState extends State<LoginSignupPage> {
  final _formKey = GlobalKey<FormState>();

  // ================= STATE VARIABLES =================
  bool isLogin = true;
  bool isLoading = false;
  bool otpSent = false;

  bool _showPassword = false;
  bool _showConfirm = false;

  int _otpCooldown = 0;
  Timer? _otpTimer;

  // CHANGE THIS TO YOUR IP IF ON REAL DEVICE
  final String baseUrl = "https://skillsphere2-0.onrender.com";

  // ================= CONTROLLERS =================
  final nameController = TextEditingController();
  final uidController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final otpController = TextEditingController();

  // ================= FIXED / OPTION VALUES =================
  String selectedYear = '1ST YEAR';
  String selectedBranch = 'AI';

  final List<String> yearOptions = const [
    '1ST YEAR',
    '2ND YEAR',
    '3RD YEAR',
    '4TH YEAR',
  ];

  final Map<String, String> departmentOptions = const {
    'AI': 'Artificial Intelligence (AI)',
    'DS': 'Data Science (DS)',
    'CSE': 'Computer Science & Eng (CSE)',
    'IT': 'Information Technology (IT)',
    'ETC': 'Electronics & Telecomm (ETC)',
    'MECH': 'Mechanical Engineering (MECH)',
    'CIVIL': 'Civil Engineering (CIVIL)',
    'EE': 'Electrical Engineering (EE)',
    'CS-CY': 'Cyber Security (CS-CY)',
    'CSBS': 'CS & Business Systems (CSBS)',
    'IIOT': 'Industrial IOT (IIOT)',
    'RAI': 'Robotics & AI (RAI)',
  };

  @override
  void dispose() {
    nameController.dispose();
    uidController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    otpController.dispose();
    _otpTimer?.cancel();
    super.dispose();
  }

  // ================= LOGIC METHODS =================

  void _toggleMode() {
    setState(() {
      isLogin = !isLogin;
      otpSent = false;
      _otpCooldown = 0;
      _otpTimer?.cancel();
      _formKey.currentState?.reset();

      if (isLogin) {
        nameController.clear();
        uidController.clear();
      }
    });
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text.trim(),
          "password": passwordController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final studentData = Map<String, dynamic>.from(data["student"]);
        await SessionStorage.saveSession(data["token"], studentData);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StudentDashboard(
              token: data["token"],
              studentData: studentData,
            ),
          ),
        );
      } else {
        showMsg(data["message"] ?? data["error"] ?? "Login failed",
            isError: true);
      }
    } catch (e) {
      print("Login Error: $e");
      showMsg("Network error: Check server connection", isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> sendOtp() async {
    if (emailController.text.trim().isEmpty) {
      showMsg("Enter email first", isError: true);
      return;
    }

    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/send_otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": emailController.text.trim()}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        showMsg("OTP sent to email", isError: false);
        setState(() {
          otpSent = true;
          _otpCooldown = 60;
        });
        _startOtpTimer();
      } else {
        showMsg(data["message"] ?? "Failed to send OTP", isError: true);
      }
    } catch (_) {
      showMsg("OTP network error", isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!otpSent) return showMsg("Please send OTP first", isError: true);
    if (otpController.text.trim().isEmpty) {
      return showMsg("Enter OTP", isError: true);
    }

    setState(() => isLoading = true);

    final bodyData = {
      "name": nameController.text.trim(),
      "uid": uidController.text.trim(),
      "branch": selectedBranch,
      "year": selectedYear.substring(0, 1),
      "email": emailController.text.trim(),
      "password": passwordController.text.trim(),
      "otp": otpController.text.trim(),
    };
    print("SENDING SIGNUP DATA: $bodyData");

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/verify_otp_and_signup"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(bodyData),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        showMsg("Signup successful. Please Login.", isError: false);
        _toggleMode();
      } else {
        showMsg(data["message"] ?? "Signup failed", isError: true);
        print("SIGNUP FAILED RESPONSE: ${data['message']}");
      }
    } catch (e) {
      print("Signup Network Error: $e");
      showMsg("Signup network error", isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _startOtpTimer() {
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpCooldown > 0) {
        setState(() => _otpCooldown--);
      } else {
        _otpTimer?.cancel();
      }
    });
  }

  void showMsg(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  // ================= UI BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E1B4B),
              Color(0xFF0F172A),
              Color(0xFF1E293B)
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
                top: -40,
                right: 80,
                child: _Blob(200, Colors.cyan.withOpacity(0.25))),
            Positioned(
                top: 40,
                left: -40,
                child: _Blob(300, Colors.purple.withOpacity(0.22))),
            Positioned(
                bottom: -80,
                left: 120,
                child: _Blob(250, Colors.pink.withOpacity(0.18))),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.15),
                                  width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ShaderMask(
                                    shaderCallback: (bounds) => const LinearGradient(
                                      colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                                    ).createShader(bounds),
                                    child: Text(
                                      isLogin ? "WELCOME BACK" : "CREATE ACCOUNT",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    isLogin
                                        ? "Sign in to access your Skill Sphere dashboard"
                                        : "Register your student profile",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  if (!isLogin) ...[
                                    _GlassTextFormField(
                                      controller: nameController,
                                      hintText: "Full Name",
                                      icon: Icons.person_outline,
                                      validator: (v) => (v ?? '').isEmpty
                                          ? "Name required"
                                          : null,
                                    ),
                                    const SizedBox(height: 12),
                                    _GlassTextFormField(
                                      controller: uidController,
                                      hintText: "UID Number (Must be Unique)",
                                      icon: Icons.badge_outlined,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(12)
                                      ],
                                      validator: (v) => (v ?? '').isEmpty
                                          ? "UID required"
                                          : null,
                                    ),
                                    const SizedBox(height: 12),
                                    _GlassDropdown<String>(
                                      value: selectedBranch,
                                      items: departmentOptions,
                                      icon: Icons.domain_rounded,
                                      label: "Department",
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => selectedBranch = val);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    _SegmentedButton<String>(
                                      values: yearOptions,
                                      selected: selectedYear,
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => selectedYear = val);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  _GlassTextFormField(
                                    controller: emailController,
                                    hintText: "University Email",
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) => !(v ?? '').contains("@")
                                        ? "Invalid Email"
                                        : null,
                                  ),
                                  const SizedBox(height: 12),
                                  _GlassTextFormField(
                                    controller: passwordController,
                                    hintText: "Password",
                                    icon: Icons.lock_outline,
                                    isPassword: true,
                                    isObscurable: true,
                                    showObscure: _showPassword,
                                    onToggleObscure: () => setState(
                                        () => _showPassword = !_showPassword),
                                    // Only enforce the strength rule when
                                    // setting a NEW password (signup) - an
                                    // existing student logging in must
                                    // never be blocked by a policy that
                                    // postdates their account.
                                    validator: isLogin
                                        ? null
                                        : (v) {
                                            final val = v ?? '';
                                            if (val.length < 8) {
                                              return "Min 8 characters";
                                            }
                                            if (!RegExp(r'[A-Z]').hasMatch(val)) {
                                              return "Add an uppercase letter";
                                            }
                                            if (!RegExp(r'[a-z]').hasMatch(val)) {
                                              return "Add a lowercase letter";
                                            }
                                            if (!RegExp(r'[0-9]').hasMatch(val)) {
                                              return "Add a digit";
                                            }
                                            if (!RegExp(r'[^A-Za-z0-9]').hasMatch(val)) {
                                              return "Add a special character";
                                            }
                                            return null;
                                          },
                                  ),
                                  if (!isLogin) ...[
                                    const SizedBox(height: 4),
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        "8+ characters, with uppercase, lowercase, a digit and a special character.",
                                        style: TextStyle(
                                            color: Colors.white70, fontSize: 11),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _GlassTextFormField(
                                      controller: confirmPasswordController,
                                      hintText: "Confirm Password",
                                      icon: Icons.lock_reset_outlined,
                                      isPassword: true,
                                      isObscurable: true,
                                      showObscure: _showConfirm,
                                      onToggleObscure: () => setState(
                                          () => _showConfirm = !_showConfirm),
                                      validator: (v) =>
                                          v != passwordController.text
                                              ? "Passwords don't match"
                                              : null,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _GlassTextFormField(
                                            controller: otpController,
                                            hintText: "OTP",
                                            icon: Icons.vpn_key_outlined,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                  6)
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        _OtpButton(
                                          text: _otpCooldown > 0
                                              ? "${_otpCooldown}s"
                                              : "Send OTP",
                                          onTap: (_otpCooldown > 0 || isLoading)
                                              ? null
                                              : sendOtp,
                                          isActive: _otpCooldown == 0,
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 28),
                                  if (isLoading)
                                    const CircularProgressIndicator(
                                        color: Color(0xFF38BDF8))
                                  else
                                    _ActionButton(
                                      text: isLogin ? "LOGIN" : "REGISTER NOW",
                                      onTap: isLogin ? login : signup,
                                    ),
                                  const SizedBox(height: 20),
                                  if (isLogin)
                                    TextButton(
                                      onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) =>
                                                  const ForgotPasswordPage())),
                                      child: const Text("Forgot Password?",
                                          style:
                                              TextStyle(color: Colors.white70)),
                                    ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        isLogin
                                            ? "Don't have an account? "
                                            : "Already have an account? ",
                                        style: const TextStyle(
                                            color: Colors.white60),
                                      ),
                                      GestureDetector(
                                        onTap: _toggleMode,
                                        child: const Text(
                                          "Switch Here",
                                          style: TextStyle(
                                            color: Color(0xFF38BDF8),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // ================= FOOTER =================
                    const Text(
                      "Designed and Developed by YSBP",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= CUSTOM WIDGETS =================

class _GlassDropdown<T> extends StatelessWidget {
  final T value;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;
  final IconData icon;
  final String label;

  const _GlassDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04)
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF38BDF8).withOpacity(0.3), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E293B),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF38BDF8)),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: items.entries.map((entry) {
            return DropdownMenuItem<T>(
              value: entry.key,
              child: Row(
                children: [
                  Icon(icon, color: Colors.white70, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ================= CUSTOM WIDGETS =================

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob(this.size, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(colors: [color, Colors.transparent]),
        borderRadius: BorderRadius.circular(size / 2),
      ),
    );
  }
}

class _GlassTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? icon;
  final bool isPassword;
  final bool isObscurable;
  final bool? showObscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _GlassTextFormField({
    required this.controller,
    required this.hintText,
    this.icon,
    this.isPassword = false,
    this.isObscurable = false,
    this.showObscure,
    this.onToggleObscure,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05)
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF00d4ff).withOpacity(0.3), width: 1),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isObscurable ? (showObscure ?? true) : isPassword,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        validator: validator,
        decoration: InputDecoration(
          prefixIcon:
              icon != null ? Icon(icon, color: Colors.white70, size: 20) : null,
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: isObscurable
              ? IconButton(
                  icon: Icon(
                    (showObscure ?? true)
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.white70,
                    size: 20,
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
        ),
      ),
    );
  }
}

class _LockedField extends StatelessWidget {
  final String text;
  const _LockedField({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFff9f43).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFff9f43).withOpacity(0.5), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.lock_clock_outlined,
              color: Color(0xFFff9f43), size: 18),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SegmentedButton<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;

  const _SegmentedButton(
      {required this.values, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: values.map((v) {
        final isSelected = v == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(v),
            child: Container(
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF00d4ff)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Center(
                child: Text(
                  v.toString(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _OtpButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isActive;

  const _OtpButton({required this.text, this.onTap, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        width: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              isActive ? const Color(0xFFff9f43) : Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white60,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _ActionButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF00d4ff), Color(0xFF0080ff)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00d4ff).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
