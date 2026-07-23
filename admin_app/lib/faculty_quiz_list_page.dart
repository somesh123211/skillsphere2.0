import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'admin_session.dart';
import 'view_quiz_page.dart';
import 'delete_quiz_page.dart';

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
  static const Color errorRed = Color(0xFFCF6679);

  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldStart, goldEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class FacultyQuizListPage extends StatefulWidget {
  final AdminSession session;

  const FacultyQuizListPage({Key? key, required this.session}) : super(key: key);

  @override
  State<FacultyQuizListPage> createState() => _FacultyQuizListPageState();
}

class _FacultyQuizListPageState extends State<FacultyQuizListPage> {
  final String baseUrl = "https://skillsphere-2-qanz.onrender.com";

  int? selectedYear;
  DateTime? selectedDate;
  bool loading = false;
  List<dynamic> quizzes = [];

  // Department filter — only super_admin/admin see quizzes across every
  // department, so only they get a filter to narrow it down; hod/faculty
  // are already scoped server-side to their own department's quizzes.
  List<Map<String, dynamic>> departments = [];
  int? selectedDeptId;
  bool loadingDepts = false;

  bool get showDeptPicker => widget.session.isSuperAdmin;

  @override
  void initState() {
    super.initState();
    if (showDeptPicker) {
      fetchDepartments();
    }
    fetchQuizzes();
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
        setState(() =>
            departments = List<Map<String, dynamic>>.from(decoded["departments"]));
      }
    } catch (_) {
      // Filter just stays empty/"All Departments".
    }
    setState(() => loadingDepts = false);
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
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
    if (picked != null) {
      setState(() => selectedDate = picked);
      fetchQuizzes();
    }
  }

  Future<void> fetchQuizzes() async {
    setState(() => loading = true);

    final dateStr = selectedDate == null
        ? null
        : "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";

    final uri = Uri.parse("$baseUrl/api/admin/faculty-quiz/list").replace(
      queryParameters: {
        if (selectedYear != null) "year": "$selectedYear",
        if (dateStr != null) "quiz_date": dateStr,
        if (showDeptPicker && selectedDeptId != null)
          "dept_id": "$selectedDeptId",
      },
    );

    try {
      final res = await http.get(
        uri,
        headers: {"Authorization": "Bearer ${widget.session.token}"},
      );
      final decoded = jsonDecode(res.body);
      if (decoded["success"] == true) {
        setState(() => quizzes = decoded["quizzes"] ?? []);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decoded["message"] ?? "Failed to load quizzes"),
            backgroundColor: AurumColors.errorRed,
          ),
        );
      }
    } catch (e) {
      debugPrint("Faculty quiz list error: $e");
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

  void openActions(Map<String, dynamic> quiz) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AurumColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "${quiz["quiz_name"] ?? "Quiz #${quiz["quiz_id"]}"}",
                  style: const TextStyle(
                      color: AurumColors.textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.visibility_outlined,
                    color: AurumColors.accentGold),
                title: const Text("View Details",
                    style: TextStyle(color: AurumColors.textWhite)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ViewQuizPage(
                        session: widget.session,
                        initialQuizId: quiz["quiz_id"],
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: AurumColors.errorRed),
                title: const Text("Delete Quiz",
                    style: TextStyle(color: AurumColors.errorRed)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeleteQuizPage(
                        session: widget.session,
                        initialQuizId: quiz["quiz_id"],
                      ),
                    ),
                  );
                  fetchQuizzes();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      appBar: AppBar(
        title: const Text("My Quizzes"),
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                // Date filter
                Expanded(
                  child: InkWell(
                    onTap: pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: AurumColors.cardSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              color: AurumColors.accentGold, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedDate == null
                                  ? "All Dates"
                                  : "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                  color: AurumColors.textWhite,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (selectedDate != null)
                            InkWell(
                              onTap: () {
                                setState(() => selectedDate = null);
                                fetchQuizzes();
                              },
                              child: const Icon(Icons.close,
                                  color: AurumColors.textGrey, size: 16),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Year filter
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AurumColors.cardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: selectedYear,
                        isExpanded: true,
                        dropdownColor: AurumColors.surfaceDark,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: AurumColors.accentGold),
                        style: const TextStyle(
                            color: AurumColors.textWhite,
                            fontWeight: FontWeight.bold),
                        items: const [
                          DropdownMenuItem<int?>(
                              value: null, child: Text("All Years")),
                          DropdownMenuItem(value: 1, child: Text("Year 1")),
                          DropdownMenuItem(value: 2, child: Text("Year 2")),
                          DropdownMenuItem(value: 3, child: Text("Year 3")),
                          DropdownMenuItem(value: 4, child: Text("Year 4")),
                        ],
                        onChanged: (v) {
                          setState(() => selectedYear = v);
                          fetchQuizzes();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showDeptPicker)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: loadingDepts
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(
                            color: AurumColors.accentGold),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AurumColors.cardSurface,
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
                                value: null, child: Text("All Departments")),
                            ...departments.map((d) => DropdownMenuItem<int?>(
                                  value: d["id"] as int,
                                  child: Text(d["name"].toString()),
                                )),
                          ],
                          onChanged: (v) {
                            setState(() => selectedDeptId = v);
                            fetchQuizzes();
                          },
                        ),
                      ),
                    ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AurumColors.accentGold))
                : quizzes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.quiz_outlined,
                                size: 60, color: AurumColors.surfaceDark),
                            const SizedBox(height: 16),
                            const Text("No faculty quizzes yet",
                                style: TextStyle(color: AurumColors.textGrey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: quizzes.length,
                        itemBuilder: (_, i) {
                          final q = quizzes[i];
                          return InkWell(
                            onTap: () => openActions(q),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AurumColors.cardSurface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "${q["quiz_name"] ?? "Quiz #${q["quiz_id"]}"}",
                                          style: const TextStyle(
                                            color: AurumColors.textWhite,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "${q["quiz_date"]} • ${q["quiz_start_time"]}-${q["quiz_end_time"]} • Y${q["year"]} • ${q["duration_minutes"]}min • ${q["question_count"]} Qs",
                                          style: const TextStyle(
                                              color: AurumColors.textGrey,
                                              fontSize: 12),
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
      ),
    );
  }
}
