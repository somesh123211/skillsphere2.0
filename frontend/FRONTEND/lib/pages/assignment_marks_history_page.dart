import 'dart:convert';
import 'dart:ui'; // Required for Glassmorphism
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'quiz_review_page.dart';

class AssignmentMarksHistoryPage extends StatefulWidget {
  final String token;

  const AssignmentMarksHistoryPage({super.key, required this.token});

  @override
  State<AssignmentMarksHistoryPage> createState() =>
      _AssignmentMarksHistoryPageState();
}

class _AssignmentMarksHistoryPageState
    extends State<AssignmentMarksHistoryPage> {
  // ==========================================
  //            BACKEND LOGIC (PRESERVED)
  // ==========================================

  final String baseUrl = "https://skillsphere2-0.onrender.com";

  bool loading = true;
  String? error;

  List<Map<String, dynamic>> allHistory = [];
  List<Map<String, dynamic>> filteredHistory = [];

  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  static const List<String> months = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

  @override
  void initState() {
    super.initState();
    fetchAssignmentMarksHistory();
  }

  Future<void> fetchAssignmentMarksHistory() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/profile/faculty_quiz/history"),
        headers: {
          "Authorization": "Bearer ${widget.token}",
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        if (mounted) {
          setState(() {
            allHistory = List<Map<String, dynamic>>.from(data["history"] ?? []);
            applyMonthFilter();
            loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            error = "Failed to load assignment marks history";
            loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = "Network error";
          loading = false;
        });
      }
    }
  }

  DateTime? safeParseDate(dynamic value) {
    if (value == null) return null;
    final s = value.toString();

    try {
      return DateTime.parse(s);
    } catch (_) {
      try {
        final parts = s.split(' ');
        if (parts.length >= 4) {
          final day = int.parse(parts[1]);
          final month = months.indexOf(parts[2]) + 1;
          final year = int.parse(parts[3]);
          if (month > 0) {
            return DateTime(year, month, day);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  void applyMonthFilter() {
    filteredHistory = allHistory.where((h) {
      final dt = safeParseDate(h["quiz_date"]);
      if (dt == null) return false;
      return dt.month == selectedMonth && dt.year == selectedYear;
    }).toList();
  }

  String formatDate(dynamic value) {
    final dt = safeParseDate(value);
    if (dt == null) return "Unknown date";
    return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
  }

  // ==========================================
  //               GAMIFIED UI BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    const Color bgDark = Color(0xFF0F0F13);
    const Color cardColor = Color(0xFF1A1A24);
    const Color accentColor = Color(0xFF00E5FF); // Cyber Cyan

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "ASSIGNMENT LOGS",
          style: TextStyle(
            color: Colors.white, // ✅ ONLY CHANGE
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: Column(
        children: [
          // ---------------- MONTH FILTER ----------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.filter_list, color: accentColor, size: 20),
                    const SizedBox(width: 10),
                    const Text("FILTER LOGS:",
                        style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentColor.withOpacity(0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedMonth,
                      dropdownColor: cardColor,
                      icon: Icon(Icons.arrow_drop_down, color: accentColor),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      items: List.generate(12, (i) {
                        return DropdownMenuItem(
                          value: i + 1,
                          child: Text(months[i]),
                        );
                      }),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          selectedMonth = v;
                          applyMonthFilter();
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---------------- LIST ----------------
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: accentColor))
                : error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.redAccent, size: 40),
                            const SizedBox(height: 10),
                            Text(error!,
                                style: const TextStyle(color: Colors.white54)),
                          ],
                        ),
                      )
                    : filteredHistory.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_off,
                                    color: Colors.white24, size: 60),
                                const SizedBox(height: 15),
                                const Text("NO ASSIGNMENT DATA",
                                    style: TextStyle(
                                        color: Colors.white30,
                                        letterSpacing: 2)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: filteredHistory.length,
                            itemBuilder: (context, index) {
                              final h = filteredHistory[index];

                              final int score = h["score"] ?? 0;
                              final int total = h["total_questions"] ?? 0;

                              double percentage =
                                  total > 0 ? (score / total) : 0.0;

                              Color statusColor;
                              if (percentage >= 0.8) {
                                statusColor = const Color(0xFF00FF88);
                              } else if (percentage >= 0.5) {
                                statusColor = const Color(0xFFFFD700);
                              } else {
                                statusColor = const Color(0xFFFF2A6D);
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.05)),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4))
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    onTap: null,
                                    child: IntrinsicHeight(
                                      child: Row(
                                        children: [
                                          Container(width: 6, color: statusColor),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                     h["quiz_name"] ?? "Faculty Quiz #${h['quiz_id']}",
                                                     style: const TextStyle(
                                                         color: Colors.white,
                                                         fontWeight: FontWeight.bold,
                                                         fontSize: 16),
                                                   ),
                                                   const SizedBox(height: 6),
                                                   Row(
                                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                     children: [
                                                       Text(
                                                         "MISSION ID: ${h["quiz_id"] ?? "N/A"}",
                                                         style: TextStyle(
                                                             color: accentColor,
                                                             fontFamily: 'Courier',
                                                             fontWeight: FontWeight.bold,
                                                             fontSize: 11),
                                                       ),
                                                       Text(
                                                         formatDate(h["quiz_date"]),
                                                         style: const TextStyle(
                                                             color: Colors.white38,
                                                             fontSize: 11),
                                                       ),
                                                     ],
                                                   ),
                                                   const SizedBox(height: 6),
                                                   Builder(builder: (context) {
                                                     final String rawCreator = h["created_by"] ?? "Faculty";
                                                     final String creator = (rawCreator.toLowerCase().contains("admin") || rawCreator.toLowerCase() == "system")
                                                         ? "Admin"
                                                         : rawCreator;
                                                     final String st = h["quiz_start_time"] ?? "";
                                                     final String et = h["quiz_end_time"] ?? "";
                                                     return Column(
                                                       crossAxisAlignment: CrossAxisAlignment.start,
                                                       children: [
                                                         Row(
                                                           children: [
                                                             const Icon(Icons.person,
                                                                 color: Colors.white54,
                                                                 size: 14),
                                                             const SizedBox(width: 6),
                                                             Text(
                                                               "Organised by: $creator",
                                                               style: const TextStyle(
                                                                   color: Colors.white70,
                                                                   fontSize: 13),
                                                             ),
                                                           ],
                                                         ),
                                                         if (st.isNotEmpty || et.isNotEmpty) ...[
                                                           const SizedBox(height: 4),
                                                           Row(
                                                             children: [
                                                               const Icon(Icons.access_time,
                                                                   color: Colors.amberAccent,
                                                                   size: 14),
                                                               const SizedBox(width: 6),
                                                               Text(
                                                                 "Time: ${st.isNotEmpty ? st : '--'} - ${et.isNotEmpty ? et : '--'}",
                                                                 style: const TextStyle(
                                                                     color: Colors.amberAccent,
                                                                     fontSize: 12),
                                                               ),
                                                             ],
                                                           ),
                                                         ],
                                                       ],
                                                     );
                                                   }),
                                                  const SizedBox(height: 12),
                                                  const Divider(color: Colors.white10),
                                                  const SizedBox(height: 12),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      const Text(
                                                        "SCORE OBTAINED",
                                                        style: TextStyle(
                                                            color: Colors.white38,
                                                            fontSize: 10,
                                                            letterSpacing: 1.5),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: statusColor.withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(20),
                                                          border: Border.all(
                                                              color: statusColor.withOpacity(0.3)),
                                                        ),
                                                        child: Text(
                                                          "$score / $total",
                                                          style: TextStyle(
                                                              color: statusColor,
                                                              fontWeight: FontWeight.bold),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
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
