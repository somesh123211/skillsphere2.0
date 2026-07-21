import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'quiz_review_page.dart';

class TodayQuizzesListPage extends StatefulWidget {
  final String token;
  final String type; // "ai" or "faculty"

  const TodayQuizzesListPage({
    Key? key,
    required this.token,
    required this.type,
  }) : super(key: key);

  @override
  State<TodayQuizzesListPage> createState() => _TodayQuizzesListPageState();
}

class _TodayQuizzesListPageState extends State<TodayQuizzesListPage> {
  final String baseUrl = "http://localhost:5000";

  bool loading = true;
  String? error;
  List<Map<String, dynamic>> quizzes = [];

  bool get isFaculty => widget.type == "faculty";

  @override
  void initState() {
    super.initState();
    fetchTodayQuizzes();
  }

  String resolveDepartmentName(String input) {
    if (input.trim().isEmpty) return "Artificial Intelligence";
    final Map<String, String> deptMap = {
      'AI': 'Artificial Intelligence',
      'DS': 'Computer Science & Engineering (Data Science)',
      'CSE': 'Computer Science & Engineering',
      'IT': 'Information Technology',
      'ETC': 'Electronics & Telecommunication',
      'MECH': 'Mechanical Engineering',
      'CIVIL': 'Civil Engineering',
      'EE': 'Electrical Engineering',
      'CS-CY': 'Computer Science & Engineering (Cyber Security)',
      'CSBS': 'Computer Science & Business Systems',
      'IIOT': 'Industrial Internet of Things',
      'RAI': 'Robotics & Artificial Intelligence',
    };
    final upper = input.trim().toUpperCase();
    if (deptMap.containsKey(upper)) {
      return deptMap[upper]!;
    }
    return input;
  }

  Future<void> fetchTodayQuizzes() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/api/profile/today/quizzes?type=${widget.type}"),
        headers: {"Authorization": "Bearer ${widget.token}"},
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data["success"] == true) {
        if (mounted) {
          setState(() {
            quizzes = List<Map<String, dynamic>>.from(data["quizzes"] ?? []);
            loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            error = data["message"] ?? "Failed to load today's quizzes";
            loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = "Connection error";
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color bgDark = Color(0xFF0F0F13);
    const Color cardColor = Color(0xFF1A1A24);
    const Color goldColor = Color(0xFFFFD700);
    const Color cyanColor = Color(0xFF00E5FF);
    const Color greenColor = Color(0xFF00FF88);

    final Color themeColor = isFaculty ? cyanColor : goldColor;

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          isFaculty ? "TODAY'S FACULTY MISSIONS" : "TODAY'S DAILY TARGETS",
          style: const TextStyle(
            color: Colors.white,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: themeColor))
          : error != null
              ? Center(
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                )
              : quizzes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isFaculty ? Icons.school_outlined : Icons.quiz_outlined,
                            size: 60,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No ${isFaculty ? 'Faculty Quizzes' : 'Daily AI Quizzes'} attempted today.",
                            style: const TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER COUNT
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: themeColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.checklist_rtl, color: themeColor, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                "ATTEMPTED TODAY: ${quizzes.length}",
                                style: TextStyle(
                                  color: themeColor,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // QUIZZES LIST
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: quizzes.length,
                            itemBuilder: (context, index) {
                              final q = quizzes[index];
                              final bool isEnded = q["is_ended"] == true;
                              final int score = q["score"] ?? 0;
                              final int total = q["total"] ?? 0;
                              final String quizName = q["quiz_name"] ?? "Quiz Attempt";
                              final String rawCreator = q["created_by"] ?? (isFaculty ? "Faculty" : "Admin");
                              final String creator = (rawCreator.toLowerCase().contains("admin") || rawCreator.toLowerCase() == "system")
                                  ? "Admin"
                                  : rawCreator;
                              final String subject = q["subject"] ?? (isFaculty ? "Faculty Quiz" : "Daily Target");

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: null,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Left Icon / Indicator
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: themeColor.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isFaculty ? Icons.school : Icons.auto_awesome,
                                            color: themeColor,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                quizName,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "Organised by: $creator  ·  Department: ${resolveDepartmentName(subject)}",
                                                style: const TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              if (isFaculty) ...[
                                                Text(
                                                  "Time: ${q["quiz_start_time"] ?? ''} - ${q["quiz_end_time"] ?? ''}",
                                                  style: const TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                              ],
                                              Row(
                                                children: [
                                                  // Status Badge
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: isEnded
                                                          ? greenColor.withOpacity(0.15)
                                                          : goldColor.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(
                                                        color: isEnded
                                                            ? greenColor.withOpacity(0.4)
                                                            : goldColor.withOpacity(0.4),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          isEnded ? Icons.lock_open : Icons.lock_clock,
                                                          size: 11,
                                                          color: isEnded ? greenColor : goldColor,
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          isEnded
                                                              ? "ANSWERS UNLOCKED"
                                                              : "LOCKED (Unlocks at ${q['quiz_end_time'] ?? ''})",
                                                          style: TextStyle(
                                                            color: isEnded ? greenColor : goldColor,
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),

                                        // Score & Chevron
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              "$score/$total",
                                              style: TextStyle(
                                                color: themeColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                fontFamily: 'Courier',
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Icon(
                                              Icons.chevron_right,
                                              color: themeColor.withOpacity(0.6),
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}
