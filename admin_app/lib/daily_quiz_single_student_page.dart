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

class DailyQuizSingleStudentPage extends StatefulWidget {
  final AdminSession session;

  const DailyQuizSingleStudentPage({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  State<DailyQuizSingleStudentPage> createState() =>
      _DailyQuizSingleStudentPageState();
}

class _DailyQuizSingleStudentPageState
    extends State<DailyQuizSingleStudentPage> {
  // =================================================
  // BASE URL
  // =================================================
  final String baseUrl = "https://skillsphere2-0.onrender.com";

  // =================================================
  // STATE
  // =================================================
  String selectedYear = "2";
  final TextEditingController uidController = TextEditingController();

  bool searched = false;
  bool loading = false;

  List<Map<String, dynamic>> marks = [];

  // Student info
  String studentName = "";
  String studentEmail = "";

  @override
  void dispose() {
    uidController.dispose();
    super.dispose();
  }

  // =================================================
  // DATE FORMAT
  // =================================================
  String formatDate(String rawDate) {
    try {
      final d = DateTime.parse(rawDate);
      return "${d.day.toString().padLeft(2, '0')}-"
          "${d.month.toString().padLeft(2, '0')}-"
          "${d.year}";
    } catch (_) {
      return rawDate.split(" ")[0];
    }
  }

  // =================================================
  // API CALL
  // =================================================
  Future<void> fetchMarks() async {
    final uid = uidController.text.trim();

    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter UID"),
          backgroundColor: AurumColors.errorRed,
        ),
      );
      return;
    }

    setState(() {
      searched = true;
      loading = true;
      marks.clear();
      studentName = "";
      studentEmail = "";
    });

    final uri = Uri.parse(
      "$baseUrl/api/admin/daily-quiz/single-student?uid=$uid",
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          "Authorization": "Bearer ${widget.session.token}",
        },
      );

      final decoded = jsonDecode(response.body);

      if (decoded["success"] == true) {
        final now = DateTime.now();

        // STUDENT INFO
        studentName = decoded["student"]?["name"] ?? "";
        studentEmail = decoded["student"]?["email"] ?? "";

        // LAST 30 DAYS FILTER
        marks = List<Map<String, dynamic>>.from(decoded["data"]).where((item) {
          final d = DateTime.parse(item["quiz_date"]);
          return now.difference(d).inDays <= 30;
        }).toList();

        setState(() {
          loading = false;
        });
      } else {
        setState(() => loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(decoded["message"]),
              backgroundColor: AurumColors.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Single-student quiz lookup error: $e");
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Unable to connect to the server. Please try again."),
            backgroundColor: AurumColors.errorRed,
          ),
        );
      }
    }
  }

  // =================================================
  // PDF GENERATION
  // =================================================
  Future<void> generatePdf() async {
    final pdf = pw.Document();

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
                      "SKILL SPHERE - AI DAILY QUIZ REPORT",
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      "Single Student Performance Analysis",
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
        build: (pw.Context context) {
          return [
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
                      pw.Text(
                        "Student Name: ${safeStr(studentName)}",
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text("Email: ${safeStr(studentEmail)}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(height: 3),
                      pw.Text("UID: ${safeStr(uidController.text)}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#DCFCE7'),
                      borderRadius: pw.BorderRadius.circular(12),
                      border: pw.Border.all(color: PdfColor.fromHex('#86EFAC')),
                    ),
                    child: pw.Text(
                      "Quizzes Attempted: ${marks.length}",
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#166534')),
                    ),
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
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: const ["Quiz Date", "Score Obtained"],
              data: marks.map((m) {
                return [
                  safeStr(formatDate(m["quiz_date"])),
                  "${m['score']} / ${m['total']}",
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

  // =================================================
  // UI BUILD
  // =================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      appBar: AppBar(
        title: const Text("Student Performance"),
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
          if (!loading && marks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_rounded,
                  color: AurumColors.accentGold),
              onPressed: generatePdf,
              tooltip: "Download Report",
            )
        ],
      ),
      body: Column(
        children: [
          // =========================
          // SEARCH CONTROL CARD
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
                TextField(
                  controller: uidController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AurumColors.textWhite),
                  cursorColor: AurumColors.accentGold,
                  decoration: InputDecoration(
                    hintText: "Enter Student UID (e.g. 2400212)",
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
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "SEARCH RECORDS",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),

          // =========================
          // REPORT CONTENT
          // =========================
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AurumColors.accentGold))
                : (searched && marks.isEmpty)
                    ? _buildPlaceholder("No records found for the last 30 days")
                    : (!searched)
                        ? _buildPlaceholder(
                            "Enter details to view student report")
                        : Column(
                            children: [
                              // Student Profile Header
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
                                      color: AurumColors.accentGold
                                          .withOpacity(0.2),
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: marks.length,
                                  itemBuilder: (context, index) {
                                    final m = marks[index];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: AurumColors.cardSurface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.05)),
                                      ),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 4),
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AurumColors.accentGold
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                              Icons.calendar_month,
                                              color: AurumColors.accentGold,
                                              size: 20),
                                        ),
                                        title: Text(
                                          formatDate(m['quiz_date']),
                                          style: const TextStyle(
                                            color: AurumColors.textWhite,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        trailing: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AurumColors.backgroundBlack,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: AurumColors.accentGold
                                                    .withOpacity(0.3)),
                                          ),
                                          child: RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: "${m['score']}",
                                                  style: const TextStyle(
                                                    color:
                                                        AurumColors.accentGold,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: " / ${m['total']}",
                                                  style: const TextStyle(
                                                    color: AurumColors.textGrey,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
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
