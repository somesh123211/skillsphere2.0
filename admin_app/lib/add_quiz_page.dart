import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

class AddQuizPage extends StatefulWidget {
  final String token;

  const AddQuizPage({Key? key, required this.token}) : super(key: key);

  @override
  State<AddQuizPage> createState() => _AddQuizPageState();
}

class _AddQuizPageState extends State<AddQuizPage> {
  final String baseUrl = "https://skillsphere1-0-0.onrender.com";

  final TextEditingController quizIdController = TextEditingController();
  final TextEditingController createdByController = TextEditingController();

  int year = 2;
  DateTime quizDate = DateTime.now();
  TimeOfDay startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 11, minute: 0);

  bool processing = false;

  String formatTime(TimeOfDay t) {
    return "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
  }

  // =========================
  // CREATE QUIZ LOGIC
  // =========================
  Future<void> createQuiz() async {
    if (quizIdController.text.isEmpty || createdByController.text.isEmpty) {
      showError("Please fill all fields");
      return;
    }

    setState(() => processing = true);

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/api/admin/faculty-quiz/create"),
        headers: {
          "Authorization": "Bearer ${widget.token}",
          "Content-Type": "application/json",
        },
        body: json.encode({
          "quiz_id": int.tryParse(quizIdController.text) ?? 0,
          "quiz_date": quizDate.toIso8601String().split("T")[0],
          "quiz_start_time": formatTime(startTime),
          "quiz_end_time": formatTime(endTime),
          "year": year,
          "created_by": createdByController.text,
        }),
      );

      if (res.statusCode == 201) {
        showSuccess("Quiz created successfully");
        quizIdController.clear();
        createdByController.clear();
      } else {
        final errorMsg = json.decode(res.body)["error"] ?? "Failed to create quiz";
        showError(errorMsg);
      }
    } catch (e) {
      showError("Connection Error: $e");
    }

    setState(() => processing = false);
  }

  // =========================
  // HELPER FUNCTIONS
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
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: AurumColors.successGreen,
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
            timePickerTheme: TimePickerThemeData(
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
        title: const Text("Create New Quiz"),
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
            // Header Info
            _buildSectionHeader("Step 1", "General Information"),
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
                    controller: quizIdController,
                    label: "Quiz ID (Numeric)",
                    icon: Icons.numbers,
                    inputType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  _buildAurumTextField(
                    controller: createdByController,
                    label: "Created By (Faculty Name)",
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 20),
                  _buildAurumDropdown<int>(
                    label: "Target Year",
                    value: year,
                    items: const [
                      DropdownMenuItem(value: 2, child: Text("Year 2")),
                      DropdownMenuItem(value: 3, child: Text("Year 3")),
                    ],
                    onChanged: (v) => setState(() => year = v!),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Schedule Section
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
                  // Date Picker Tile
                  _buildPickerTile(
                    label: "Quiz Date",
                    value: quizDate.toIso8601String().split("T")[0],
                    icon: Icons.calendar_today,
                    onTap: _pickDate,
                  ),
                  const Divider(color: Colors.white10, height: 30),
                  
                  // Start Time Tile
                  _buildPickerTile(
                    label: "Start Time",
                    value: formatTime(startTime),
                    icon: Icons.access_time,
                    onTap: () => _pickTime(true),
                  ),
                  const Divider(color: Colors.white10, height: 30),

                  // End Time Tile
                  _buildPickerTile(
                    label: "End Time",
                    value: formatTime(endTime),
                    icon: Icons.timer_off_outlined,
                    onTap: () => _pickTime(false),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Create Button
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
                          color: Colors.black, // Contrast text for gold bg
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