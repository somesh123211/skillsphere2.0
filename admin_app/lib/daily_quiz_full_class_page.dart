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

class DailyQuizFullClassPage extends StatefulWidget {
  final AdminSession session;

  const DailyQuizFullClassPage({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  State<DailyQuizFullClassPage> createState() => _DailyQuizFullClassPageState();
}

class _DailyQuizFullClassPageState extends State<DailyQuizFullClassPage> {
  // ================= CONFIG =================
  final String baseUrl = "https://skillsphere2-0.onrender.com";

  // ================= STATE =================
  int selectedYear = 2;
  DateTime? selectedDate;

  bool loading = false;
  bool searched = false;

  // Step 1: list of quizzes found on the selected date
  List<dynamic> quizList = [];

  // Step 2: the quiz the caller drilled into
  dynamic activeQuiz;
  String topic = "";
  String subject = "";
  String difficulty = "";
  String createdByName = "";
  String quizDepartment = "";
  String quizStartTime = "";
  String quizEndTime = "";
  int durationMinutes = 10;
  int totalMarks = 0;
  List<Map<String, dynamic>> students = [];
  // Only the quiz's own creator may reset a student's attempt on it.
  bool canReset = false;
  int? resettingUid;

  // Department filter — only super_admin/admin get a free choice; hod/
  // faculty are already forced to their own department server-side.
  bool get showDeptFilter => widget.session.isSuperAdmin;
  List<Map<String, dynamic>> departments = [];
  int? selectedDeptId;
  bool loadingDepts = false;

  @override
  void initState() {
    super.initState();
    if (showDeptFilter) {
      fetchDepartments();
    }
  }

  Future<void> fetchDepartments() async {
    setState(() => loadingDepts = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/admin/departments"),
        headers: {"Authorization": "Bearer ${widget.session.token}"},
      );
      final data = jsonDecode(response.body);
      if (data["success"] == true) {
        setState(() {
          departments = List<Map<String, dynamic>>.from(data["departments"]);
        });
      }
    } catch (e) {
      // Filter just stays on "All Departments" if this fails.
    }
    setState(() => loadingDepts = false);
  }

  // ================= DATE PICKER =================
  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDate: DateTime.now(),
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

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  // ================= STEP 1: LIST QUIZZES ON DATE =================
  Future<void> fetchQuizList() async {
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a date first"),
          backgroundColor: AurumColors.errorRed,
        ),
      );
      return;
    }

    setState(() {
      loading = true;
      searched = true;
      quizList = [];
      activeQuiz = null;
      students = [];
    });

    final dateStr =
        "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";

    final uri = Uri.parse(
      "$baseUrl/api/admin/daily-quiz/list",
    ).replace(queryParameters: {
      "year": "$selectedYear",
      "date": dateStr,
      if (selectedDeptId != null) "dept_id": "$selectedDeptId",
    });

    try {
      final res = await http.get(
        uri,
        headers: {
          "Authorization": "Bearer ${widget.session.token}",
        },
      );

      final decoded = jsonDecode(res.body);

      if (decoded["success"] == true) {
        setState(() => quizList = decoded["quizzes"] ?? []);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decoded["message"] ?? "Failed to load quizzes"),
            backgroundColor: AurumColors.errorRed,
          ),
        );
      }
    } catch (e) {
      debugPrint("Daily quiz full-class error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Unable to connect to the server. Please try again."),
            backgroundColor: AurumColors.errorRed,
          ),
        );
      }
    }

    setState(() => loading = false);
  }

  // ================= STEP 2: OPEN A SPECIFIC QUIZ'S MARKS =================
  Future<void> openQuiz(dynamic quiz) async {
    setState(() {
      loading = true;
      activeQuiz = quiz;
      students = [];
    });

    final uri = Uri.parse(
      "$baseUrl/api/admin/daily-quiz/full-class",
    ).replace(queryParameters: {
      "year": "$selectedYear",
      "quiz_id": "${quiz["id"]}",
    });

    try {
      final res = await http.get(
        uri,
        headers: {
          "Authorization": "Bearer ${widget.session.token}",
        },
      );

      final decoded = jsonDecode(res.body);

      if (decoded["success"] == true) {
        setState(() {
          topic = decoded["quiz"]["topic"] ?? "";
          subject = decoded["quiz"]["subject"] ?? "";
          difficulty = decoded["quiz"]["difficulty"] ?? "";
          createdByName = decoded["quiz"]["created_by_name"] ?? decoded["quiz"]["created_by"] ?? "";
          quizDepartment = decoded["quiz"]["department"] ?? "";
          quizStartTime = decoded["quiz"]["quiz_start_time"] ?? "";
          quizEndTime = decoded["quiz"]["quiz_end_time"] ?? "";
          durationMinutes = decoded["quiz"]["duration_minutes"] ?? 10;
          totalMarks = decoded["quiz"]["total_marks"] ?? 0;
          canReset = decoded["quiz"]["can_reset"] == true;
          students = List<Map<String, dynamic>>.from(decoded["students"]);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(decoded["message"] ?? "Failed to load marks"),
              backgroundColor: AurumColors.errorRed,
            ),
          );
        }
        setState(() => activeQuiz = null);
      }
    } catch (e) {
      debugPrint("Daily quiz full-class error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Unable to connect to the server. Please try again."),
            backgroundColor: AurumColors.errorRed,
          ),
        );
      }
      setState(() => activeQuiz = null);
    }

    setState(() => loading = false);
  }

  void backToList() {
    setState(() {
      activeQuiz = null;
      students = [];
    });
  }

  // ================= RESET A STUDENT'S ATTEMPT =================
  Future<void> resetStudent(Map<String, dynamic> student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurumColors.surfaceDark,
        title: const Text("Reset Quiz?",
            style: TextStyle(color: AurumColors.textWhite)),
        content: Text(
          "This will clear ${student["name"]}'s (UID: ${student["uid"]}) attempt on this quiz. "
          "They will be able to take it again and may be handed any of the "
          "generated sets, even one already used by another student.",
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
        Uri.parse("$baseUrl/api/admin/daily-quiz/reset-student"),
        headers: {
          "Authorization": "Bearer ${widget.session.token}",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "year": selectedYear,
          "quiz_id": activeQuiz["id"],
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
        await openQuiz(activeQuiz);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decoded["message"] ?? "Failed to reset quiz"),
            backgroundColor: AurumColors.errorRed,
          ),
        );
      }
    } catch (e) {
      debugPrint("Daily quiz full-class error: $e");
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

  // ================= PDF (WITH DOWNLOADED TIME) =================
  Future<void> generatePdf() async {
    final pdf = pw.Document();

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

    final quizDateStr =
        "${selectedDate!.day.toString().padLeft(2, '0')}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.year}";

    final now = DateTime.now();
    final downloadedTime = "${now.day.toString().padLeft(2, '0')}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.year}  "
        "${now.hour.toString().padLeft(2, '0')}:"
        "${now.minute.toString().padLeft(2, '0')}";

    pdf.addPage(
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
                      "SKILL SPHERE - AI DAILY QUIZ CLASS REPORT",
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      "Full Class Daily Target Analytics",
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
                      "Generated: $downloadedTime",
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
        build: (_) {
          return [
            // METADATA CARD
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
                      if (subject.isNotEmpty || quizDepartment.isNotEmpty) ...[
                        pw.Text("Department: ${safeStr(resolveDepartmentName(subject.isNotEmpty ? subject : quizDepartment))}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                        pw.SizedBox(height: 3),
                      ],
                      pw.Text("Topic: ${safeStr(topic)}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2563EB'))),
                      pw.SizedBox(height: 3),
                      pw.Text("Date: $quizDateStr", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      if (quizStartTime.isNotEmpty || quizEndTime.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text("Timings: ${safeStr(quizStartTime.isNotEmpty ? quizStartTime : '--')} - ${safeStr(quizEndTime.isNotEmpty ? quizEndTime : '--')} ($durationMinutes mins)", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                      pw.SizedBox(height: 3),
                      pw.Text("Difficulty: ${safeStr(difficulty)}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      if (createdByName.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text("Organised by: ${safeStr(createdByName)}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                      if (quizDepartment.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text("Department: ${safeStr(quizDepartment)}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("Year: Year $selectedYear", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2563EB'))),
                      pw.SizedBox(height: 3),
                      pw.Text("Total Students: ${students.length}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
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
              data: students.map((s) {
                final bool attempted = s["attempted"] == true || s["attempted"] == 1;
                final score = s["score"] ?? s["marks"];
                final total = s["total"];
                final String markText = (attempted && score != null && total != null)
                    ? "$score / $total"
                    : (attempted && score != null)
                        ? "$score / 10"
                        : "ABSENT / NOT ATTEMPTED";
                return [
                  s["uid"].toString(),
                  safeStr(s["name"]),
                  markText,
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  // ================= UI BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      appBar: AppBar(
        title: const Text("Class Performance"),
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
          if (!loading && activeQuiz != null && students.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_rounded,
                  color: AurumColors.accentGold),
              onPressed: generatePdf,
              tooltip: "Download PDF",
            )
        ],
      ),
      body: Column(
        children: [
          // =========================
          // FILTER CONTROLS (hidden once a quiz is open)
          // =========================
          if (activeQuiz == null)
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
                  if (showDeptFilter) ...[
                    loadingDepts
                        ? const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: AurumColors.accentGold,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: AurumColors.backgroundBlack,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int?>(
                                  value: selectedDeptId,
                                  isExpanded: true,
                                  dropdownColor: AurumColors.surfaceDark,
                                  icon: const Icon(Icons.arrow_drop_down,
                                      color: AurumColors.accentGold),
                                  style: const TextStyle(
                                      color: AurumColors.textWhite,
                                      fontWeight: FontWeight.bold),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text("All Departments"),
                                    ),
                                    ...departments.map((d) =>
                                        DropdownMenuItem<int?>(
                                          value: d["id"] as int,
                                          child: Text("${d["name"]}"),
                                        )),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => selectedDeptId = v),
                                ),
                              ),
                            ),
                          ),
                  ],
                  Row(
                    children: [
                      // Year Selector
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
                              value: selectedYear,
                              dropdownColor: AurumColors.surfaceDark,
                              icon: const Icon(Icons.arrow_drop_down,
                                  color: AurumColors.accentGold),
                              style: const TextStyle(
                                  color: AurumColors.textWhite,
                                  fontWeight: FontWeight.bold),
                              items: const [
                                DropdownMenuItem(
                                    value: 1, child: Text("Year 1")),
                                DropdownMenuItem(
                                    value: 2, child: Text("Year 2")),
                                DropdownMenuItem(
                                    value: 3, child: Text("Year 3")),
                                DropdownMenuItem(
                                    value: 4, child: Text("Year 4")),
                              ],
                              onChanged: (v) =>
                                  setState(() => selectedYear = v!),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Date Picker Button
                      Expanded(
                        flex: 3,
                        child: InkWell(
                          onTap: pickDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 12),
                            decoration: BoxDecoration(
                              color: AurumColors.backgroundBlack,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 16,
                                    color: selectedDate == null
                                        ? AurumColors.textGrey
                                        : AurumColors.accentGold),
                                const SizedBox(width: 8),
                                Text(
                                  selectedDate == null
                                      ? "Select Date"
                                      : "${selectedDate!.day}-${selectedDate!.month}-${selectedDate!.year}",
                                  style: TextStyle(
                                    color: selectedDate == null
                                        ? AurumColors.textGrey
                                        : AurumColors.textWhite,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : fetchQuizList,
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
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "SEARCH QUIZZES",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),

          // =========================
          // CONTENT
          // =========================
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AurumColors.accentGold))
                : activeQuiz != null
                    ? _buildQuizDetail()
                    : quizList.isNotEmpty
                        ? _buildQuizList()
                        : searched
                            ? _buildPlaceholder(
                                "No quizzes were taken on this date")
                            : _buildPlaceholder(
                                "Select a year and date to search"),
          ),
        ],
      ),
    );
  }

  // ================= STEP 1 UI: LIST OF QUIZZES =================
  Widget _buildQuizList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Text(
            "${quizList.length} quiz${quizList.length == 1 ? '' : 'zes'} taken on this date",
            style: const TextStyle(
                color: AurumColors.textGrey,
                fontSize: 12,
                fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: quizList.length,
            itemBuilder: (_, i) {
              final q = quizList[i];
              return InkWell(
                onTap: () => openQuiz(q),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AurumColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${q["topic"] ?? "Untitled"}",
                              style: const TextStyle(
                                color: AurumColors.textWhite,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${q["subject"] ?? ""} • ${q["department"] ?? ""}",
                              style: const TextStyle(
                                  color: AurumColors.textGrey, fontSize: 12),
                            ),
                            if (q["created_by_name"] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                "Created by: ${q["created_by_name"]}",
                                style: const TextStyle(
                                    color: AurumColors.accentGold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: AurumColors.textGrey, size: 16),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ================= STEP 2 UI: STUDENT MARKS FOR ONE QUIZ =================
  Widget _buildQuizDetail() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              InkWell(
                onTap: backToList,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back_ios_rounded,
                          color: AurumColors.accentGold, size: 14),
                      SizedBox(width: 4),
                      Text("Back to quiz list",
                          style: TextStyle(
                              color: AurumColors.accentGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (students.isEmpty)
          Expanded(child: _buildPlaceholder("No records found for this quiz"))
        else
          Expanded(
            child: Column(
              children: [
                // Quiz Info Header
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AurumColors.accentGold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AurumColors.accentGold.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "TOPIC",
                            style: TextStyle(
                                color: AurumColors.accentGold,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            topic.isEmpty ? "N/A" : topic,
                            style: const TextStyle(
                                color: AurumColors.textWhite,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            "DIFFICULTY",
                            style: TextStyle(
                                color: AurumColors.accentGold,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            difficulty.isEmpty
                                ? "N/A"
                                : difficulty.toUpperCase(),
                            style: const TextStyle(
                                color: AurumColors.textWhite,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (createdByName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 6, left: 16, right: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Created by: $createdByName",
                        style: const TextStyle(
                            color: AurumColors.textGrey,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),

                // List Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 8),
                  child: Row(
                    children: const [
                      Expanded(
                          child: Text("STUDENT",
                              style: TextStyle(
                                  color: AurumColors.textGrey, fontSize: 10))),
                      Text("STATUS / SCORE",
                          style: TextStyle(
                              color: AurumColors.textGrey, fontSize: 10)),
                    ],
                  ),
                ),

                // Students List (already uid-ascending from the backend)
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: students.length,
                    itemBuilder: (_, i) {
                      final s = students[i];
                      final bool attempted = s["attempted"] == 1;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AurumColors.cardSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: attempted
                                  ? AurumColors.successGreen.withOpacity(0.3)
                                  : AurumColors.errorRed.withOpacity(0.3),
                              width: 1),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: AurumColors.backgroundBlack,
                            child: Text(
                              s["name"].substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                color: attempted
                                    ? AurumColors.successGreen
                                    : AurumColors.errorRed,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            s["name"],
                            style: const TextStyle(
                              color: AurumColors.textWhite,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            "UID: ${s['uid']}",
                            style: const TextStyle(
                                color: AurumColors.textGrey, fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: attempted
                                      ? AurumColors.successGreen
                                          .withOpacity(0.1)
                                      : AurumColors.errorRed.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  attempted
                                      ? "${s['marks']} / $totalMarks"
                                      : "Absent",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: attempted
                                        ? AurumColors.successGreen
                                        : AurumColors.errorRed,
                                  ),
                                ),
                              ),
                              if (canReset) ...[
                                const SizedBox(width: 6),
                                resettingUid == s["uid"]
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          color: AurumColors.accentGold,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(
                                            Icons.restart_alt_rounded,
                                            color: AurumColors.accentGold,
                                            size: 20),
                                        tooltip: "Reset this student's quiz",
                                        onPressed: () => resetStudent(s),
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
    );
  }

  Widget _buildPlaceholder(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined,
              size: 60, color: AurumColors.surfaceDark),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AurumColors.textGrey)),
        ],
      ),
    );
  }
}
