import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'admin_session.dart';
import 'super_admin_generation_analytics_page.dart';

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
  static const Color successGreen = Color(0xFF4CAF50);

  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldStart, goldEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AddDailyQuizPage extends StatefulWidget {
  final AdminSession session;

  const AddDailyQuizPage({Key? key, required this.session}) : super(key: key);

  @override
  State<AddDailyQuizPage> createState() => _AddDailyQuizPageState();
}

class _AddDailyQuizPageState extends State<AddDailyQuizPage> {
  final String baseUrl = "https://skillsphere-2-qanz.onrender.com";

  // Mode: add / progress / remove
  String mode = "add";

  int selectedYear = 2;
  String difficulty = "medium";

  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay selectedEndTime = const TimeOfDay(hour: 18, minute: 0);
  final TextEditingController topicController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController questionsCountController =
      TextEditingController(text: "10");
  final TextEditingController durationController =
      TextEditingController(text: "10");

  static const int maxQuestions = 20;
  static const int maxDurationMinutes = 30;

  bool processing = false;

  // Department picker — only super_admin/admin get a free choice.
  // hod/faculty are forced to their own department server-side.
  List<Map<String, dynamic>> departments = [];
  int? selectedDeptId;
  bool loadingDepts = false;

  // Questions Generated (generation progress) tab
  bool loadingProgress = false;
  String? progressError;
  List<dynamic> progressQuizzes = [];

  bool get showDeptPicker => widget.session.isSuperAdmin;

  // Quizzes whose end time has already passed for the selected date
  // drop off the list automatically — once a quiz's window is over
  // there's nothing left to monitor.
  List<dynamic> get _activeProgressQuizzes {
    final now = DateTime.now();
    return progressQuizzes.where((q) {
      final endStr = "${q["quiz_end_time"] ?? "23:59:59"}";
      final parts = endStr.split(":");
      try {
        final end = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        return now.isBefore(end);
      } catch (e) {
        return true;
      }
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    if (showDeptPicker) {
      fetchDepartments();
    }
  }

  // =========================
  // FETCH DEPARTMENTS (super_admin/admin only)
  // =========================
  Future<void> fetchDepartments() async {
    setState(() => loadingDepts = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/admin/departments/quiz-enabled"),
        headers: {"Authorization": "Bearer ${widget.session.token}"},
      );
      final data = json.decode(response.body);
      if (data["success"] == true) {
        final list = List<Map<String, dynamic>>.from(data["departments"]);
        setState(() {
          departments = list;
          if (selectedDeptId == null && list.isNotEmpty) {
            selectedDeptId = list.first["id"];
          }
        });
      }
    } catch (e) {
      // Dropdown just stays empty; submit-time validation below will
      // surface a clear error rather than failing silently.
    }
    setState(() => loadingDepts = false);
  }

  // =========================
  // DATE PICKER
  // =========================
  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
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
      if (mode == "progress" || mode == "remove") fetchProgress();
    }
  }

  // =========================
  // TIME PICKERS
  // =========================
  Future<void> pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedStartTime,
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
      setState(() => selectedStartTime = picked);
    }
  }

  Future<void> pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedEndTime,
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
      setState(() => selectedEndTime = picked);
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return "$hh:$mm";
  }

  // =========================
  // ADD QUIZ
  // =========================
  Future<void> addQuizTopic() async {
    if (subjectController.text.trim().isEmpty) {
      showError("Subject is required");
      return;
    }
    if (topicController.text.trim().isEmpty) {
      showError("Quiz topic is required");
      return;
    }
    if (showDeptPicker && selectedDeptId == null) {
      showError("Please select a department");
      return;
    }
    final startMinutes = selectedStartTime.hour * 60 + selectedStartTime.minute;
    final endMinutes = selectedEndTime.hour * 60 + selectedEndTime.minute;
    if (endMinutes <= startMinutes) {
      showError("End time must be after start time");
      return;
    }
    final questionsCount = int.tryParse(questionsCountController.text.trim());
    if (questionsCount == null || questionsCount < 1 || questionsCount > maxQuestions) {
      showError("Number of questions must be between 1 and $maxQuestions");
      return;
    }
    final duration = int.tryParse(durationController.text.trim());
    if (duration == null || duration < 1 || duration > maxDurationMinutes) {
      showError("Time limit must be between 1 and $maxDurationMinutes minutes");
      return;
    }

    setState(() => processing = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/admin/daily-quiz/topic"),
        headers: {
          "Authorization": "Bearer ${widget.session.token}",
          "Content-Type": "application/json",
        },
        body: json.encode({
          "year": selectedYear,
          "quiz_date": selectedDate.toIso8601String().split("T")[0],
          "quiz_type": "placement",
          "subject": subjectController.text.trim(),
          "topic": topicController.text.trim(),
          "difficulty": difficulty,
          "quiz_start_time": _formatTimeOfDay(selectedStartTime),
          "quiz_end_time": _formatTimeOfDay(selectedEndTime),
          "questions_per_student": questionsCount,
          "duration_minutes": duration,
          if (selectedDeptId != null) "dept_id": selectedDeptId,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        showSuccess("Quiz topic added successfully");
        subjectController.clear();
        topicController.clear();
      } else {
        showError(data["error"] ?? "Failed to add quiz");
      }
    } catch (e) {
      debugPrint("Add quiz topic error: $e");
      showError("Unable to connect to the server. Please try again.");
    }

    setState(() => processing = false);
  }

  // =========================
  // QUESTIONS GENERATED (progress) FETCH
  // =========================
  Future<void> fetchProgress() async {
    setState(() {
      loadingProgress = true;
      progressError = null;
      progressQuizzes = [];
    });

    try {
      final dateStr = selectedDate.toIso8601String().split("T")[0];
      final response = await http.get(
        Uri.parse(
            "$baseUrl/api/admin/daily-quiz/progress/$selectedYear/$dateStr"),
        headers: {"Authorization": "Bearer ${widget.session.token}"},
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        setState(() => progressQuizzes = data["quizzes"] ?? []);
      } else {
        setState(() =>
            progressError = data["error"] ?? "No quizzes found for this date");
      }
    } catch (e) {
      setState(() => progressError = "Server error or connection failed");
    }

    setState(() => loadingProgress = false);
  }

  TimeOfDay? _parseTimeOfDay(String s) {
    try {
      final parts = s.split(":");
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (e) {
      return null;
    }
  }

  // =========================
  // DELETE A SPECIFIC QUIZ (Remove Quiz tab)
  // =========================
  Future<void> deleteQuizById(dynamic quiz) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurumColors.surfaceDark,
        title: const Text("Delete Quiz?", style: TextStyle(color: Colors.white)),
        content: Text(
          "This will permanently delete \"${quiz["topic"]}\" and all its generated questions and sets. This cannot be undone.",
          style: const TextStyle(color: AurumColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: AurumColors.textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: AurumColors.errorRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/admin/daily-quiz/topic/delete"),
        headers: {
          "Authorization": "Bearer ${widget.session.token}",
          "Content-Type": "application/json",
        },
        body: json.encode({
          "year": selectedYear,
          "quiz_id": quiz["id"],
        }),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        showSuccess("Quiz removed successfully");
        fetchProgress();
      } else {
        showError(data["error"] ?? "Failed to remove quiz");
      }
    } catch (e) {
      debugPrint("Remove quiz error: $e");
      showError("Unable to connect to the server. Please try again.");
    }
  }

  // =========================
  // EDIT TIME FOR A SPECIFIC QUIZ (Remove Quiz tab)
  // =========================
  Future<void> editQuizTime(dynamic quiz) async {
    TimeOfDay start =
        _parseTimeOfDay("${quiz["quiz_start_time"]}") ?? const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end =
        _parseTimeOfDay("${quiz["quiz_end_time"]}") ?? const TimeOfDay(hour: 18, minute: 0);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AurumColors.surfaceDark,
              title: const Text("Edit Quiz Time", style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTimePickerTile(
                    label: "Start Time",
                    time: start,
                    onTap: () async {
                      final picked = await showTimePicker(context: ctx, initialTime: start);
                      if (picked != null) setDialogState(() => start = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildTimePickerTile(
                    label: "End Time",
                    time: end,
                    onTap: () async {
                      final picked = await showTimePicker(context: ctx, initialTime: end);
                      if (picked != null) setDialogState(() => end = picked);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Cancel", style: TextStyle(color: AurumColors.textGrey)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Save", style: TextStyle(color: AurumColors.accentGold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/admin/daily-quiz/edit-time"),
        headers: {
          "Authorization": "Bearer ${widget.session.token}",
          "Content-Type": "application/json",
        },
        body: json.encode({
          "year": selectedYear,
          "quiz_id": quiz["id"],
          "quiz_start_time": _formatTimeOfDay(start),
          "quiz_end_time": _formatTimeOfDay(end),
        }),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        showSuccess("Quiz timings updated");
        fetchProgress();
      } else {
        showError(data["error"] ?? "Failed to update timings");
      }
    } catch (e) {
      debugPrint("Update timings error: $e");
      showError("Unable to connect to the server. Please try again.");
    }
  }

  // =========================
  // SNACKBARS
  // =========================
  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: AurumColors.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.black)),
        backgroundColor: AurumColors.accentGold,
        behavior: SnackBarBehavior.floating,
      ),
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
        title: const Text("Quiz Manager"),
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
          if (widget.session.isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.analytics_rounded, color: AurumColors.accentGold),
              tooltip: "Generation Analytics",
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SuperAdminGenerationAnalyticsPage(session: widget.session),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =========================
            // MODE TOGGLE
            // =========================
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AurumColors.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModeTab("Add Quiz", "add"),
                  ),
                  Expanded(
                    child: _buildModeTab("Questions Generated", "progress"),
                  ),
                  Expanded(
                    child: _buildModeTab("Remove Quiz", "remove"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // =========================
            // COMMON SETTINGS CARD
            // =========================
            const Text(
              "CONFIGURATION",
              style: TextStyle(
                color: AurumColors.textGrey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AurumColors.cardSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  // Department Selector — super_admin/admin only.
                  // hod/faculty are locked to their own department by
                  // the backend, so no picker is shown for them at all.
                  if (showDeptPicker && mode == "add") ...[
                    loadingDepts
                        ? const Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: AurumColors.accentGold,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : _buildAurumDropdown<int>(
                            label: "Department",
                            value: selectedDeptId,
                            items: departments
                                .map((d) => DropdownMenuItem<int>(
                                      value: d["id"] as int,
                                      child: Text("${d["name"]}"),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => selectedDeptId = v),
                          ),
                    const Divider(color: Colors.white10, height: 30),
                  ],

                  // Year Selector
                  _buildAurumDropdown<int>(
                    label: "Target Year",
                    value: selectedYear,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text("Year 1")),
                      DropdownMenuItem(value: 2, child: Text("Year 2")),
                      DropdownMenuItem(value: 3, child: Text("Year 3")),
                      DropdownMenuItem(value: 4, child: Text("Year 4")),
                    ],
                    onChanged: (v) {
                      setState(() => selectedYear = v!);
                      if (mode == "progress" || mode == "remove") fetchProgress();
                    },
                  ),
                  const Divider(color: Colors.white10, height: 30),

                  // Date Picker
                  InkWell(
                    onTap: pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AurumColors.accentGold.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.calendar_month,
                                color: AurumColors.accentGold),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Scheduled Date",
                                style: TextStyle(
                                    color: AurumColors.textGrey, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedDate.toIso8601String().split("T")[0],
                                style: const TextStyle(
                                  color: AurumColors.textWhite,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Icon(Icons.edit,
                              color: AurumColors.textGrey, size: 16),
                        ],
                      ),
                    ),
                  ),

                  // Start / End Time Pickers — only relevant when
                  // publishing a new quiz (students need a live window).
                  if (mode == "add") ...[
                    const Divider(color: Colors.white10, height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimePickerTile(
                            label: "Start Time",
                            time: selectedStartTime,
                            onTap: pickStartTime,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTimePickerTile(
                            label: "End Time",
                            time: selectedEndTime,
                            onTap: pickEndTime,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 30),

            // =========================
            // ADD MODE SPECIFIC FIELDS
            // =========================
            if (mode == "add") ...[
              const Text(
                "QUIZ DETAILS",
                style: TextStyle(
                  color: AurumColors.textGrey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AurumColors.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    // Subject Field
                    _buildAurumTextField(
                      controller: subjectController,
                      label: "Subject",
                      icon: Icons.menu_book_outlined,
                    ),
                    const SizedBox(height: 20),

                    // Topic Field
                    _buildAurumTextField(
                      controller: topicController,
                      label: "Quiz Topic",
                      icon: Icons.topic_outlined,
                    ),
                    const SizedBox(height: 20),

                    // Difficulty
                    _buildAurumDropdown<String>(
                      label: "Difficulty Level",
                      value: difficulty,
                      items: const [
                        DropdownMenuItem(
                            value: "basic", child: Text("Basic (Very Simple)")),
                        DropdownMenuItem(value: "easy", child: Text("Easy")),
                        DropdownMenuItem(
                            value: "medium", child: Text("Medium")),
                        DropdownMenuItem(value: "hard", child: Text("Hard")),
                        DropdownMenuItem(
                            value: "very hard", child: Text("Expert")),
                      ],
                      onChanged: (v) => setState(() => difficulty = v!),
                    ),
                    const SizedBox(height: 20),

                    // Number of Questions
                    _buildAurumTextField(
                      controller: questionsCountController,
                      label: "Number of Questions (max $maxQuestions)",
                      icon: Icons.format_list_numbered,
                      inputType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),

                    // Time Limit for Students
                    _buildAurumTextField(
                      controller: durationController,
                      label:
                          "Time Limit for Students (minutes, max $maxDurationMinutes)",
                      icon: Icons.hourglass_bottom_outlined,
                      inputType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ],

            // =========================
            // QUESTIONS GENERATED (PROGRESS) / REMOVE QUIZ LIST
            // =========================
            if (mode == "progress" || mode == "remove") ...[
              Text(
                mode == "progress" ? "GENERATION STATUS" : "YOUR QUIZZES",
                style: const TextStyle(
                  color: AurumColors.textGrey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              if (progressError != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AurumColors.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AurumColors.errorRed.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AurumColors.errorRed),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          progressError!,
                          style: const TextStyle(color: AurumColors.errorRed),
                        ),
                      ),
                    ],
                  ),
                )
              else if (loadingProgress)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AurumColors.accentGold),
                  ),
                )
              else if (_activeProgressQuizzes.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AurumColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    progressQuizzes.isEmpty
                        ? (mode == "progress"
                            ? "No quizzes for this year/date yet. Pick a year and date above, or publish one from Add Quiz."
                            : "You have no quizzes to manage for this year/date.")
                        : "All quizzes for this date have ended.",
                    style: const TextStyle(color: AurumColors.textGrey),
                  ),
                )
              else
                Column(
                  children: _activeProgressQuizzes
                      .map((q) =>
                          _buildProgressCard(q, showActions: mode == "remove"))
                      .toList(),
                ),
            ],

            const SizedBox(height: 40),

            // =========================
            // ACTION BUTTON
            // =========================
            InkWell(
              onTap: (processing || loadingProgress)
                  ? null
                  : mode == "add"
                      ? addQuizTopic
                      : fetchProgress,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  gradient: AurumColors.goldGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AurumColors.accentGold.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: (processing || loadingProgress)
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            mode == "add"
                                ? Icons.add_circle
                                : Icons.refresh_rounded,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            mode == "add"
                                ? "PUBLISH QUIZ"
                                : mode == "remove"
                                    ? "REFRESH LIST"
                                    : "CHECK STATUS",
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  // Custom Toggle Tab
  Widget _buildModeTab(String title, String value) {
    bool isSelected = mode == value;
    return GestureDetector(
      onTap: () {
        setState(() => mode = value);
        if (value == "progress" || value == "remove") {
          fetchProgress();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AurumColors.backgroundBlack : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AurumColors.accentGold.withOpacity(0.5))
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? AurumColors.accentGold : AurumColors.textGrey,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // Time Picker Tile (Start / End)
  Widget _buildTimePickerTile({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AurumColors.accentGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.access_time,
                  color: AurumColors.accentGold, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        color: AurumColors.textGrey, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimeOfDay(time),
                    style: const TextStyle(
                      color: AurumColors.textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Custom Text Field
  Widget _buildAurumTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      style: const TextStyle(color: AurumColors.textWhite),
      cursorColor: AurumColors.accentGold,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AurumColors.textGrey),
        prefixIcon: Icon(icon, color: AurumColors.accentGold),
        filled: true,
        fillColor: AurumColors.backgroundBlack,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AurumColors.accentGold),
        ),
      ),
    );
  }

  // Custom Dropdown
  Widget _buildAurumDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AurumColors.textGrey, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AurumColors.backgroundBlack,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: AurumColors.surfaceDark,
              hint: const Text("Select",
                  style: TextStyle(color: AurumColors.textGrey)),
              icon: const Icon(Icons.arrow_drop_down,
                  color: AurumColors.accentGold),
              style: const TextStyle(
                  color: AurumColors.textWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // Generation progress card (Questions Generated / Remove Quiz tabs)
  Widget _buildProgressCard(dynamic q, {bool showActions = false}) {
    final String status = "${q["status"] ?? "UNKNOWN"}";
    final int generated = (q["generated_sets"] ?? 0) as int;
    final int failed = (q["failed_sets"] ?? 0) as int;
    final int total = (q["total_sets_required"] ?? 0) as int;
    final int percentage = (q["percentage"] ?? 0) as int;

    Color statusColor;
    switch (status) {
      case "READY":
        statusColor = AurumColors.successGreen;
        break;
      case "FAILED":
        statusColor = AurumColors.errorRed;
        break;
      default:
        statusColor = AurumColors.accentGold;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AurumColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "${q["topic"] ?? "Untitled"}",
                  style: const TextStyle(
                    color: AurumColors.textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "${q["subject"] ?? ""} • ${q["department"] ?? ""}",
            style: const TextStyle(color: AurumColors.textGrey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total > 0 ? percentage / 100 : 0,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$generated / $total sets generated",
                style:
                    const TextStyle(color: AurumColors.textGrey, fontSize: 12),
              ),
              if (failed > 0)
                Text(
                  "$failed failed",
                  style: const TextStyle(
                      color: AurumColors.errorRed,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                )
              else
                Text(
                  "$percentage%",
                  style: const TextStyle(
                      color: AurumColors.textWhite,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
            ],
          ),
          if (showActions) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => editQuizTime(q),
                    icon: const Icon(Icons.edit_calendar_outlined,
                        size: 16, color: AurumColors.accentGold),
                    label: const Text("Edit Time",
                        style: TextStyle(color: AurumColors.accentGold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AurumColors.accentGold.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => deleteQuizById(q),
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: AurumColors.errorRed),
                    label: const Text("Delete",
                        style: TextStyle(color: AurumColors.errorRed)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AurumColors.errorRed.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
