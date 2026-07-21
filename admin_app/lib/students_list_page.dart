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

  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldStart, goldEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class StudentsListPage extends StatefulWidget {
  final AdminSession session;

  const StudentsListPage({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  State<StudentsListPage> createState() => _StudentsListPageState();
}

class _StudentsListPageState extends State<StudentsListPage> {
  final String baseUrl = "https://skillsphere2-0.onrender.com";

  int selectedYear = 2;
  bool loading = false;
  List students = [];

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
    fetchStudents();
  }

  // =========================
  // FETCH DEPARTMENTS (super_admin/admin only)
  // =========================
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
  // FETCH STUDENTS
  // =========================
  Future<void> fetchStudents() async {
    setState(() {
      loading = true;
      students.clear();
    });

    try {
      final uri = Uri.parse("$baseUrl/api/admin/students").replace(
        queryParameters: {
          "year": "$selectedYear",
          if (selectedDeptId != null) "dept_id": "$selectedDeptId",
        },
      );
      final response = await http.get(
        uri,
        headers: {
          "Authorization": "Bearer ${widget.session.token}",
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
      debugPrint("Students list load error: $e");
      if (mounted) showError("Unable to connect to the server. Please try again.");
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

  String getDepartmentName() {
    if (selectedDeptId != null) {
      final found = departments.firstWhere(
        (d) => d["id"] == selectedDeptId,
        orElse: () => {},
      );
      if (found.isNotEmpty && found["name"] != null) {
        return found["name"].toString();
      }
    }
    if (widget.session.deptName.isNotEmpty) {
      return widget.session.deptName;
    }
    if (students.isNotEmpty) {
      for (var s in students) {
        if (s["dept_name"] != null && s["dept_name"].toString().isNotEmpty) {
          return s["dept_name"].toString();
        }
        if (s["department"] != null && s["department"].toString().isNotEmpty) {
          return s["department"].toString();
        }
        if (s["branch"] != null && s["branch"].toString().isNotEmpty) {
          return s["branch"].toString();
        }
      }
    }
    return "All Departments";
  }

  // =========================
  // DOWNLOAD PDF
  // =========================
  Future<void> downloadPDF() async {
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

    final String deptName = getDepartmentName();

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
                      "SKILL SPHERE - STUDENT REGISTRY REPORT",
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 1.0,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      "Enrolled Students Directory",
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
                  "Skill Sphere Official Directory",
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
        build: (context) {
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
                        "Academic Year: Year $selectedYear",
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        "Department: ${safeStr(deptName)}",
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2563EB')),
                      ),
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
                      "Total Students: ${students.length}",
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
              headers: const ["UID", "Student Name", "Email Address"],
              data: students
                  .map((s) => [
                        s["uid"].toString(),
                        safeStr(s["name"]),
                        safeStr(s["email"]),
                      ])
                  .toList(),
            ),
          ];
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
          "Authorization": "Bearer ${widget.session.token}",
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
      debugPrint("Delete student error: $e");
      showError("Unable to connect to the server. Please try again.");
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Department Dropdown — super_admin/admin only
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AurumColors.backgroundBlack,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AurumColors.accentGold.withOpacity(0.5)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int?>(
                                value: selectedDeptId,
                                isExpanded: true,
                                dropdownColor: AurumColors.surfaceDark,
                                icon: const Icon(Icons.arrow_drop_down,
                                    color: AurumColors.accentGold),
                                style: const TextStyle(
                                    color: AurumColors.textWhite,
                                    fontWeight: FontWeight.bold),
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
                                onChanged: (value) {
                                  setState(() => selectedDeptId = value);
                                  fetchStudents();
                                },
                              ),
                            ),
                          ),
                        ),
                ],
                Row(
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
                        DropdownMenuItem(value: 1, child: Text("Year 1")),
                        DropdownMenuItem(value: 2, child: Text("Year 2")),
                        DropdownMenuItem(value: 3, child: Text("Year 3")),
                        DropdownMenuItem(value: 4, child: Text("Year 4")),
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
            if (widget.session.canEditStudents)
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
                session: widget.session,
                uid: s["uid"].toString(),
              ),
            ),
          );
        },
      ),
    );
  }
}
