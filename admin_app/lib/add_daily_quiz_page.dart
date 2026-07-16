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
  static const Color errorRed = Color(0xFFCF6679);

  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldStart, goldEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient redGradient = LinearGradient(
    colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AddDailyQuizPage extends StatefulWidget {
  final String token;

  const AddDailyQuizPage({Key? key, required this.token}) : super(key: key);

  @override
  State<AddDailyQuizPage> createState() => _AddDailyQuizPageState();
}

class _AddDailyQuizPageState extends State<AddDailyQuizPage> {
  final String baseUrl = "https://skillsphere1-0-0.onrender.com";

  // Mode: add / remove
  String mode = "add";

  int selectedYear = 2;
  String quizType = "placement";
  String difficulty = "medium";

  DateTime selectedDate = DateTime.now();
  final TextEditingController topicController = TextEditingController();

  bool processing = false;

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
    }
  }

  // =========================
  // ADD QUIZ
  // =========================
  Future<void> addQuizTopic() async {
    if (topicController.text.trim().isEmpty) {
      showError("Quiz topic is required");
      return;
    }

    setState(() => processing = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/admin/daily-quiz/topic"),
        headers: {
          "Authorization": "Bearer ${widget.token}",
          "Content-Type": "application/json",
        },
        body: json.encode({
          "year": selectedYear,
          "quiz_date": selectedDate.toIso8601String().split("T")[0],
          "quiz_type": quizType,
          "topic": topicController.text.trim(),
          "difficulty": difficulty,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        showSuccess("Quiz topic added successfully");
        topicController.clear();
      } else {
        showError(data["error"] ?? "Failed to add quiz");
      }
    } catch (e) {
      showError(e.toString());
    }

    setState(() => processing = false);
  }

  // =========================
  // REMOVE QUIZ
  // =========================
  Future<void> removeQuizTopic() async {
    setState(() => processing = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/admin/daily-quiz/topic/delete"),
        headers: {
          "Authorization": "Bearer ${widget.token}",
          "Content-Type": "application/json",
        },
        body: json.encode({
          "year": selectedYear,
          "quiz_date": selectedDate.toIso8601String().split("T")[0],
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        showSuccess("Quiz topic removed successfully");
      } else {
        showError(data["error"] ?? "Failed to remove quiz");
      }
    } catch (e) {
      showError(e.toString());
    }

    setState(() => processing = false);
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
                  // Year Selector
                  _buildAurumDropdown<int>(
                    label: "Target Year",
                    value: selectedYear,
                    items: const [
                      DropdownMenuItem(value: 2, child: Text("Year 2")),
                      DropdownMenuItem(value: 3, child: Text("Year 3")),
                    ],
                    onChanged: (v) => setState(() => selectedYear = v!),
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
                    // Topic Field
                    _buildAurumTextField(
                      controller: topicController,
                      label: "Quiz Topic",
                      icon: Icons.topic_outlined,
                    ),
                    const SizedBox(height: 20),

                    // Quiz Type
                    _buildAurumDropdown<String>(
                      label: "Quiz Category",
                      value: quizType,
                      items: const [
                        DropdownMenuItem(
                            value: "placement", child: Text("Placement")),
                      ],
                      onChanged: (v) => setState(() => quizType = v!),
                    ),
                    const SizedBox(height: 20),

                    // Difficulty
                    _buildAurumDropdown<String>(
                      label: "Difficulty Level",
                      value: difficulty,
                      items: const [
                        DropdownMenuItem(value: "easy", child: Text("Easy")),
                        DropdownMenuItem(
                            value: "medium", child: Text("Medium")),
                        DropdownMenuItem(value: "hard", child: Text("Hard")),
                        DropdownMenuItem(
                            value: "very hard", child: Text("Expert")),
                      ],
                      onChanged: (v) => setState(() => difficulty = v!),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 40),

            // =========================
            // ACTION BUTTON
            // =========================
            InkWell(
              onTap: processing
                  ? null
                  : mode == "add"
                      ? addQuizTopic
                      : removeQuizTopic,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  gradient: mode == "remove"
                      ? AurumColors.redGradient
                      : AurumColors.goldGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (mode == "remove"
                              ? AurumColors.errorRed
                              : AurumColors.accentGold)
                          .withOpacity(0.3),
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
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            mode == "add" ? Icons.add_circle : Icons.delete,
                            color:
                                mode == "remove" ? Colors.white : Colors.black,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            mode == "add" ? "PUBLISH QUIZ" : "REMOVE QUIZ",
                            style: TextStyle(
                              color: mode == "remove"
                                  ? Colors.white
                                  : Colors.black,
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
      onTap: () => setState(() => mode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
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
          style: TextStyle(
            color: isSelected ? AurumColors.accentGold : AurumColors.textGrey,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // Custom Text Field
  Widget _buildAurumTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
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
}
