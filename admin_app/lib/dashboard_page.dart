import 'dart:async';
import 'package:flutter/material.dart';

// Import your pages here
import 'students_list_page.dart';
import 'add_daily_quiz_page.dart';
import 'faculty_quiz_page.dart';
import 'students_marks_menu_page.dart';
import 'login_page.dart';
import 'admin_session.dart';
import 'departments_page.dart';
import 'staff_management_page.dart';

// --- AURUM THEME COLORS ---
class AurumColors {
  static const Color backgroundBlack = Color(0xFF101010);
  static const Color surfaceDark = Color(0xFF1C1C1E);
  static const Color cardSurface = Color(0xFF252525);
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

  static const LinearGradient darkGradient = LinearGradient(
    colors: [surfaceDark, Colors.black],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class DashboardPage extends StatefulWidget {
  final AdminSession session;

  const DashboardPage({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // ⏰ Update real-time clock every second
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get formattedTime {
    final hour = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final minute = _now.minute.toString().padLeft(2, '0');
    final ampm = _now.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $ampm"; // Removed seconds for cleaner look
  }

  String get dateString {
    final List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return "${months[_now.month - 1]} ${_now.day}, ${_now.year}";
  }

  String get _roleLabel {
    switch (widget.session.role) {
      case "super_admin":
        return "Super Admin Access";
      case "admin":
        return "Administrator Access";
      case "hod":
        return "Head of Department";
      case "faculty":
        return "Faculty Access";
      default:
        return "Administrator Access";
    }
  }

  // =========================
  // LOGOUT HANDLER
  // =========================
  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AurumColors.surfaceDark,
        title: const Text("Sign Out", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to log out?",
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => LoginPage()),
                (route) => false,
              );
            },
            child: const Text("Logout",
                style: TextStyle(color: AurumColors.accentGold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      body: SafeArea(
        child: Column(
          children: [
            // =========================
            // CUSTOM APP BAR AREA
            // =========================
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateString.toUpperCase(),
                        style: const TextStyle(
                          color: AurumColors.textGrey,
                          fontSize: 12,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Dashboard",
                        style: const TextStyle(
                          color: AurumColors.textWhite,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AurumColors.surfaceDark,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: AurumColors.accentGold.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_filled,
                            color: AurumColors.accentGold, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          formattedTime,
                          style: const TextStyle(
                            color: AurumColors.textWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),

            // =========================
            // SCROLLABLE CONTENT
            // =========================
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // WELCOME CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        gradient: AurumColors.goldGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AurumColors.accentGold.withOpacity(0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Hello, ${widget.session.name}",
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _roleLabel,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if ((widget.session.isHod || widget.session.isFaculty) &&
                                      widget.session.deptName.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.session.deptName,
                                      style: const TextStyle(
                                        color: Colors.black45,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.verified_user,
                                    color: Colors.black87),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                    const Text(
                      "QUICK ACTIONS",
                      style: TextStyle(
                        color: AurumColors.textGrey,
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // =========================
                    // ACTION TILES (Vertical Layout for better detail)
                    // =========================

                    // 1. Students Management
                    _buildWideActionTile(
                      title: "Manage Students",
                      subtitle: widget.session.isFaculty
                          ? "View student list (read-only)"
                          : "View list, approve registrations & manage profiles",
                      icon: Icons.people_alt_rounded,
                      colorStart: const Color(0xFF6dd5ed), // Subtle blue accent
                      colorEnd: const Color(0xFF2193b0),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                StudentsListPage(session: widget.session)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        // 2. Ai Quiz (Left)
                        Expanded(
                          child: _buildSquareActionTile(
                            title: "Ai Quiz",
                            icon: Icons.timer_outlined,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => AddDailyQuizPage(
                                      session: widget.session)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // 3. Faculty Quiz (Right)
                        Expanded(
                          child: _buildSquareActionTile(
                            title: "Faculty Quiz",
                            icon: Icons.assignment_late_outlined,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      FacultyQuizPage(session: widget.session)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 4. Analytics / Marks
                    _buildWideActionTile(
                      title: "Performance Analytics",
                      subtitle:
                          "Check student marks, progress reports & history",
                      icon: Icons.bar_chart_rounded,
                      colorStart: AurumColors.goldStart,
                      colorEnd: AurumColors.goldEnd,
                      isGold: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => StudentsMarksMenuPage(
                                session: widget.session)),
                      ),
                    ),

                    // 5. Departments (super_admin/admin only)
                    if (widget.session.isSuperAdmin) ...[
                      const SizedBox(height: 16),
                      _buildWideActionTile(
                        title: "Departments",
                        subtitle:
                            "Browse every department's staff, subjects & quizzes",
                        icon: Icons.apartment_rounded,
                        colorStart: const Color(0xFFa18cd1),
                        colorEnd: const Color(0xFF6c5ce7),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  DepartmentsPage(session: widget.session)),
                        ),
                      ),
                    ],

                    // 6. Staff Management (super_admin/admin/hod)
                    if (widget.session.canManageStaff) ...[
                      const SizedBox(height: 16),
                      _buildWideActionTile(
                        title: "Staff Management",
                        subtitle: widget.session.isHod
                            ? "Manage faculty in your department"
                            : "Create, edit & manage HOD/faculty accounts",
                        icon: Icons.badge_rounded,
                        colorStart: const Color(0xFF43cea2),
                        colorEnd: const Color(0xFF185a9d),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => StaffManagementPage(
                                  session: widget.session)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),

                    // LOGOUT BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => _logout(context),
                        icon: const Icon(Icons.logout_rounded,
                            color: Colors.redAccent),
                        label: const Text("Sign Out",
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          backgroundColor: AurumColors.surfaceDark,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDE TILE WIDGET ---
  Widget _buildWideActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color colorStart,
    required Color colorEnd,
    required VoidCallback onTap,
    bool isGold = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AurumColors.cardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [colorStart, colorEnd]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: colorEnd.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon,
                  color: isGold ? Colors.black : Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AurumColors.textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AurumColors.textGrey,
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AurumColors.textGrey, size: 16),
          ],
        ),
      ),
    );
  }

  // --- SQUARE TILE WIDGET ---
  Widget _buildSquareActionTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: AurumColors.cardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AurumColors.accentGold, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AurumColors.textWhite,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
