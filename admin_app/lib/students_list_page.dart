import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// PAGE IMPORT
import 'student_detail_page.dart';

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

  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldStart, goldEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class StudentsListPage extends StatefulWidget {
  final String token;

  const StudentsListPage({
    Key? key,
    required this.token,
  }) : super(key: key);

  @override
  State<StudentsListPage> createState() => _StudentsListPageState();
}

class _StudentsListPageState extends State<StudentsListPage> {
  final String baseUrl = "https://skillsphere1-0-0.onrender.com";

  int selectedYear = 2;
  bool loading = false;
  List students = [];

  @override
  void initState() {
    super.initState();
    fetchStudents();
  }

  // =========================
  // FETCH STUDENTS
  // =========================
  Future<void> fetchStudents() async {
    setState(() {
      loading = true;
      students.clear();
    });

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/admin/students?year=$selectedYear"),
        headers: {
          "Authorization": "Bearer ${widget.token}",
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        if (mounted) {
          setState(() {
            students = data["students"];
          });
        }
      } else {
        if (mounted) showError(data["message"] ?? "Failed to load students");
      }
    } catch (e) {
      if (mounted) showError(e.toString());
    }

    if (mounted) setState(() => loading = false);
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =========================
  // DOWNLOAD CSV
  // =========================
  void downloadCSV() {
    final buffer = StringBuffer();
    buffer.writeln("Students List - Year $selectedYear");
    buffer.writeln("UID,Name,Email");

    for (var s in students) {
      buffer.writeln("${s["uid"]},${s["name"]},${s["email"]}");
    }

    final bytes = utf8.encode(buffer.toString());

    Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: "students_year_$selectedYear.csv",
    );
  }

  // =========================
  // DOWNLOAD PDF
  // =========================
  Future<void> downloadPDF() async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final downloadedTime =
        "${now.day}-${now.month}-${now.year} ${now.hour}:${now.minute}";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Student Registry",
                        style: pw.TextStyle(
                            fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Year $selectedYear",
                        style: const pw.TextStyle(fontSize: 18)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text("Generated on: $downloadedTime",
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey700)),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ["UID", "Name", "Email"],
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.black),
                rowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                cellAlignment: pw.Alignment.centerLeft,
                data: students
                    .map((s) => [
                          s["uid"].toString(),
                          s["name"].toString(),
                          s["email"].toString(),
                        ])
                    .toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // =========================
  // DELETE STUDENT
  // =========================
  Future<void> _confirmDelete(Map student) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AurumColors.surfaceDark,
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 10),
              Text(
                "Delete Student",
                style: TextStyle(
                  color: AurumColors.textWhite,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            "Are you sure you want to permanently delete student '${student["name"]}' (UID: ${student["uid"]})? "
            "This will delete all of their quiz records, marks, and attempts.",
            style: const TextStyle(color: AurumColors.textWhite),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel", style: TextStyle(color: AurumColors.textGrey)),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _deleteStudent(student["uid"].toString(), student["name"].toString());
    }
  }

  Future<void> _deleteStudent(String uid, String name) async {
    setState(() => loading = true);

    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/api/admin/student/$uid/delete"),
        headers: {
          "Authorization": "Bearer ${widget.token}",
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Student '$name' deleted successfully"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        fetchStudents();
      } else {
        showError(data["message"] ?? "Failed to delete student");
        setState(() => loading = false);
      }
    } catch (e) {
      showError("Error deleting student: $e");
      setState(() => loading = false);
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
        title: const Text("Student Registry"),
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
      body: Column(
        children: [
          // =========================
          // CONTROL BAR (Year Selector + Actions)
          // =========================
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AurumColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                // Year Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AurumColors.backgroundBlack,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AurumColors.accentGold.withOpacity(0.5)),
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
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => selectedYear = value);
                        fetchStudents();
                      },
                    ),
                  ),
                ),

                const Spacer(),

                // Action Buttons
                _buildActionButton(
                    icon: Icons.table_chart,
                    label: "CSV",
                    onTap: students.isEmpty ? null : downloadCSV),
                const SizedBox(width: 8),
                _buildActionButton(
                    icon: Icons.picture_as_pdf,
                    label: "PDF",
                    onTap: students.isEmpty ? null : downloadPDF),
              ],
            ),
          ),

          // =========================
          // STUDENT LIST
          // =========================
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AurumColors.accentGold),
                  )
                : students.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.person_search,
                                size: 60, color: AurumColors.textGrey),
                            SizedBox(height: 16),
                            Text("No students found for this year",
                                style: TextStyle(color: AurumColors.textGrey)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: students.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final s = students[index];
                          return _buildStudentCard(s);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildActionButton(
      {required IconData icon, required String label, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.white10
              : AurumColors.accentGold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: onTap == null
                ? Colors.transparent
                : AurumColors.accentGold.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: onTap == null ? Colors.grey : AurumColors.accentGold),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: onTap == null ? Colors.grey : AurumColors.accentGold,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(Map s) {
    return Container(
      decoration: BoxDecoration(
        color: AurumColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        // Avatar
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AurumColors.goldGradient,
            boxShadow: [
              BoxShadow(
                color: AurumColors.accentGold.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            s["name"].toString().substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        // Info
        title: Text(
          s["name"] ?? "Unknown",
          style: const TextStyle(
            color: AurumColors.textWhite,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.fingerprint,
                    size: 14, color: AurumColors.textGrey),
                const SizedBox(width: 4),
                Text(
                  "UID: ${s["uid"]}",
                  style: const TextStyle(
                      color: AurumColors.textGrey, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.email_outlined,
                    size: 14, color: AurumColors.textGrey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    "${s["email"]}",
                    style: const TextStyle(
                        color: AurumColors.textGrey, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        // Actions (Delete + Arrow)
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              tooltip: "Delete Student",
              onPressed: () {
                _confirmDelete(s);
              },
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: AurumColors.accentGold),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentDetailPage(
                token: widget.token,
                uid: s["uid"].toString(),
              ),
            ),
          );
        },
      ),
    );
  }
}
