import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'admin_session.dart';

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
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color errorRed = Color(0xFFCF6679);

  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldStart, goldEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class FacultyStudentQuizMarksPage extends StatefulWidget {
  final AdminSession session;

  const FacultyStudentQuizMarksPage({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  State<FacultyStudentQuizMarksPage> createState() =>
      _FacultyStudentQuizMarksPageState();
}

class _FacultyStudentQuizMarksPageState
    extends State<FacultyStudentQuizMarksPage> {
  final String baseUrl = "http://localhost:5000";

  final TextEditingController uidCtrl = TextEditingController();
  int year = 2;

  bool loading = false;
  List<dynamic> data = [];

  String studentName = "NOT GIVEN";
  String studentEmail = "NOT GIVEN";
  int? resettingQuizId;

  // =========================
  // HELPERS
  // =========================
  bool hasValue(dynamic v) {
    return v != null &&
        v.toString().trim().isNotEmpty &&
        v.toString() != "NOT GIVEN";
  }

  String formatDate(dynamic date) {
    if (!hasValue(date)) return "NOT GIVEN";
    final s = date.toString();
    if (s.contains("GMT")) {
      return s
          .split(" GMT")
          .first
          .replaceAll(RegExp(r"\s\d{2}:\d{2}:\d{2}"), "");
    }
    return s;
  }

  String formatTime(dynamic start, dynamic end) {
    if (!hasValue(start) && !hasValue(end)) return "NOT GIVEN";
    return "${start ?? "NOT GIVEN"} - ${end ?? "NOT GIVEN"}";
  }

  String downloadedTimestamp() {
    final d = DateTime.now();
    return "${d.day.toString().padLeft(2, '0')}-"
        "${d.month.toString().padLeft(2, '0')}-"
        "${d.year}  "
        "${d.hour.toString().padLeft(2, '0')}:"
        "${d.minute.toString().padLeft(2, '0')}";
  }

  // =========================
  // FETCH MARKS
  // =========================
  Future<void> fetchMarks() async {
    final uidText = uidCtrl.text.trim();

    if (uidText.isEmpty || int.tryParse(uidText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter a valid numeric UID"),
          backgroundColor: AurumColors.errorRed,
        ),
      );
      return;
    }

    setState(() {
      loading = true;
      data = [];
      studentName = "NOT GIVEN";
      studentEmail = "NOT GIVEN";
    });

    try {
      final response = await http.get(
        Uri.parse(
          "$baseUrl/api/faculty/student/quiz-marks?uid=$uidText",
        ),
        headers: {
          "Authorization": "Bearer ${widget.session.token}",
        },
      );

      final json = jsonDecode(response.body);

      if (json["success"] == true && json["data"] is List) {
        setState(() {
          data = json["data"];
          if (hasValue(json["student_name"])) {
            studentName = json["student_name"];
          }
          if (hasValue(json["email"])) {
            studentEmail = json["email"];
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No data found or student does not exist"),
            backgroundColor: AurumColors.errorRed,
          ),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to load marks"),
          backgroundColor: AurumColors.errorRed,
        ),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  String formatTimeTaken(int? seconds) {
    if (seconds == null) return "";
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return "${m}m ${s}s";
  }

  String formatClockTime(String? iso) {
    if (iso == null || iso.isEmpty) return "";
    try {
      final dt = DateTime.parse(iso);
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? "PM" : "AM";
      return "${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm";
    } catch (_) {
      return "";
    }
  }

  // =========================
  // RESET A STUDENT'S ATTEMPT ON ONE QUIZ
  // =========================
  Future<void> resetQuiz(Map<String, dynamic> quiz) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurumColors.surfaceDark,
        title: const Text("Reset Quiz?",
            style: TextStyle(color: AurumColors.textWhite)),
        content: Text(
          "This will clear $studentName's attempt on quiz ${quiz["quiz_id"]}. "
          "They will be able to take it again.",
          style: const TextStyle(color: AurumColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel",
                style: TextStyle(color: AurumColors.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Reset",
                style: TextStyle(
                    color: AurumColors.errorRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => resettingQuizId = quiz["quiz_id"] as int);

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/api/admin/faculty-quiz/reset-student"),
        headers: {
          "Authorization": "Bearer ${widget.session.token}",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "quiz_id": quiz["quiz_id"],
          "uid": int.parse(uidCtrl.text.trim()),
        }),
      );

      final decoded = jsonDecode(res.body);

      if (decoded["success"] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "$studentName's attempt on quiz ${quiz["quiz_id"]} has been reset"),
              backgroundColor: AurumColors.successGreen,
            ),
          );
        }
        await fetchMarks();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decoded["message"] ?? "Failed to reset quiz"),
            backgroundColor: AurumColors.errorRed,
          ),
        );
      }
    } catch (e) {
      debugPrint("Faculty student quiz marks error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Unable to connect to the server. Please try again."),
            backgroundColor: AurumColors.errorRed,
          ),
        );
      }
    }

    if (mounted) setState(() => resettingQuizId = null);
  }

  // =========================
  // GENERATE PDF
  // =========================
  Future<void> generatePdf() async {
    final doc = pw.Document();

    String safeStr(dynamic val) {
      if (val == null) return "";
      return val
          .toString()
          .replaceAll('’', "'")
          .replaceAll('‘', "'")
          .replaceAll('“', '"')
          .replaceAll('”', '"')
          .replaceAll('–', '-')
          .replaceAll('—', '-')
          .replaceAll('•', '*')
          .replaceAll('…', '...');
    }

    final String generatedTime = downloadedTimestamp();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#1E293B'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "SKILL SPHERE - STUDENT PERFORMANCE REPORT",
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      "Faculty Quiz Analysis",
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey400,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "Generated: $generatedTime",
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.amber300,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  "Skill Sphere Official Analytics",
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  "Page ${context.pageNumber} of ${context.pagesCount}",
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // METADATA CARD
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              margin: const pw.EdgeInsets.only(bottom: 16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "Student Name: ${safeStr(studentName)}",
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text("Email: ${safeStr(studentEmail)}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(height: 3),
                      pw.Text("UID: ${safeStr(uidCtrl.text)}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#FEF3C7'),
                      borderRadius: pw.BorderRadius.circular(12),
                      border: pw.Border.all(color: PdfColor.fromHex('#FDE68A')),
                    ),
                    child: pw.Text(
                      "Total Quizzes: ${data.length}",
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#92400E')),
                    ),
                  ),
                ],
              ),
            ),

            // TABLE
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E293B')),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: const ["Quiz ID", "Quiz Title", "Date", "Time Slot", "Marks", "Organised By"],
              data: data.map((q) {
                final isNotGiven = q["marks"] == "NOT GIVEN";
                final qName = q["quiz_name"] != null && q["quiz_name"].toString().isNotEmpty
                    ? q["quiz_name"].toString()
                    : "Faculty Quiz #${q['quiz_id']}";
                return [
                  q["quiz_id"].toString(),
                  safeStr(qName),
                  safeStr(formatDate(q["quiz_date"])),
                  safeStr(formatTime(q["start_time"], q["end_time"])),
                  isNotGiven ? "NOT GIVEN" : "${q["marks"]} / ${q["total_marks"]}",
                  safeStr(hasValue(q["created_by"]) ? q["created_by"] : "Admin"),
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
    );
  }

  // =========================
  // UI BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      appBar: AppBar(
        title: const Text("Student Analysis"),
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
          if (data.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf,
                  color: AurumColors.accentGold),
              tooltip: "Generate PDF",
              onPressed: generatePdf,
            ),
        ],
      ),
      body: Column(
        children: [
          // =========================
          // SEARCH CARD
          // =========================
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AurumColors.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: uidCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AurumColors.textWhite),
                  cursorColor: AurumColors.accentGold,
                  decoration: InputDecoration(
                    hintText: "Enter Student UID (e.g. 2400212)",
                    hintStyle:
                        const TextStyle(color: AurumColors.textGrey),
                    filled: true,
                    fillColor: AurumColors.backgroundBlack,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AurumColors.accentGold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Search Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : fetchMarks,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AurumColors.accentGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 2),
                          )
                        : const Text(
                            "FETCH RECORD",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),

          // =========================
          // RESULT CONTENT
          // =========================
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AurumColors.accentGold))
                : data.isEmpty
                    ? _buildPlaceholder("Enter student UID to view marks")
                    : Column(
                        children: [
                          // Student Profile Card
                          if (hasValue(studentName) || hasValue(studentEmail))
                            Container(
                              width: double.infinity,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: AurumColors.goldGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AurumColors.accentGold.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.black,
                                        child: Text(
                                          studentName.isNotEmpty
                                              ? studentName[0].toUpperCase()
                                              : "S",
                                          style: const TextStyle(
                                              color: AurumColors.accentGold),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              studentName,
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (hasValue(studentEmail))
                                              Text(
                                                studentEmail,
                                                style: TextStyle(
                                                  color: Colors.black
                                                      .withOpacity(0.7),
                                                  fontSize: 12,
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

                          const SizedBox(height: 16),

                          // Marks List
                          Expanded(
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: data.length,
                              itemBuilder: (_, i) {
                                final q = data[i];
                                final isNotGiven = q["marks"] == "NOT GIVEN";

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: AurumColors.cardSurface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isNotGiven
                                          ? AurumColors.errorRed
                                              .withOpacity(0.3)
                                          : AurumColors.successGreen
                                              .withOpacity(0.3),
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          AurumColors.backgroundBlack,
                                      child: Text(
                                        q["quiz_id"].toString(),
                                        style: const TextStyle(
                                          color: AurumColors.textWhite,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      formatDate(q["quiz_date"]),
                                      style: const TextStyle(
                                        color: AurumColors.textWhite,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          formatTime(
                                              q["start_time"], q["end_time"]),
                                          style: const TextStyle(
                                              color: AurumColors.textGrey,
                                              fontSize: 12),
                                        ),
                                        if (hasValue(q["created_by"]))
                                          Text(
                                            "By: ${q["created_by"]}",
                                            style: const TextStyle(
                                                color: AurumColors.textGrey,
                                                fontSize: 11),
                                          ),
                                        if (q["time_taken_seconds"] != null)
                                          Text(
                                            "Started ${formatClockTime(q["started_at"])} · Submitted ${formatClockTime(q["submitted_at"])} · ${formatTimeTaken(q["time_taken_seconds"])}",
                                            style: const TextStyle(
                                                color: AurumColors.textGrey,
                                                fontSize: 11),
                                          ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isNotGiven
                                                ? AurumColors.errorRed
                                                    .withOpacity(0.1)
                                                : AurumColors.successGreen
                                                    .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            isNotGiven
                                                ? "Absent"
                                                : "${q["marks"]} / ${q["total_marks"]}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isNotGiven
                                                  ? AurumColors.errorRed
                                                  : AurumColors.successGreen,
                                            ),
                                          ),
                                        ),
                                        if (q["can_reset"] == true) ...[
                                          const SizedBox(width: 6),
                                          resettingQuizId == q["quiz_id"]
                                              ? const SizedBox(
                                                  height: 18,
                                                  width: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                    color:
                                                        AurumColors.accentGold,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : IconButton(
                                                  icon: const Icon(
                                                      Icons.restart_alt_rounded,
                                                      color: AurumColors
                                                          .accentGold,
                                                      size: 20),
                                                  tooltip:
                                                      "Reset this attempt",
                                                  onPressed: () =>
                                                      resetQuiz(q),
                                                ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // --- HELPERS ---

  Widget _buildPlaceholder(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined,
              size: 60, color: AurumColors.surfaceDark),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AurumColors.textGrey)),
        ],
      ),
    );
  }
}
