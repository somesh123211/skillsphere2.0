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

class DailyQuizFullClassPage extends StatefulWidget {
  final String token;

  const DailyQuizFullClassPage({
    Key? key,
    required this.token,
  }) : super(key: key);

  @override
  State<DailyQuizFullClassPage> createState() => _DailyQuizFullClassPageState();
}

class _DailyQuizFullClassPageState extends State<DailyQuizFullClassPage> {
  // ================= CONFIG =================
  final String baseUrl = "https://skillsphere1-0-0.onrender.com";

  // ================= STATE =================
  int selectedYear = 2;
  DateTime? selectedDate;

  bool loading = false;
  bool searched = false;

  String topic = "";
  String difficulty = "";
  int totalMarks = 0;

  List<Map<String, dynamic>> students = [];

  // ================= DATE PICKER =================
  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDate: DateTime.now(),
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

  // ================= FETCH DATA =================
  Future<void> fetchData() async {
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a date first"),
          backgroundColor: AurumColors.errorRed,
        ),
      );
      return;
    }

    setState(() {
      loading = true;
      searched = true;
      students.clear();
    });

    final dateStr =
        "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";

    final uri = Uri.parse(
      "$baseUrl/api/admin/daily-quiz/full-class"
      "?year=$selectedYear&date=$dateStr",
    );

    try {
      final res = await http.get(
        uri,
        headers: {
          "Authorization": "Bearer ${widget.token}",
        },
      );

      final decoded = jsonDecode(res.body);

      if (decoded["success"] == true) {
        setState(() {
          topic = decoded["quiz"]["topic"];
          difficulty = decoded["quiz"]["difficulty"];
          totalMarks = decoded["quiz"]["total_marks"];
          students = List<Map<String, dynamic>>.from(decoded["students"]);
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
            content: Text("Error: $e"),
            backgroundColor: AurumColors.errorRed,
          ),
        );
      }
    }
  }

  // ================= PDF (WITH DOWNLOADED TIME) =================
  Future<void> generatePdf() async {
    final pdf = pw.Document();

    final quizDateStr =
        "${selectedDate!.day}-${selectedDate!.month}-${selectedDate!.year}";

    final now = DateTime.now();
    final downloadedTime = "${now.day.toString().padLeft(2, '0')}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.year}  "
        "${now.hour.toString().padLeft(2, '0')}:"
        "${now.minute.toString().padLeft(2, '0')}";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Daily Quiz – Full Class Report",
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

              pw.SizedBox(height: 10),

              pw.Text("Date      : $quizDateStr"),
              pw.Text("Year      : $selectedYear"),
              pw.Text("Topic     : $topic"),
              pw.Text("Difficulty: $difficulty"),

              pw.SizedBox(height: 20),

              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          "Name",
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          "UID",
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
                  ...students.map((s) {
                    final bool attempted = s["attempted"] == 1;

                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(s["name"]),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(s["uid"].toString()),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            attempted
                                ? "${s['marks']}/$totalMarks"
                                : "Not Given",
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
    );
  }

  // ================= UI BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      appBar: AppBar(
        title: const Text("Class Performance"),
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
          if (!loading && students.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_rounded,
                  color: AurumColors.accentGold),
              onPressed: generatePdf,
              tooltip: "Download PDF",
            )
        ],
      ),
      body: Column(
        children: [
          // =========================
          // FILTER CONTROLS
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
                          child: DropdownButton<int>(
                            value: selectedYear,
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
                            onChanged: (v) => setState(() => selectedYear = v!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Date Picker Button
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AurumColors.backgroundBlack,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 16,
                                  color: selectedDate == null
                                      ? AurumColors.textGrey
                                      : AurumColors.accentGold),
                              const SizedBox(width: 8),
                              Text(
                                selectedDate == null
                                    ? "Select Date"
                                    : "${selectedDate!.day}-${selectedDate!.month}-${selectedDate!.year}",
                                style: TextStyle(
                                  color: selectedDate == null
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
                  ],
                ),
                const SizedBox(height: 16),
                // Search Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : fetchData,
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
                            "FETCH REPORT",
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
                : (!searched && students.isEmpty)
                    ? _buildPlaceholder("Select options to view report")
                    : (students.isEmpty)
                        ? _buildPlaceholder("No records found for this date")
                        : Column(
                            children: [
                              // Quiz Info Header
                              Container(
                                width: double.infinity,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color:
                                      AurumColors.accentGold.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AurumColors.accentGold
                                          .withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "TOPIC",
                                          style: TextStyle(
                                              color: AurumColors.accentGold,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          topic.isEmpty ? "N/A" : topic,
                                          style: const TextStyle(
                                              color: AurumColors.textWhite,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "DIFFICULTY",
                                          style: TextStyle(
                                              color: AurumColors.accentGold,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          difficulty.isEmpty
                                              ? "N/A"
                                              : difficulty.toUpperCase(),
                                          style: const TextStyle(
                                              color: AurumColors.textWhite,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // List Header
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 8),
                                child: Row(
                                  children: const [
                                    Expanded(
                                        child: Text("STUDENT",
                                            style: TextStyle(
                                                color: AurumColors.textGrey,
                                                fontSize: 10))),
                                    Text("STATUS / SCORE",
                                        style: TextStyle(
                                            color: AurumColors.textGrey,
                                            fontSize: 10)),
                                  ],
                                ),
                              ),

                              // Students List
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: students.length,
                                  itemBuilder: (_, i) {
                                    final s = students[i];
                                    final bool attempted = s["attempted"] == 1;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: AurumColors.cardSurface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: attempted
                                                ? AurumColors.successGreen
                                                    .withOpacity(0.3)
                                                : AurumColors.errorRed
                                                    .withOpacity(0.3),
                                            width: 1),
                                      ),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 4),
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              AurumColors.backgroundBlack,
                                          child: Text(
                                            s["name"]
                                                .substring(0, 1)
                                                .toUpperCase(),
                                            style: TextStyle(
                                              color: attempted
                                                  ? AurumColors.successGreen
                                                  : AurumColors.errorRed,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          s["name"],
                                          style: const TextStyle(
                                            color: AurumColors.textWhite,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          "UID: ${s['uid']}",
                                          style: const TextStyle(
                                              color: AurumColors.textGrey,
                                              fontSize: 12),
                                        ),
                                        trailing: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: attempted
                                                ? AurumColors.successGreen
                                                    .withOpacity(0.1)
                                                : AurumColors.errorRed
                                                    .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            attempted
                                                ? "${s['marks']} / $totalMarks"
                                                : "Absent",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: attempted
                                                  ? AurumColors.successGreen
                                                  : AurumColors.errorRed,
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
          Icon(Icons.analytics_outlined,
              size: 60, color: AurumColors.surfaceDark),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AurumColors.textGrey)),
        ],
      ),
    );
  }
}
