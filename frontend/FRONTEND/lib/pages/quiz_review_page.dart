import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class QuizReviewPage extends StatefulWidget {
  final String token;
  final int? quizId;
  final bool isFacultyQuiz;
  final String? quizTitle;

  const QuizReviewPage({
    Key? key,
    required this.token,
    this.quizId,
    this.isFacultyQuiz = false,
    this.quizTitle,
  }) : super(key: key);

  @override
  State<QuizReviewPage> createState() => _QuizReviewPageState();
}

class _QuizReviewPageState extends State<QuizReviewPage> {
  final String baseUrl = "https://skillsphere2-0.onrender.com";

  bool loading = true;
  List<Map<String, dynamic>> answers = [];
  int score = 0;
  int total = 0;
  bool answersHidden = false;
  String? unlockMessage;
  String quizName = "Quiz Results";
  String quizDate = "";
  String quizSubject = "General";
  String quizDepartment = "AI";
  String createdBy = "Admin";
  String startTime = "";
  String endTime = "";
  String? errorMsg;

  String formatCreator(String creator) {
    if (creator.trim().isEmpty) return "Admin";
    final lower = creator.trim().toLowerCase();
    if (lower.contains("admin") || lower == "system" || lower == "superadmin") {
      return "Admin";
    }
    return creator;
  }

  @override
  void initState() {
    super.initState();
    fetchReview();
  }

  Future<void> fetchReview() async {
    try {
      final dio = Dio();
      final String url;
      if (widget.isFacultyQuiz && widget.quizId != null) {
        url = "$baseUrl/api/faculty_quiz/review?quiz_id=${widget.quizId}";
      } else if (widget.quizId != null) {
        url = "$baseUrl/api/quiz/review?quiz_id=${widget.quizId}";
      } else {
        url = "$baseUrl/api/quiz/review";
      }

      final response = await dio.get(
        url,
        options: Options(
          headers: {
            "Authorization": "Bearer ${widget.token}",
          },
        ),
      );

      if (response.statusCode == 200 &&
          response.data != null &&
          response.data["success"] == true) {
        if (mounted) {
          setState(() {
            score = response.data["score"] ?? 0;
            total = response.data["total"] ?? 0;
            answersHidden = response.data["answers_hidden"] == true;
            unlockMessage = response.data["message"];
            quizName = response.data["quiz_name"] ?? widget.quizTitle ?? "Quiz Results";
            quizDate = response.data["quiz_date"] ?? "";
            quizSubject = response.data["subject"] ?? "General";
            quizDepartment = response.data["department"] ?? "AI";
            createdBy = formatCreator(response.data["created_by"] ?? "Admin");
            startTime = response.data["start_time"] ?? response.data["quiz_start_time"] ?? "";
            endTime = response.data["end_time"] ?? response.data["quiz_end_time"] ?? "";

            final List list = response.data["answers"] ?? [];
            answers = list.map((e) => Map<String, dynamic>.from(e)).toList();

            loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMsg = response.data?["message"] ?? "Failed to load quiz review";
            loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMsg = "Network error while loading review";
          loading = false;
        });
      }
    }
  }

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

  Future<void> generatePdf() async {
    try {
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
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "SKILL SPHERE - QUIZ REPORT",
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          widget.isFacultyQuiz ? "Faculty Quiz Evaluation" : "AI Daily Quiz Evaluation",
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "Date: ${safeStr(quizDate)}",
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.amber300,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (startTime.isNotEmpty || endTime.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          "Time: ${safeStr(startTime.isNotEmpty ? startTime : '--')} - ${safeStr(endTime.isNotEmpty ? endTime : '--')}",
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.amber100,
                          ),
                        ),
                      ],
                      pw.SizedBox(height: 2),
                      pw.Text(
                        "Organised by: ${safeStr(createdBy)}",
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.white,
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
                    "Skill Sphere Performance Metrics",
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
          build: (pw.Context context) {
            final double percentage = total == 0 ? 0 : (score / total) * 100;

            return [
              // ------------ SCORE METRICS BANNER ------------
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                margin: const pw.EdgeInsets.only(bottom: 16),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            safeStr(quizName),
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#0F172A'),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            "Department: ${safeStr(resolveDepartmentName(quizDepartment))}  |  Subject: ${safeStr(quizSubject)}",
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#2563EB'),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            "Total Questions: $total  |  Correct: $score  |  Accuracy: ${percentage.toStringAsFixed(0)}%",
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: score > (total / 2) ? PdfColor.fromHex('#DCFCE7') : PdfColor.fromHex('#FEE2E2'),
                        borderRadius: pw.BorderRadius.circular(20),
                        border: pw.Border.all(
                          color: score > (total / 2) ? PdfColor.fromHex('#86EFAC') : PdfColor.fromHex('#FCA5A5'),
                        ),
                      ),
                      child: pw.Text(
                        "SCORE: $score / $total",
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: score > (total / 2) ? PdfColor.fromHex('#166534') : PdfColor.fromHex('#991B1B'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (answersHidden)
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#FEF3C7'),
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColor.fromHex('#FDE68A')),
                  ),
                  child: pw.Text(
                    safeStr(unlockMessage ?? "Answers will be available after the quiz ends."),
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#92400E'),
                    ),
                  ),
                )
              else
                ...answers.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final q = entry.value;
                  final bool isCorr = q["is_correct"] == true;

                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 10),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(
                        color: isCorr ? PdfColor.fromHex('#BBF7D0') : PdfColor.fromHex('#FECACA'),
                        width: 1,
                      ),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(
                              child: pw.Text(
                                "Q$idx. ${safeStr(q['question'])}",
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#1E293B'),
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 8),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: isCorr ? PdfColor.fromHex('#DCFCE7') : PdfColor.fromHex('#FEE2E2'),
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(
                                isCorr ? "CORRECT (+1)" : "INCORRECT (0)",
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: isCorr ? PdfColor.fromHex('#166534') : PdfColor.fromHex('#991B1B'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Divider(color: PdfColor.fromHex('#F1F5F9'), thickness: 0.5),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              "Your Answer: ",
                              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                            ),
                            pw.Expanded(
                              child: pw.Text(
                                safeStr(q["your_answer"] ?? "Skipped"),
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: isCorr ? PdfColor.fromHex('#166534') : PdfColor.fromHex('#991B1B'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!isCorr) ...[
                          pw.SizedBox(height: 3),
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                "Correct Answer: ",
                                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                              ),
                              pw.Expanded(
                                child: pw.Text(
                                  safeStr(q["correct_answer"] ?? "N/A"),
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColor.fromHex('#166534'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
            ];
          },
        ),
      );

      final bytes = await doc.save();
      final filename = "Quiz_Report_${widget.quizId ?? 'review'}.pdf";

      try {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      } catch (_) {
        await Printing.layoutPdf(
          onLayout: (format) async => bytes,
          name: filename,
        );
      }
    } catch (e, stack) {
      debugPrint("PDF GENERATION ERROR: $e\n$stack");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not generate the PDF. Please try again."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color bgDark = Color(0xFF121212);
    const Color cardColor = Color(0xFF1E1E1E);
    const Color correctColor = Colors.greenAccent;
    const Color wrongColor = Colors.redAccent;
    const Color goldColor = Color(0xFFFFD700);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        title: Text(
          quizName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!loading && errorMsg == null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: goldColor),
              tooltip: "Download PDF",
              onPressed: generatePdf,
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: goldColor))
          : errorMsg != null
              ? Center(
                  child: Text(errorMsg!,
                      style: const TextStyle(color: Colors.redAccent)),
                )
              : Column(
                  children: [
                    // ---------------- SCORE HEADER ----------------
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: cardColor,
                        border: Border(
                          bottom: BorderSide(color: Colors.white10),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "YOUR SCORE",
                            style: TextStyle(
                              color: Colors.white54,
                              letterSpacing: 1.5,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "$score / $total",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: total == 0 ? 0 : score / total,
                            backgroundColor: Colors.white10,
                            color: score > (total / 2) ? correctColor : wrongColor,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (quizDate.isNotEmpty)
                                Text("Date: $quizDate",
                                    style: const TextStyle(color: Colors.white60, fontSize: 11)),
                              if (startTime.isNotEmpty || endTime.isNotEmpty) ...[
                                if (quizDate.isNotEmpty)
                                  const Text("•", style: TextStyle(color: Colors.white38, fontSize: 11)),
                                Text("Time: ${startTime.isNotEmpty ? startTime : '--'} - ${endTime.isNotEmpty ? endTime : '--'}",
                                    style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w500)),
                              ],
                              const Text("•", style: TextStyle(color: Colors.white38, fontSize: 11)),
                              Text("Department: ${resolveDepartmentName(quizDepartment)}",
                                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                              const Text("•", style: TextStyle(color: Colors.white38, fontSize: 11)),
                              Text("Subject: $quizSubject",
                                  style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                              const Text("•", style: TextStyle(color: Colors.white38, fontSize: 11)),
                              Text("Organised by: $createdBy",
                                  style: const TextStyle(color: goldColor, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ---------------- ANSWERS LOCKED BANNER ----------------
                    if (answersHidden)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2200),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: goldColor.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_clock, color: goldColor, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Answers Locked",
                                    style: TextStyle(
                                      color: goldColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    unlockMessage ?? "Faculty Quiz answers will be available after the quiz ends.",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ---------------- QUESTIONS LIST ----------------
                    if (!answersHidden)
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: answers.length,
                          itemBuilder: (context, index) {
                            final q = answers[index];
                            final bool isCorrect = q["is_correct"] == true;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCorrect
                                      ? correctColor.withOpacity(0.3)
                                      : wrongColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Question Text
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Q${index + 1}.",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          q["question"] ?? "No Question",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),
                                  const Divider(color: Colors.white10),
                                  const SizedBox(height: 8),

                                  // User Answer
                                  Row(
                                    children: [
                                      Icon(
                                        isCorrect
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color: isCorrect ? correctColor : wrongColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text("Your Answer: ",
                                          style: TextStyle(color: Colors.white54)),
                                      Expanded(
                                        child: Text(
                                          q["your_answer"] ?? "Skipped",
                                          style: TextStyle(
                                            color: isCorrect ? correctColor : wrongColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Correct Answer (Only show if wrong)
                                  if (!isCorrect) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.check_circle_outline,
                                            color: Colors.white54, size: 20),
                                        const SizedBox(width: 8),
                                        const Text("Correct Answer: ",
                                            style: TextStyle(color: Colors.white54)),
                                        Expanded(
                                          child: Text(
                                            q["correct_answer"] ?? "N/A",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ]
                                ],
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
