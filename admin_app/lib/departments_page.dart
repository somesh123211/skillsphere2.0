import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'admin_session.dart';
import 'department_detail_page.dart';

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

class DepartmentsPage extends StatefulWidget {
  final AdminSession session;

  const DepartmentsPage({Key? key, required this.session}) : super(key: key);

  @override
  State<DepartmentsPage> createState() => _DepartmentsPageState();
}

class _DepartmentsPageState extends State<DepartmentsPage> {
  final String baseUrl = "https://skillsphere-2-qanz.onrender.com";
  bool loading = true;
  List departments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/admin/departments"),
        headers: {"Authorization": "Bearer ${widget.session.token}"},
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data["success"] == true) {
        setState(() => departments = data["departments"]);
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      appBar: AppBar(
        title: const Text("Departments"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: AurumColors.textWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: AurumColors.accentGold),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AurumColors.accentGold))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: departments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final d = departments[index];
                return Container(
                  decoration: BoxDecoration(
                    color: AurumColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AurumColors.goldGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.apartment_rounded, color: Colors.black),
                    ),
                    title: Text(d["name"] ?? "",
                        style: const TextStyle(color: AurumColors.textWhite, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AurumColors.accentGold),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DepartmentDetailPage(
                          session: widget.session,
                          deptId: d["id"],
                          deptName: d["name"],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
