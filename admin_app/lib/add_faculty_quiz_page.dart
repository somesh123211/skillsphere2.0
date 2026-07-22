import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
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

class AddFacultyQuizPage extends StatefulWidget {
  final AdminSession session;

  const AddFacultyQuizPage({Key? key, required this.session}) : super(key: key);

  @override
  State<AddFacultyQuizPage> createState() => _AddFacultyQuizPageState();
}

class _AddFacultyQuizPageState extends State<AddFacultyQuizPage> {
  final String baseUrl = "https://skillsphere2-0.onrender.com";

  final TextEditingController nameController = TextEditingController();
  final TextEditingController durationController =
      TextEditingController(text: "15");

  int year = 2;
  DateTime quizDate = DateTime.now();
  TimeOfDay startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 11, minute: 0);

  Uint8List? csvBytes;
  String? csvFileName;
  int? csvRowCount;

  bool processing = false;
  bool checkingCsv = false;

  // Department picker — only super_admin/admin get a free choice.
  // hod/faculty are forced to their own department server-side.
  List<Map<String, dynamic>> departments = [];
  int? selectedDeptId;
  bool loadingDepts = false;

  bool get showDeptPicker => widget.session.isSuperAdmin;

  static const int maxQuestions = 30;
  static const int maxDurationMinutes = 30;

  @override
  void initState() {
    super.initState();
    if (showDeptPicker) {
      fetchDepartments();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    durationController.dispose();
    super.dispose();
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
      // Dropdown just stays empty; submit-time validation surfaces a
      // clear error rather than failing silently.
    }
    setState(() => loadingDepts = false);
  }

  String formatTime(TimeOfDay t) {
    return "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
  }

  // =========================
  // SAMPLE CSV EMAIL REQUEST
  // =========================
  Future<void> requestSampleCsvEmail() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AurumColors.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.email_outlined, color: AurumColors.accentGold),
              SizedBox(width: 10),
              Text("Request Sample CSV", style: TextStyle(color: AurumColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            "Do you want the Sample CSV template sent to your registered email address (${widget.session.email})?",
            style: const TextStyle(color: AurumColors.textWhite, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("No", style: TextStyle(color: AurumColors.textGrey, fontSize: 14)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AurumColors.accentGold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Yes, Send Email", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => loading = true);
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/api/admin/faculty-quiz/send-sample-csv"),
        headers: {
          "Authorization": "Bearer ${widget.session.token}",
          "Content-Type": "application/json"
        },
      );
      final data = jsonDecode(res.body);
      if (data["success"] == true) {
        showSuccess(data["message"] ?? "Sample CSV template has been sent to your registered email.");
      } else {
        showError(data["message"] ?? "Failed to send email. Please try again.");
      }
    } catch (e) {
      debugPrint("Sample CSV email error: $e");
      showError("Could not connect to server. Please try again.");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // =========================
  // CHECK CSV (authoritative server-side validation, no upload/commit)
  // =========================
  Future<void> checkCsv() async {
    if (csvBytes == null || csvFileName == null) {
      showError("Please select a CSV file first");
      return;
    }

    setState(() => checkingCsv = true);
    try {
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/api/admin/faculty-quiz/validate-csv"),
      );
      request.headers["Authorization"] = "Bearer ${widget.session.token}";
      request.files.add(http.MultipartFile.fromBytes(
        "file",
        csvBytes!,
        filename: csvFileName!,
      ));

      final res = await request.send();
      final body = await res.stream.bytesToString();
      final data = json.decode(body);

      if (!mounted) return;

      if (res.statusCode == 200 && data["success"] == true) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AurumColors.surfaceDark,
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AurumColors.successGreen),
                SizedBox(width: 10),
                Text("CSV Looks Good",
                    style: TextStyle(color: AurumColors.textWhite)),
              ],
            ),
            content: Text(
              "${data['total_questions']} question(s) passed all checks: "
              "columns, filled fields and valid answer keys.",
              style: const TextStyle(color: AurumColors.textGrey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK",
                    style: TextStyle(color: AurumColors.accentGold)),
              ),
            ],
          ),
        );
      } else {
        final details = data["details"];
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AurumColors.surfaceDark,
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: AurumColors.errorRed),
                SizedBox(width: 10),
                Text("CSV Has Problems",
                    style: TextStyle(color: AurumColors.textWhite)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Text(
                  details is List && details.isNotEmpty
                      ? details.join('\n')
                      : (data["error"] ?? "CSV validation failed").toString(),
                  style: const TextStyle(color: AurumColors.textGrey),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK",
                    style: TextStyle(color: AurumColors.accentGold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("Faculty quiz request error: $e");
      showError("Unable to connect to the server. Please check your internet connection and try again.");
    }

    setState(() => checkingCsv = false);
  }

  // =========================
  // PICK + LIGHT CLIENT-SIDE CHECK
  // =========================
  Future<void> pickCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["csv"],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) return;

    // Quick client-side sanity check for fast feedback - the server is
    // still the source of truth for full validation.
    try {
      final content = utf8.decode(bytes);
      final lines = const LineSplitter()
          .convert(content)
          .where((l) => l.trim().isNotEmpty)
          .toList();

      if (lines.isEmpty) {
        showError("CSV file is empty");
        return;
      }

      final headers =
          lines.first.split(',').map((e) => e.trim().toLowerCase()).toSet();
      const required = [
        'question',
        'option_a',
        'option_b',
        'option_c',
        'option_d',
        'correct_option'
      ];
      final missing = required.where((c) => !headers.contains(c)).toList();
      if (missing.isNotEmpty) {
        showError("CSV is missing column(s): ${missing.join(', ')}");
        return;
      }

      final rowCount = lines.length - 1;
      if (rowCount == 0) {
        showError("CSV has no question rows");
        return;
      }
      if (rowCount > maxQuestions) {
        showError("Too many questions: $rowCount (max $maxQuestions)");
        return;
      }

      setState(() {
        csvFileName = file.name;
        csvBytes = bytes;
        csvRowCount = rowCount;
      });
    } catch (e) {
      debugPrint("CSV read error: $e");
      showError("Could not read CSV file. Please check its format and try again.");
    }
  }

  // =========================
  // CREATE QUIZ (metadata + CSV in one request)
  // =========================
  Future<void> createQuiz() async {
    if (nameController.text.trim().isEmpty) {
      showError("Quiz name is required");
      return;
    }
    final duration = int.tryParse(durationController.text.trim());
    if (duration == null || duration < 1 || duration > maxDurationMinutes) {
      showError("Duration must be between 1 and $maxDurationMinutes minutes");
      return;
    }
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    if (endMinutes <= startMinutes) {
      showError("End time must be after start time");
      return;
    }
    final startDateTime = DateTime(
      quizDate.year,
      quizDate.month,
      quizDate.day,
      startTime.hour,
      startTime.minute,
    );
    if (startDateTime.difference(DateTime.now()).inMinutes < 5) {
      showError("Quiz start time must be at least 5 minutes in the future");
      return;
    }
    if (csvBytes == null || csvFileName == null) {
      showError("Please select a CSV file of questions");
      return;
    }
    if (showDeptPicker && selectedDeptId == null) {
      showError("Please select a department");
      return;
    }

    setState(() => processing = true);

    try {
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/api/admin/faculty-quiz/create"),
      );
      request.headers["Authorization"] = "Bearer ${widget.session.token}";
      request.fields["quiz_name"] = nameController.text.trim();
      request.fields["year"] = year.toString();
      request.fields["quiz_date"] = quizDate.toIso8601String().split("T")[0];
      request.fields["quiz_start_time"] = formatTime(startTime);
      request.fields["quiz_end_time"] = formatTime(endTime);
      request.fields["duration_minutes"] = duration.toString();
      if (selectedDeptId != null) {
        request.fields["dept_id"] = selectedDeptId.toString();
      }
      request.files.add(http.MultipartFile.fromBytes(
        "file",
        csvBytes!,
        filename: csvFileName!,
      ));

      final res = await request.send();
      final body = await res.stream.bytesToString();
      final data = json.decode(body);

      if (res.statusCode == 201) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AurumColors.surfaceDark,
              title: const Text("Quiz Created",
                  style: TextStyle(color: AurumColors.textWhite)),
              content: Text(
                "\"${data['quiz_name']}\" (ID: ${data['quiz_id']}) created with "
                "${data['total_questions']} questions.",
                style: const TextStyle(color: AurumColors.textGrey),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("OK",
                      style: TextStyle(color: AurumColors.accentGold)),
                ),
              ],
            ),
          );
          if (mounted) Navigator.pop(context, true);
        }
      } else {
        final details = data["details"];
        if (details is List && details.isNotEmpty) {
          showError("${data['error']}:\n${details.join('\n')}");
        } else {
          showError(data["error"] ?? "Failed to create quiz");
        }
      }
    } catch (e) {
      debugPrint("Faculty quiz request error: $e");
      showError("Unable to connect to the server. Please check your internet connection and try again.");
    }

    setState(() => processing = false);
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: AurumColors.errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: quizDate,
      firstDate: DateTime.now(),
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
    if (d != null) setState(() => quizDate = d);
  }

  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(
      context: context,
      initialTime: isStart ? startTime : endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: AurumColors.surfaceDark,
              dialHandColor: AurumColors.accentGold,
              dialBackgroundColor: AurumColors.backgroundBlack,
              hourMinuteTextColor: AurumColors.textWhite,
              dayPeriodTextColor: AurumColors.accentGold,
            ),
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
    if (t != null) {
      setState(() {
        if (isStart) {
          startTime = t;
        } else {
          endTime = t;
        }
      });
    }
  }

  // =========================
  // UI BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      appBar: AppBar(
        title: const Text("Create Faculty Quiz"),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Step 1", "Quiz Details"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AurumColors.cardSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  _buildAurumTextField(
                    controller: nameController,
                    label: "Quiz Name",
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 20),
                  _buildAurumDropdown<int>(
                    label: "Target Year",
                    value: year,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text("Year 1")),
                      DropdownMenuItem(value: 2, child: Text("Year 2")),
                      DropdownMenuItem(value: 3, child: Text("Year 3")),
                      DropdownMenuItem(value: 4, child: Text("Year 4")),
                    ],
                    onChanged: (v) => setState(() => year = v!),
                  ),
                  if (showDeptPicker) ...[
                    const SizedBox(height: 20),
                    loadingDepts
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: CircularProgressIndicator(
                                  color: AurumColors.accentGold),
                            ),
                          )
                        : _buildAurumDropdown<int>(
                            label: "Department",
                            value: selectedDeptId ??
                                (departments.isNotEmpty
                                    ? departments.first["id"]
                                    : 0),
                            items: departments
                                .map((d) => DropdownMenuItem<int>(
                                      value: d["id"] as int,
                                      child: Text(d["name"].toString()),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => selectedDeptId = v),
                          ),
                  ],
                  const SizedBox(height: 20),
                  _buildAurumTextField(
                    controller: durationController,
                    label: "Duration for students (minutes, max $maxDurationMinutes)",
                    icon: Icons.hourglass_bottom_outlined,
                    inputType: TextInputType.number,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            _buildSectionHeader("Step 2", "Schedule & Timing"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AurumColors.cardSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  _buildPickerTile(
                    label: "Quiz Date",
                    value: quizDate.toIso8601String().split("T")[0],
                    icon: Icons.calendar_today,
                    onTap: _pickDate,
                  ),
                  const Divider(color: Colors.white10, height: 30),
                  _buildPickerTile(
                    label: "Start Time",
                    value: formatTime(startTime),
                    icon: Icons.access_time,
                    onTap: () => _pickTime(true),
                  ),
                  const Divider(color: Colors.white10, height: 30),
                  _buildPickerTile(
                    label: "End Time",
                    value: formatTime(endTime),
                    icon: Icons.timer_off_outlined,
                    onTap: () => _pickTime(false),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildSectionHeader("Step 3", "Upload Questions (CSV)"),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AurumColors.accentGold, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: requestSampleCsvEmail,
                  icon: const Icon(Icons.email_outlined,
                      color: AurumColors.accentGold, size: 16),
                  label: const Text("Sample CSV",
                      style: TextStyle(color: AurumColors.accentGold, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Columns required: question, option_a, option_b, option_c, "
              "option_d, correct_option (A/B/C/D). Max $maxQuestions questions.",
              style: TextStyle(color: AurumColors.textGrey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AurumColors.cardSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: InkWell(
                onTap: pickCsv,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: csvFileName == null
                          ? AurumColors.textGrey.withOpacity(0.3)
                          : AurumColors.successGreen,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    color: csvFileName == null
                        ? Colors.transparent
                        : AurumColors.successGreen.withOpacity(0.1),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        csvFileName == null
                            ? Icons.upload_file
                            : Icons.description,
                        size: 40,
                        color: csvFileName == null
                            ? AurumColors.textGrey
                            : AurumColors.successGreen,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        csvFileName == null
                            ? "Tap to Select CSV File"
                            : "$csvFileName ($csvRowCount questions)",
                        style: TextStyle(
                          color: csvFileName == null
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

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (csvFileName == null || checkingCsv)
                    ? null
                    : checkCsv,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AurumColors.accentGold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: checkingCsv
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AurumColors.accentGold,
                        ),
                      )
                    : const Icon(Icons.fact_check_outlined,
                        color: AurumColors.accentGold),
                label: const Text(
                  "Check CSV",
                  style: TextStyle(
                    color: AurumColors.accentGold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            InkWell(
              onTap: processing ? null : createQuiz,
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
                child: processing
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        "CREATE QUIZ",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.1,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildSectionHeader(String step, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AurumColors.accentGold,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: AurumColors.textWhite,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

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

  Widget _buildAurumDropdown<T>({
    required String label,
    required T value,
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
              icon: const Icon(Icons.arrow_drop_down, color: AurumColors.accentGold),
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

  Widget _buildPickerTile({
    required String label,
    required String value,
    required IconData icon,
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
              child: Icon(icon, color: AurumColors.accentGold),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: AurumColors.textGrey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AurumColors.textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.edit, color: AurumColors.textGrey, size: 16),
          ],
        ),
      ),
    );
  }
}
