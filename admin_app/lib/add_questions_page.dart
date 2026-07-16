import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

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

class AddQuestionsPage extends StatefulWidget {
  final String token;

  const AddQuestionsPage({
    Key? key,
    required this.token,
  }) : super(key: key);

  @override
  State<AddQuestionsPage> createState() => _AddQuestionsPageState();
}

class _AddQuestionsPageState extends State<AddQuestionsPage> {
  final String baseUrl = "https://skillsphere1-0-0.onrender.com";

  // QUIZ STATE
  List quizzes = [];
  int? selectedQuizId;
  final TextEditingController searchController = TextEditingController();

  // CSV STATE
  Uint8List? csvBytes;
  String? csvFileName;
  bool csvValid = false;
  bool loading = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // =========================
  // SEARCH QUIZ
  // =========================
  Future<void> searchQuiz() async {
    final quizIdText = searchController.text.trim();

    if (quizIdText.isEmpty) {
      showError("Enter a Quiz ID to search");
      return;
    }

    setState(() {
      loading = true;
      quizzes = [];
      selectedQuizId = null;
    });

    try {
      final res = await http.get(
        Uri.parse("$baseUrl/api/admin/faculty-quiz/search?quiz_id=$quizIdText"),
        headers: {
          "Authorization": "Bearer ${widget.token}",
        },
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          quizzes = data["quizzes"] ?? [];
        });
        if (quizzes.isEmpty) {
          showError("No quizzes found with ID $quizIdText");
        }
      } else {
        showError("Search failed");
      }
    } catch (e) {
      showError("Connection error");
    }

    setState(() => loading = false);
  }

  // =========================
  // PICK CSV
  // =========================
  Future<void> pickCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["csv"],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;

    setState(() {
      csvFileName = file.name;
      csvBytes = file.bytes;
      csvValid = false; // Reset validation on new pick
    });
  }

  // =========================
  // CHECK CSV (CLIENT SIDE VALIDATION)
  // =========================
  Future<void> checkCsv() async {
    if (csvFileName == null || csvBytes == null) {
      showError("Select a CSV file first");
      return;
    }

    setState(() => loading = true);

    // 1. Client Side Column Check
    try {
      // Decode bytes to string
      String content = utf8.decode(csvBytes!);

      // Split into lines
      List<String> lines = const LineSplitter().convert(content);

      if (lines.isEmpty) {
        setState(() => loading = false);
        showError("CSV file is empty");
        return;
      }

      // Get Headers from first line
      // Splitting by comma, trimming whitespace
      List<String> headers = lines[0].split(',').map((e) => e.trim()).toList();

      // Required Columns
      List<String> requiredColumns = [
        'question',
        'option_a',
        'option_b',
        'option_c',
        'option_d',
        'correct_option'
      ];

      // Verify Headers
      bool headersValid = true;
      for (var col in requiredColumns) {
        if (!headers.contains(col)) {
          headersValid = false;
          break;
        }
      }

      if (!headersValid) {
        setState(() {
          loading = false;
          csvValid = false;
        });
        showError(
            "Invalid Columns! File must contain:\n${requiredColumns.join(', ')}");
        return;
      }

      // If headers match, we can proceed to server check if needed, or just mark valid.
      // For now, let's mark it valid as per request logic.
      setState(() {
        csvValid = true;
        loading = false;
      });
      showSuccess("CSV Validated Successfully!");
    } catch (e) {
      setState(() {
        loading = false;
        csvValid = false;
      });
      showError("Error reading CSV file: $e");
    }
  }

  // =========================
  // UPLOAD QUESTIONS
  // =========================
  Future<void> uploadQuestions() async {
    if (selectedQuizId == null) {
      showError("Please select a quiz first");
      return;
    }
    if (!csvValid) {
      showError("Please validate the CSV file first");
      return;
    }

    setState(() => loading = true);

    try {
      final request = http.MultipartRequest(
        "POST",
        Uri.parse("$baseUrl/api/admin/faculty-quiz/questions/upload"),
      );

      request.headers["Authorization"] = "Bearer ${widget.token}";
      request.fields["quiz_id"] = selectedQuizId.toString();
      request.files.add(
        http.MultipartFile.fromBytes(
          "file",
          csvBytes!,
          filename: csvFileName!,
        ),
      );

      final res = await request.send();
      final body = await res.stream.bytesToString();
      final data = json.decode(body);

      if (res.statusCode == 201) {
        showSuccess(data["message"] ?? "Questions uploaded successfully");
        setState(() {
          csvBytes = null;
          csvFileName = null;
          csvValid = false;
          searchController.clear();
          quizzes = [];
          selectedQuizId = null;
        });
        if (mounted) Navigator.pop(context);
      } else {
        showError(data["error"] ?? "Upload failed");
      }
    } catch (e) {
      showError("Upload error: $e");
    }

    setState(() => loading = false);
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

  void showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: AurumColors.successGreen,
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
        title: const Text("Import Questions"),
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
            // =========================
            // STEP 1: FIND QUIZ
            // =========================
            _buildSectionHeader("Step 1", "Select Target Quiz"),
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
                  TextField(
                    controller: searchController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AurumColors.textWhite),
                    cursorColor: AurumColors.accentGold,
                    decoration: InputDecoration(
                      labelText: "Search by Quiz ID",
                      labelStyle: const TextStyle(color: AurumColors.textGrey),
                      hintText: "e.g. 101",
                      hintStyle: TextStyle(color: Colors.grey.shade800),
                      prefixIcon: const Icon(Icons.search,
                          color: AurumColors.accentGold),
                      filled: true,
                      fillColor: AurumColors.backgroundBlack,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward,
                            color: AurumColors.accentGold),
                        onPressed: searchQuiz,
                      ),
                    ),
                    onSubmitted: (_) => searchQuiz(),
                  ),
                  if (quizzes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AurumColors.backgroundBlack,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AurumColors.accentGold.withOpacity(0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedQuizId,
                          hint: const Text("Select Found Quiz",
                              style: TextStyle(color: AurumColors.textGrey)),
                          isExpanded: true,
                          dropdownColor: AurumColors.surfaceDark,
                          icon: const Icon(Icons.arrow_drop_down,
                              color: AurumColors.accentGold),
                          style: const TextStyle(color: AurumColors.textWhite),
                          items: quizzes.map<DropdownMenuItem<int>>((q) {
                            return DropdownMenuItem(
                              value: q["quiz_id"],
                              child: Text(
                                "ID: ${q["quiz_id"]} | ${q["topic"]} (Y${q["year"]})",
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => selectedQuizId = v),
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),

            const SizedBox(height: 32),

            // =========================
            // STEP 2: UPLOAD & CHECK CSV
            // =========================
            _buildSectionHeader("Step 2", "Upload CSV File"),
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
                  // File Picker Area
                  InkWell(
                    onTap: pickCsv,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: csvFileName == null
                                ? AurumColors.textGrey.withOpacity(0.3)
                                : (csvValid
                                    ? AurumColors.successGreen
                                    : AurumColors.accentGold),
                            width: 2,
                            style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(16),
                        color: csvFileName == null
                            ? Colors.transparent
                            : AurumColors.accentGold.withOpacity(0.1),
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
                                : (csvValid
                                    ? AurumColors.successGreen
                                    : AurumColors.accentGold),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            csvFileName ?? "Tap to Select CSV File",
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

                  // CHECK CSV BUTTON
                  if (csvFileName != null) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: csvValid
                            ? null
                            : checkCsv, // Disable if already valid
                        icon: Icon(
                          csvValid ? Icons.check_circle : Icons.fact_check,
                          color: csvValid
                              ? AurumColors.successGreen
                              : AurumColors.accentGold,
                        ),
                        label: Text(
                          csvValid
                              ? "CSV Format Validated"
                              : "Check CSV Columns",
                          style: TextStyle(
                            color: csvValid
                                ? AurumColors.successGreen
                                : AurumColors.accentGold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                              color: csvValid
                                  ? AurumColors.successGreen
                                  : AurumColors.accentGold),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 40),

            // =========================
            // FINAL ACTION: UPLOAD
            // =========================
            InkWell(
              // Disable Upload if not selected, or CSV not valid
              onTap: (loading || selectedQuizId == null || !csvValid)
                  ? null
                  : uploadQuestions,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  gradient: (selectedQuizId != null && csvValid)
                      ? AurumColors.goldGradient
                      : null,
                  color: (selectedQuizId != null && csvValid)
                      ? null
                      : AurumColors.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: (selectedQuizId != null && csvValid)
                      ? [
                          BoxShadow(
                            color: AurumColors.accentGold.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: loading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        "UPLOAD QUESTIONS",
                        style: TextStyle(
                          color: (selectedQuizId != null && csvValid)
                              ? Colors.black
                              : AurumColors.textGrey,
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
}
