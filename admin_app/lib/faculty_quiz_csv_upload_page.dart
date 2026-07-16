import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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

class FacultyQuizCsvUploadPage extends StatefulWidget {
  final String token;

  const FacultyQuizCsvUploadPage({
    Key? key,
    required this.token,
  }) : super(key: key);

  @override
  State<FacultyQuizCsvUploadPage> createState() =>
      _FacultyQuizCsvUploadPageState();
}

class _FacultyQuizCsvUploadPageState extends State<FacultyQuizCsvUploadPage> {
  final String baseUrl = "https://skillsphere1-0-0.onrender.com";

  List quizzes = [];
  int? selectedQuizId;

  File? selectedFile;
  bool loadingQuizzes = true;
  bool uploading = false;

  @override
  void initState() {
    super.initState();
    fetchQuizzes();
  }

  // =========================
  // FETCH QUIZ MASTER LIST
  // =========================
  Future<void> fetchQuizzes() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/admin/faculty-quiz/master"),
        headers: {
          "Authorization": "Bearer ${widget.token}",
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        if (mounted) {
          setState(() {
            quizzes = data["quizzes"];
          });
        }
      } else {
        if (mounted) showError("Failed to load quizzes");
      }
    } catch (e) {
      if (mounted) showError(e.toString());
    }

    if (mounted) setState(() => loadingQuizzes = false);
  }

  // =========================
  // PICK CSV FILE
  // =========================
  Future<void> pickCsvFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["csv"],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        selectedFile = File(result.files.single.path!);
      });
    }
  }

  // =========================
  // UPLOAD CSV
  // =========================
  Future<void> uploadCsv() async {
    if (selectedQuizId == null) {
      showError("Please select a quiz first");
      return;
    }

    if (selectedFile == null) {
      showError("Please select a CSV file");
      return;
    }

    setState(() => uploading = true);

    try {
      final request = http.MultipartRequest(
        "POST",
        Uri.parse(
          "$baseUrl/api/admin/faculty-quiz/questions/upload",
        ),
      );

      request.headers["Authorization"] = "Bearer ${widget.token}";

      request.fields["quiz_id"] = selectedQuizId.toString();

      request.files.add(
        await http.MultipartFile.fromPath(
          "file",
          selectedFile!.path,
        ),
      );

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      final data = json.decode(responseBody);

      if (streamedResponse.statusCode == 201) {
        showSuccess(data["message"] ?? "Upload successful");
        setState(() {
          selectedFile = null;
        });
      } else {
        showError(data["error"] ?? "Upload failed");
      }
    } catch (e) {
      showError(e.toString());
    }

    setState(() => uploading = false);
  }

  // =========================
  // SNACKBARS
  // =========================
  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: AurumColors.errorRed,
      ),
    );
  }

  void showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: AurumColors.successGreen,
      ),
    );
  }

  // =========================
  // UI BUILDER
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      appBar: AppBar(
        title: const Text("Upload Questions"),
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
      body: loadingQuizzes
          ? const Center(
              child: CircularProgressIndicator(color: AurumColors.accentGold))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildSectionHeader("Step 1", "Select Target Quiz"),
                  const SizedBox(height: 16),

                  // Quiz Selection Card
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AurumColors.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedQuizId,
                        hint: const Text(
                          "Select Quiz",
                          style: TextStyle(color: AurumColors.textGrey),
                        ),
                        dropdownColor: AurumColors.surfaceDark,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: AurumColors.accentGold),
                        style: const TextStyle(color: AurumColors.textWhite),
                        isExpanded: true,
                        items: quizzes.map<DropdownMenuItem<int>>((q) {
                          return DropdownMenuItem<int>(
                            value: q["quiz_id"],
                            child: Text(
                              "Quiz ${q["quiz_id"]} | Year ${q["year"]} | ${q["quiz_date"]}",
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedQuizId = value;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // CSV Selection Header
                  _buildSectionHeader("Step 2", "Upload CSV File"),
                  const SizedBox(height: 16),

                  // CSV Selection Area
                  InkWell(
                    onTap: pickCsvFile,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedFile == null
                              ? AurumColors.textGrey.withOpacity(0.3)
                              : AurumColors.successGreen,
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        color: selectedFile == null
                            ? Colors.transparent
                            : AurumColors.accentGold.withOpacity(0.1),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            selectedFile == null
                                ? Icons.upload_file
                                : Icons.description,
                            size: 40,
                            color: selectedFile == null
                                ? AurumColors.textGrey
                                : AurumColors.successGreen,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            selectedFile == null
                                ? "Tap to Select CSV File"
                                : selectedFile!.path.split('/').last,
                            style: TextStyle(
                              color: selectedFile == null
                                  ? AurumColors.textGrey
                                  : AurumColors.textWhite,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Upload Button
                  InkWell(
                    onTap: uploading ? null : uploadCsv,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        gradient:
                            (selectedQuizId != null && selectedFile != null)
                                ? AurumColors.goldGradient
                                : null,
                        color: (selectedQuizId != null && selectedFile != null)
                            ? null
                            : AurumColors.surfaceDark,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: (selectedQuizId != null &&
                                selectedFile != null)
                            ? [
                                BoxShadow(
                                  color:
                                      AurumColors.accentGold.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: uploading
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
                                color: (selectedQuizId != null &&
                                        selectedFile != null)
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

  // Helper Widget for Section Headers
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
