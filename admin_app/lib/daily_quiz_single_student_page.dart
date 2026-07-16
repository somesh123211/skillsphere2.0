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

class DailyQuizSingleStudentPage extends StatefulWidget {
  final String token;

  const DailyQuizSingleStudentPage({
    Key? key,
    required this.token,
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
  final String baseUrl = "https://skillsphere1-0-0.onrender.com";

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
      "$baseUrl/api/admin/daily-quiz/single-student"
      "?uid=$uid&year=$selectedYear",
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          "Authorization": "Bearer ${widget.token}",
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
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Network error: $e"),
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

    final now = DateTime.now();
    final downloadedTime = "${now.day.toString().padLeft(2, '0')}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.year}  "
        "${now.hour.toString().padLeft(2, '0')}:"
        "${now.minute.toString().padLeft(2, '0')}";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Daily Quiz Marks Report",
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 6),

              // DOWNLOADED TIME
              pw.Text(
                "Downloaded on: $downloadedTime",
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),

              pw.SizedBox(height: 12),

              pw.Text("Name : $studentName"),
              pw.Text("Email: $studentEmail"),
              pw.Text("UID   : ${uidController.text}"),
              pw.Text("Year  : $selectedYear"),

              pw.SizedBox(height: 20),

              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  // HEADER
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          "Date",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          "Marks",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // DATA
                  ...marks.map(
                    (m) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            formatDate(m["quiz_date"]),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            "${m['score']}/${m['total']}",
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
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
                Row(
                  children: [
                    // Year Selector
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
                          child: DropdownButton<String>(
                            value: selectedYear,
                            dropdownColor: AurumColors.surfaceDark,
                            icon: const Icon(Icons.arrow_drop_down,
                                color: AurumColors.accentGold),
                            style: const TextStyle(
                                color: AurumColors.textWhite,
                                fontWeight: FontWeight.bold),
                            items: const [
                              DropdownMenuItem(
                                  value: "2", child: Text("Year 2")),
                              DropdownMenuItem(
                                  value: "3", child: Text("Year 3")),
                            ],
                            onChanged: (v) => setState(() => selectedYear = v!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // UID Input
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: uidController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AurumColors.textWhite),
                        cursorColor: AurumColors.accentGold,
                        decoration: InputDecoration(
                          hintText: "Enter Student UID",
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
