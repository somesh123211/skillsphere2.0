import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  final String token;

  const FacultyStudentQuizMarksPage({
    Key? key,
    required this.token,
  }) : super(key: key);

  @override
  State<FacultyStudentQuizMarksPage> createState() =>
      _FacultyStudentQuizMarksPageState();
}

class _FacultyStudentQuizMarksPageState
    extends State<FacultyStudentQuizMarksPage> {
  final String baseUrl = "https://skillsphere1-0-0.onrender.com";

  final TextEditingController uidCtrl = TextEditingController();
  int year = 2;

  bool loading = false;
  List<dynamic> data = [];

  String studentName = "NOT GIVEN";
  String studentEmail = "NOT GIVEN";

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
          "$baseUrl/api/faculty/student/quiz-marks?uid=$uidText&year=$year",
        ),
        headers: {
          "Authorization": "Bearer ${widget.token}",
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

  // =========================
  // GENERATE PDF
  // =========================
  Future<void> generatePdf() async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            "Student Quiz Marks Report",
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            "Downloaded on: ${downloadedTimestamp()}",
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text("Student Name : $studentName"),
          pw.Text("Email        : $studentEmail"),
          pw.Text("UID          : ${uidCtrl.text}"),
          pw.Text("Year         : ${year == 2 ? "Second Year" : "Third Year"}"),
          pw.SizedBox(height: 15),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: const [
              "Quiz ID",
              "Date",
              "Time Slot",
              "Marks",
              "Created By",
            ],
            data: data.map((q) {
              final isNotGiven = q["marks"] == "NOT GIVEN";
              return [
                q["quiz_id"].toString(),
                formatDate(q["quiz_date"]),
                formatTime(q["start_time"], q["end_time"]),
                isNotGiven
                    ? "NOT GIVEN"
                    : "${q["marks"]} / ${q["total_marks"]}",
                hasValue(q["created_by"]) ? q["created_by"] : "NOT GIVEN",
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
                Row(
                  children: [
                    // UID Input
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: uidCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AurumColors.textWhite),
                        cursorColor: AurumColors.accentGold,
                        decoration: InputDecoration(
                          hintText: "Enter UID",
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
                              DropdownMenuItem(value: 2, child: Text("Year 2")),
                              DropdownMenuItem(value: 3, child: Text("Year 3")),
                            ],
                            onChanged: (v) => setState(() => year = v!),
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
                                      ],
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isNotGiven
                                            ? AurumColors.errorRed
                                                .withOpacity(0.1)
                                            : AurumColors.successGreen
                                                .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
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
