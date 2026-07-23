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

  // Rank Colors
  static const Color rankGold = Color(0xFFFFD700);
  static const Color rankSilver = Color(0xFFC0C0C0);
  static const Color rankBronze = Color(0xFFCD7F32);

  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldStart, goldEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AdminLeaderboardPage extends StatefulWidget {
  final AdminSession session;

  const AdminLeaderboardPage({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  State<AdminLeaderboardPage> createState() => _AdminLeaderboardPageState();
}

class _AdminLeaderboardPageState extends State<AdminLeaderboardPage> {
  final String baseUrl = "https://skillsphere-2-qanz.onrender.com";

  int year = 2;
  String type = "all"; // all | month
  String month = "01";

  bool loading = false;
  List leaderboard = [];

  // Department filter — only super_admin/admin get a free choice; hod/
  // faculty are already forced to their own department server-side.
  bool get showDeptFilter => widget.session.isSuperAdmin;
  List<Map<String, dynamic>> departments = [];
  int? selectedDeptId;
  bool loadingDepts = false;

  @override
  void initState() {
    super.initState();
    if (showDeptFilter) {
      fetchDepartments();
    }
  }

  Future<void> fetchDepartments() async {
    setState(() => loadingDepts = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/admin/departments"),
        headers: {"Authorization": "Bearer ${widget.session.token}"},
      );
      final data = jsonDecode(response.body);
      if (data["success"] == true) {
        setState(() {
          departments = List<Map<String, dynamic>>.from(data["departments"]);
        });
      }
    } catch (e) {
      // Filter just stays on "All Departments" if this fails.
    }
    setState(() => loadingDepts = false);
  }

  // =========================
  // MONTH NAMES MAP
  // =========================
  static const Map<String, String> monthNames = {
    "01": "January",
    "02": "February",
    "03": "March",
    "04": "April",
    "05": "May",
    "06": "June",
    "07": "July",
    "08": "August",
    "09": "September",
    "10": "October",
    "11": "November",
    "12": "December",
  };

  // =========================
  // DOWNLOADED TIMESTAMP
  // =========================
  String downloadedTimestamp() {
    final d = DateTime.now();
    return "${d.day.toString().padLeft(2, '0')}-"
        "${d.month.toString().padLeft(2, '0')}-"
        "${d.year}  "
        "${d.hour.toString().padLeft(2, '0')}:"
        "${d.minute.toString().padLeft(2, '0')}";
  }

  // =========================
  // LOAD LEADERBOARD
  // =========================
  Future<void> loadLeaderboard() async {
    setState(() {
      loading = true;
      leaderboard.clear();
    });

    final uri = Uri.parse(
      "$baseUrl/api/admin/leaderboard/daily",
    ).replace(queryParameters: {
      "year": "$year",
      "type": type,
      if (type == "month") "month": month,
      if (selectedDeptId != null) "dept_id": "$selectedDeptId",
    });

    try {
      final res = await http.get(
        uri,
        headers: {
          "Authorization": "Bearer ${widget.session.token}",
        },
      );

      final data = jsonDecode(res.body);

      if (data["success"] == true) {
        leaderboard = data["data"];
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Server error")),
      );
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  // =========================
  // EXPORT PDF
  // =========================
  Future<void> exportPdf() async {
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

    final String generatedTime = downloadedTimestamp();

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
                      "SKILL SPHERE - LEADERBOARD RANKINGS",
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      "AI Quiz Performance Leaderboard",
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
                      "Generated: $generatedTime",
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
                  "Skill Sphere Official Rankings",
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
        build: (_) {
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
                      pw.Text("Academic Year: Year $year", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A'))),
                      pw.SizedBox(height: 3),
                      pw.Text("Filter Type: ${type == "all" ? "All Time" : monthNames[month]}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#FEF3C7'),
                      borderRadius: pw.BorderRadius.circular(12),
                      border: pw.Border.all(color: PdfColor.fromHex('#FDE68A')),
                    ),
                    child: pw.Text(
                      "Ranked Students: ${leaderboard.length}",
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#92400E')),
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
              headers: const ["Rank", "Student UID", "Student Name", "Total Score / Out Of"],
              data: List.generate(leaderboard.length, (index) {
                final row = leaderboard[index];
                final String sName = row["name"] != null && row["name"].toString().isNotEmpty ? row["name"].toString() : "N/A";
                return [
                  "#${index + 1}",
                  row["uid"].toString(),
                  safeStr(sName),
                  "${row["total_marks"]} / ${row["total_out_of"]}",
                ];
              }),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
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
        title: const Text("Student Rankings"),
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
          if (leaderboard.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: const Icon(Icons.picture_as_pdf,
                    color: AurumColors.accentGold),
                tooltip: "Export PDF",
                onPressed: exportPdf,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // =========================
          // FILTER CONTROL BAR
          // =========================
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AurumColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                if (showDeptFilter) ...[
                  loadingDepts
                      ? const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: AurumColors.accentGold,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildFilterDropdown<int?>(
                            label: "Department",
                            value: selectedDeptId,
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text("All Departments"),
                              ),
                              ...departments.map((d) => DropdownMenuItem<int?>(
                                    value: d["id"] as int,
                                    child: Text("${d["name"]}"),
                                  )),
                            ],
                            onChanged: (v) => setState(() => selectedDeptId = v),
                          ),
                        ),
                ],
                Row(
                  children: [
                    // Year Selector
                    Expanded(
                      child: _buildFilterDropdown<int>(
                        label: "Year",
                        value: year,
                        items: const [
                          DropdownMenuItem(value: 1, child: Text("Year 1")),
                          DropdownMenuItem(value: 2, child: Text("Year 2")),
                          DropdownMenuItem(value: 3, child: Text("Year 3")),
                          DropdownMenuItem(value: 4, child: Text("Year 4")),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => year = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Type Selector
                    Expanded(
                      child: _buildFilterDropdown<String>(
                        label: "Duration",
                        value: type,
                        items: const [
                          DropdownMenuItem(
                              value: "all", child: Text("All Time")),
                          DropdownMenuItem(
                              value: "month", child: Text("Monthly")),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => type = v);
                        },
                      ),
                    ),
                  ],
                ),

                // Month Selector (Conditional)
                if (type == "month") ...[
                  const SizedBox(height: 12),
                  _buildFilterDropdown<String>(
                    label: "Select Month",
                    value: month,
                    items: monthNames.entries.map((e) {
                      return DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => month = v);
                    },
                  ),
                ],

                const SizedBox(height: 16),

                // Load Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : loadLeaderboard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AurumColors.accentGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 2))
                        : const Text("UPDATE LEADERBOARD",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          // =========================
          // LEADERBOARD LIST
          // =========================
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AurumColors.accentGold))
                : leaderboard.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.emoji_events_outlined,
                                size: 60, color: AurumColors.textGrey),
                            SizedBox(height: 16),
                            Text("No rankings available",
                                style: TextStyle(color: AurumColors.textGrey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: leaderboard.length,
                        itemBuilder: (context, index) {
                          final row = leaderboard[index];
                          return _buildLeaderboardTile(index, row);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // --- FILTER DROPDOWN ---
  Widget _buildFilterDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AurumColors.textGrey, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AurumColors.backgroundBlack,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: AurumColors.surfaceDark,
              icon: const Icon(Icons.arrow_drop_down,
                  color: AurumColors.accentGold),
              style:
                  const TextStyle(color: AurumColors.textWhite, fontSize: 14),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // --- LEADERBOARD TILE ---
  Widget _buildLeaderboardTile(int index, Map row) {
    Color rankColor;
    double scale = 1.0;

    // Determine visuals based on rank
    if (index == 0) {
      rankColor = AurumColors.rankGold;
      scale = 1.05;
    } else if (index == 1) {
      rankColor = AurumColors.rankSilver;
    } else if (index == 2) {
      rankColor = AurumColors.rankBronze;
    } else {
      rankColor = AurumColors.surfaceDark;
    }

    bool isTop3 = index < 3;

    return Transform.scale(
      scale: scale,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AurumColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isTop3 ? rankColor.withOpacity(0.5) : Colors.transparent,
            width: isTop3 ? 1.5 : 0,
          ),
          boxShadow: isTop3
              ? [
                  BoxShadow(
                    color: rankColor.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

          // RANK BADGE
          leading: Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isTop3 ? rankColor : AurumColors.surfaceDark,
              border: Border.all(color: Colors.white10),
            ),
            alignment: Alignment.center,
            child: Text(
              "${index + 1}",
              style: TextStyle(
                color: isTop3 ? Colors.black : AurumColors.textWhite,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),

          // USER DETAILS
          title: Text(
            "UID: ${row["uid"]}",
            style: const TextStyle(
              color: AurumColors.textWhite,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          // SCORE
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AurumColors.backgroundBlack,
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AurumColors.accentGold.withOpacity(0.3)),
            ),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: "${row["total_marks"]}",
                    style: const TextStyle(
                      color: AurumColors.accentGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  TextSpan(
                    text: " / ${row["total_out_of"]}",
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
      ),
    );
  }
}
