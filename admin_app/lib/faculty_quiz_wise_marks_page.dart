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

class FacultyQuizWiseMarksPage extends StatefulWidget {
  final AdminSession session;

  const FacultyQuizWiseMarksPage({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  State<FacultyQuizWiseMarksPage> createState() =>
      _FacultyQuizWiseMarksPageState();
}

class _FacultyQuizWiseMarksPageState extends State<FacultyQuizWiseMarksPage> {
  final String baseUrl = "http://localhost:5000";

  DateTime selectedDate = DateTime.now();
  int year = 2;
  int? currentQuizId;

  List<dynamic> searchedQuizzes = [];
  bool hasSearched = false;

  // Department picker — only super_admin/admin need to narrow by
  // department; hod/faculty are already scoped server-side to their own.
  List<Map<String, dynamic>> departments = [];
  int? selectedDeptId;
  bool loadingDepts = false;

  bool get showDeptPicker => widget.session.isSuperAdmin;

  bool loading = false;
  List<dynamic> data = [];

  // Quiz meta
  String quizName = "";
  String quizDate = "";
  String startTime = "";
  String endTime = "";
  String createdBy = "";
  String quizDeptName = "";
  bool canReset = false;
  int? resettingUid;

  @override
  void initState() {
    super.initState();
    if (showDeptPicker) {
      fetchDepartments();
    }
  }

  Future<void> fetchDepartments() async {
    setState(() => loadingDepts = true);
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/api/admin/departments/quiz-enabled"),
        headers: {"Authorization": "Bearer ${widget.session.token}"},
      );
      final decoded = jsonDecode(res.body);
      if (decoded["success"] == true) {
        final list = List<Map<String, dynamic>>.from(decoded["departments"]);
        setState(() {
          departments = list;
          if (selectedDeptId == null && list.isNotEmpty) {
            selectedDeptId = list.first["id"];
          }
        });
      }
    } catch (_) {
      // Dropdown stays empty; submit-time validation surfaces a clear error.
    }
    setState(() => loadingDepts = false);
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AurumColors.accentGold,
              onPrimary: Colors.black,
              surface: AurumColors.surfaceDark,
              onSurface: AurumColors.textWhite,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  // =========================
  // HELPERS
  // =========================
  bool hasValue(dynamic v) {
    return v != null && v.toString().trim().isNotEmpty;
  }

  String cleanDate(dynamic date) {
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

  String timeSlot() {
    if (!hasValue(startTime) && !hasValue(endTime)) return "NOT GIVEN";
    return "${startTime.isEmpty ? "NOT GIVEN" : startTime}"
        " - "
        "${endTime.isEmpty ? "NOT GIVEN" : endTime}";
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
  // FIND QUIZ(ZES) FOR THE SELECTED DATE, THEN FETCH MARKS
  // =========================
  Future<void> findAndFetchMarks() async {
    if (showDeptPicker && selectedDeptId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a department"),
          backgroundColor: AurumColors.errorRed,
        ),
      );
      return;
    }

    setState(() {
      loading = true;
      data = [];
      quizName = "";
      quizDate = "";
      startTime = "";
      endTime = "";
      createdBy = "";
      canReset = false;
      currentQuizId = null;
      searchedQuizzes = [];
      hasSearched = false;
    });

    try {
      final dateStr =
          "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
      final uri = Uri.parse("$baseUrl/api/admin/faculty-quiz/list").replace(
        queryParameters: {
          "year": "$year",
          "quiz_date": dateStr,
          if (showDeptPicker && selectedDeptId != null)
            "dept_id": "$selectedDeptId",
        },
      );
      final res = await http.get(
        uri,
        headers: {"Authorization": "Bearer ${widget.session.token}"},
      );
      final decoded = jsonDecode(res.body);

      if (decoded["success"] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decoded["message"] ?? "Failed to search quizzes"),
            backgroundColor: AurumColors.errorRed,
          ),
        );
        setState(() => loading = false);
        return;
      }

      final list = List<dynamic>.from(decoded["quizzes"] ?? []);
      setState(() {
        searchedQuizzes = list;
        hasSearched = true;
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to search quizzes"),
          backgroundColor: AurumColors.errorRed,
        ),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> fetchQuizMarksById(int quizId) async {
    setState(() => loading = true);

    try {
      final res = await http.get(
        Uri.parse(
          "$baseUrl/api/faculty/quiz/marks?quiz_id=$quizId&year=$year",
        ),
        headers: {
          "Authorization": "Bearer ${widget.session.token}",
        },
      );

      final json = jsonDecode(res.body);

      if (json["success"] == true) {
        setState(() {
          currentQuizId = quizId;
          quizName = json["quiz_name"]?.toString() ?? "";
          quizDate = json["quiz_date"]?.toString() ?? "";
          startTime = json["start_time"]?.toString() ?? "";
          endTime = json["end_time"]?.toString() ?? "";
          createdBy = json["created_by"]?.toString() ?? "";
          quizDeptName = json["dept_name"]?.toString() ?? json["department"]?.toString() ?? "";
          canReset = json["can_reset"] == true;
          data = json["data"] ?? [];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(json["message"] ?? "Quiz not found"),
            backgroundColor: AurumColors.errorRed,
          ),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to load quiz marks"),
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
  // RESET A STUDENT'S ATTEMPT
  // =========================
  Future<void> resetStudent(Map<String, dynamic> student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurumColors.surfaceDark,
        title: const Text("Reset Quiz?",
            style: TextStyle(color: AurumColors.textWhite)),
        content: Text(
          "This will clear ${student["name"]}'s (UID: ${student["uid"]}) attempt on this quiz. "
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

    setState(() => resettingUid = student["uid"] as int);

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/api/admin/faculty-quiz/reset-student"),
        headers: {
          "Authorization": "Bearer ${widget.session.token}",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "quiz_id": currentQuizId,
          "uid": student["uid"],
        }),
      );

      final decoded = jsonDecode(res.body);

      if (decoded["success"] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "${student["name"]}'s quiz has been reset — they can retake it"),
              backgroundColor: AurumColors.successGreen,
            ),
          );
        }
        await fetchQuizMarksById(currentQuizId!);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decoded["message"] ?? "Failed to reset quiz"),
            backgroundColor: AurumColors.errorRed,
          ),
        );
      }
    } catch (e) {
      debugPrint("Faculty quiz marks error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Unable to connect to the server. Please try again."),
            backgroundColor: AurumColors.errorRed,
          ),
        );
      }
    }

    if (mounted) setState(() => resettingUid = null);
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
                      "SKILL SPHERE - FACULTY QUIZ CLASS REPORT",
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      "Class Evaluation & Student Marks",
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
        build: (_) => [
          // METADATA SUMMARY CARD
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
                    pw.Text("Quiz ID: ${currentQuizId ?? ''}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                    pw.SizedBox(height: 3),
                    pw.Text("Date: ${safeStr(cleanDate(quizDate))}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 3),
                    pw.Text("Time Slot: ${safeStr(timeSlot())}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    if (quizDeptName.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text("Department: ${safeStr(quizDeptName)}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("Organised By: ${safeStr(hasValue(createdBy) ? createdBy : 'Admin')}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2563EB'))),
                    pw.SizedBox(height: 3),
                    pw.Text("Year: Year $year", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 3),
                    pw.Text("Total Students: ${data.length}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
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
            headers: const ["UID", "Student Name", "Marks Obtained"],
            data: data.map((s) {
              final isNotGiven = s["marks"] == "NOT GIVEN";
              return [
                s["uid"].toString(),
                safeStr(s["name"]),
                isNotGiven ? "NOT GIVEN" : "${s["marks"]} / ${s["total_marks"]}",
              ];
            }).toList(),
          ),
        ],
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
        title: const Text("Quiz Analysis"),
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
                Row(
                  children: [
                    // Date Picker
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AurumColors.backgroundBlack,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  color: AurumColors.accentGold, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                                style: const TextStyle(
                                    color: AurumColors.textWhite,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Year Dropdown
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AurumColors.backgroundBlack,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: year,
                            dropdownColor: AurumColors.surfaceDark,
                            icon: const Icon(Icons.arrow_drop_down,
                                color: AurumColors.accentGold),
                            style: const TextStyle(
                                color: AurumColors.textWhite,
                                fontWeight: FontWeight.bold),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text("Year 1")),
                              DropdownMenuItem(value: 2, child: Text("Year 2")),
                              DropdownMenuItem(value: 3, child: Text("Year 3")),
                              DropdownMenuItem(value: 4, child: Text("Year 4")),
                            ],
                            onChanged: (v) => setState(() => year = v!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (showDeptPicker) ...[
                  const SizedBox(height: 16),
                  loadingDepts
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: CircularProgressIndicator(
                              color: AurumColors.accentGold),
                        )
                      : Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AurumColors.backgroundBlack,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: selectedDeptId ??
                                  (departments.isNotEmpty
                                      ? departments.first["id"]
                                      : 0),
                              isExpanded: true,
                              dropdownColor: AurumColors.surfaceDark,
                              icon: const Icon(Icons.arrow_drop_down,
                                  color: AurumColors.accentGold),
                              style: const TextStyle(
                                  color: AurumColors.textWhite,
                                  fontWeight: FontWeight.bold),
                              items: departments
                                  .map((d) => DropdownMenuItem<int>(
                                        value: d["id"] as int,
                                        child: Text(d["name"].toString()),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => selectedDeptId = v),
                            ),
                          ),
                        ),
                ],
                const SizedBox(height: 16),
                // Search Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : findAndFetchMarks,
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
                            "FETCH MARKS",
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
                : !hasSearched
                    ? _buildPlaceholder("Select a date and click FETCH MARKS")
                    : searchedQuizzes.isEmpty
                        ? _buildPlaceholder("No quizzes found for this date")
                        : currentQuizId == null
                            ? Column(
                                children: [
                                  // Display Number of Quizzes Taken Header
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      "Quizzes Taken on this Day: ${searchedQuizzes.length}",
                                      style: const TextStyle(
                                        color: AurumColors.accentGold,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // List of quizzes
                                  Expanded(
                                    child: ListView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: searchedQuizzes.length,
                                      itemBuilder: (_, i) {
                                        final q = searchedQuizzes[i];
                                        final qName = q["quiz_name"] ?? "Quiz #${q["quiz_id"]}";
                                        final qDept = q["department"] ?? "";
                                        final qStart = q["quiz_start_time"] ?? "";
                                        final qEnd = q["quiz_end_time"] ?? "";
                                        final qCreator = q["created_by_name"] ?? q["created_by"] ?? "N/A";
                                        final qYear = q["year"] ?? "";

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          decoration: BoxDecoration(
                                            color: AurumColors.cardSurface,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.05),
                                            ),
                                          ),
                                          child: ListTile(
                                            contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                            title: Text(
                                              qName,
                                              style: const TextStyle(
                                                color: AurumColors.textWhite,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            subtitle: Padding(
                                              padding: const EdgeInsets.only(top: 4.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "Dept: $qDept · Year: $qYear",
                                                    style: const TextStyle(
                                                        color: AurumColors.textGrey,
                                                        fontSize: 12),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    "Time Slot: $qStart - $qEnd",
                                                    style: const TextStyle(
                                                        color: AurumColors.textGrey,
                                                        fontSize: 12),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    "Created By: $qCreator",
                                                    style: const TextStyle(
                                                        color: AurumColors.textGrey,
                                                        fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            trailing: const Icon(
                                              Icons.chevron_right,
                                              color: AurumColors.accentGold,
                                            ),
                                            onTap: () => fetchQuizMarksById(q["quiz_id"] as int),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  // Back to Quiz List button
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            currentQuizId = null;
                                            data = [];
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.arrow_back, color: AurumColors.accentGold, size: 18),
                                              SizedBox(width: 8),
                                              Text(
                                                "Back to Quiz List",
                                                style: TextStyle(
                                                  color: AurumColors.accentGold,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Quiz Meta Card
                                  if (hasValue(quizDate))
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
                                          if (hasValue(quizName))
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(bottom: 6),
                                              child: Text(
                                                quizName,
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          _buildMetaRow(
                                              "Date", cleanDate(quizDate), true),
                                          const SizedBox(height: 4),
                                          _buildMetaRow("Time Slot", timeSlot(), true),
                                          const SizedBox(height: 4),
                                          _buildMetaRow(
                                              "Created By",
                                              hasValue(createdBy) ? createdBy : "N/A",
                                              true),
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
                                        final s = data[i];
                                        final isNotGiven = s["marks"] == "NOT GIVEN";

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
                                            title: Text(
                                              s["name"],
                                              style: const TextStyle(
                                                color: AurumColors.textWhite,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            subtitle: Text(
                                              s["time_taken_seconds"] != null
                                                  ? "UID: ${s["uid"]} · Started ${formatClockTime(s["started_at"])} · Submitted ${formatClockTime(s["submitted_at"])} · ${formatTimeTaken(s["time_taken_seconds"])}"
                                                  : "UID: ${s["uid"]}",
                                              style: const TextStyle(
                                                  color: AurumColors.textGrey,
                                                  fontSize: 12),
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
                                                        : "${s["marks"]} / ${s["total_marks"]}",
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: isNotGiven
                                                          ? AurumColors.errorRed
                                                          : AurumColors.successGreen,
                                                    ),
                                                  ),
                                                ),
                                                if (canReset) ...[
                                                  const SizedBox(width: 6),
                                                  resettingUid == s["uid"]
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
                                                              "Reset this student's quiz",
                                                          onPressed: () =>
                                                              resetStudent(s),
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
          Icon(Icons.assignment_outlined,
              size: 60, color: AurumColors.surfaceDark),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AurumColors.textGrey)),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, bool isDark) {
    return Row(
      children: [
        Text(
          "$label: ",
          style: TextStyle(
            color: isDark ? Colors.black54 : AurumColors.textGrey,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.black : AurumColors.textWhite,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
