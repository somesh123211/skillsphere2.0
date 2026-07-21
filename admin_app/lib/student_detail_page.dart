import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'admin_session.dart';
import 'edit_student_page.dart';

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
}

class StudentDetailPage extends StatefulWidget {
  final AdminSession session;
  final String uid;

  const StudentDetailPage({
    Key? key,
    required this.session,
    required this.uid,
  }) : super(key: key);

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  final String baseUrl = "https://skillsphere2-0.onrender.com";

  bool loading = true;
  Map<String, dynamic>? student;

  @override
  void initState() {
    super.initState();
    fetchStudent();
  }

  Future<void> fetchStudent() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/admin/student/${widget.uid}"),
        headers: {
          "Authorization": "Bearer ${widget.session.token}",
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        if (mounted) {
          setState(() {
            student = data["student"];
          });
        }
      } else {
        if (mounted) showError(data["message"] ?? "Failed to load student");
      }
    } catch (e) {
      debugPrint("Student detail load error: $e");
      if (mounted) showError("Unable to connect to the server. Please try again.");
    }

    if (mounted) setState(() => loading = false);
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      appBar: AppBar(
        title: const Text("Student Profile"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: AurumColors.textWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
        iconTheme: const IconThemeData(color: AurumColors.accentGold),
        actions: [
          if (!loading && student != null && widget.session.canEditStudents)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AurumColors.accentGold),
              tooltip: "Edit Student",
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditStudentPage(
                      session: widget.session,
                      student: student!,
                    ),
                  ),
                );
                if (updated == true) fetchStudent();
              },
            ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: AurumColors.accentGold),
            )
          : student == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.person_off,
                          size: 60, color: AurumColors.textGrey),
                      SizedBox(height: 16),
                      Text("No student data found",
                          style: TextStyle(color: AurumColors.textGrey)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // ==================
                      // PROFILE HEADER
                      // ==================
                      Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AurumColors.accentGold.withOpacity(0.3),
                            width: 2,
                          ),
                          gradient: LinearGradient(
                            colors: [
                              AurumColors.surfaceDark,
                              Colors.black.withOpacity(0.5)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Text(
                          _getInitials(student!["name"]?.toString() ?? "U"),
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: AurumColors.accentGold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        student!["name"]?.toString() ?? "Unknown Name",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AurumColors.textWhite,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AurumColors.accentGold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AurumColors.accentGold.withOpacity(0.5)),
                        ),
                        child: Text(
                          "Year: ${student!["year"]?.toString() ?? "N/A"}",
                          style: const TextStyle(
                            color: AurumColors.accentGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // ==================
                      // DETAILS SECTION
                      // ==================
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AurumColors.cardSurface,
                          borderRadius: BorderRadius.circular(24),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "ACADEMIC DETAILS",
                              style: TextStyle(
                                color: AurumColors.textGrey,
                                fontSize: 12,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // FIXED: Added .toString() to prevent crash
                            _buildDetailRow(
                              icon: Icons.fingerprint,
                              label: "UID (Roll No)",
                              value: student!["uid"]?.toString() ?? "N/A",
                            ),

                            const Divider(color: Colors.white10, height: 30),

                            _buildDetailRow(
                              icon: Icons.email_outlined,
                              label: "Email Address",
                              value: student!["email"]?.toString() ?? "N/A",
                            ),

                            const Divider(color: Colors.white10, height: 30),

                            _buildDetailRow(
                              icon: Icons.calendar_today_outlined,
                              label: "Academic Year",
                              value:
                                  "Year ${student!["year"]?.toString() ?? "?"}",
                            ),

                            const Divider(color: Colors.white10, height: 30),

                            _buildDetailRow(
                              icon: Icons.school_outlined,
                              label: "Branch",
                              value: student!["branch"]?.toString() ?? "N/A",
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // Helper to extract initials
  String _getInitials(String name) {
    if (name.isEmpty) return "S";
    List<String> parts = name.trim().split(" ");
    if (parts.length > 1) {
      return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  // Helper Widget for Rows
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AurumColors.backgroundBlack,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AurumColors.accentGold, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AurumColors.textGrey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: AurumColors.textWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
