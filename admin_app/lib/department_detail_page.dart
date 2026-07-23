import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'admin_session.dart';
import 'staff_management_page.dart' show StaffFormDialog, AurumColors;

class DepartmentDetailPage extends StatefulWidget {
  final AdminSession session;
  final int deptId;
  final String deptName;

  const DepartmentDetailPage({
    Key? key,
    required this.session,
    required this.deptId,
    required this.deptName,
  }) : super(key: key);

  @override
  State<DepartmentDetailPage> createState() => _DepartmentDetailPageState();
}

class _DepartmentDetailPageState extends State<DepartmentDetailPage> {
  final String baseUrl = "https://skillsphere-2-qanz.onrender.com";
  bool loading = true;
  List staff = [];

  Map<String, String> get _headers => {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${widget.session.token}",
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/admin/department/${widget.deptId}/details"),
        headers: _headers,
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data["success"] == true) {
        setState(() => staff = data["staff"]);
      } else {
        _showMessage(data["error"] ?? "Failed to load department");
      }
    } catch (e) {
      debugPrint("Department detail load error: $e");
      _showMessage("Unable to connect to the server. Please try again.");
    }
    if (mounted) setState(() => loading = false);
  }

  void _showMessage(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _toggleActive(Map member) async {
    final bool isActive = member["is_active"] == 1 || member["is_active"] == true;
    final id = member["id"];
    final response = isActive
        ? await http.delete(Uri.parse("$baseUrl/api/admin/staff/$id/delete"), headers: _headers)
        : await http.post(Uri.parse("$baseUrl/api/admin/staff/$id/activate"), headers: _headers);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data["success"] == true) {
      _load();
    } else {
      _showMessage(data["error"] ?? "Action failed");
    }
  }

  Future<void> _openAddDialog() async {
    await showDialog(
      context: context,
      builder: (_) => StaffFormDialog(
        session: widget.session,
        departments: [
          {"id": widget.deptId, "name": widget.deptName}
        ],
        onSubmit: (body) async {
          body["dept_id"] = widget.deptId;
          final response = await http.post(
            Uri.parse("$baseUrl/api/admin/staff/create"),
            headers: _headers,
            body: jsonEncode(body),
          );
          final data = jsonDecode(response.body);
          if (response.statusCode == 201 && data["success"] == true) {
            Navigator.pop(context);
            _showMessage(data["message"] ?? "Staff created", error: false);
            _load();
          } else {
            _showMessage(data["error"] ?? "Failed to create staff");
          }
        },
      ),
    );
  }

  Future<void> _openEditDialog(Map member) async {
    await showDialog(
      context: context,
      builder: (_) => StaffFormDialog(
        session: widget.session,
        departments: [
          {"id": widget.deptId, "name": widget.deptName}
        ],
        existing: member,
        onSubmit: (body) async {
          final response = await http.post(
            Uri.parse("$baseUrl/api/admin/staff/${member["id"]}/update"),
            headers: _headers,
            body: jsonEncode(body),
          );
          final data = jsonDecode(response.body);
          if (response.statusCode == 200 && data["success"] == true) {
            Navigator.pop(context);
            _showMessage(data["message"] ?? "Staff updated", error: false);
            _load();
          } else {
            _showMessage(data["error"] ?? "Failed to update staff");
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      appBar: AppBar(
        title: Text(widget.deptName),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: AurumColors.textWhite,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: AurumColors.accentGold),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AurumColors.accentGold,
        onPressed: _openAddDialog,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.black),
        label: const Text("Add Faculty/HOD", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AurumColors.accentGold))
          : staff.isEmpty
              ? const Center(
                  child: Text("No staff assigned to this department yet",
                      style: TextStyle(color: AurumColors.textGrey)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: staff.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final s = staff[index];
                    final subjects = (s["subjects"] as List?) ?? [];
                    final quizzes = (s["quizzes"] as List?) ?? [];
                    final bool isActive = s["is_active"] == 1 || s["is_active"] == true;

                    return Container(
                      decoration: BoxDecoration(
                        color: AurumColors.cardSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: ExpansionTile(
                        collapsedIconColor: AurumColors.accentGold,
                        iconColor: AurumColors.accentGold,
                        title: Text(s["name"] ?? "",
                            style: const TextStyle(color: AurumColors.textWhite, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          "${(s["role"] ?? "").toString().replaceAll("_", " ").toUpperCase()}"
                          "${isActive ? "" : " · INACTIVE"}",
                          style: TextStyle(color: isActive ? AurumColors.textGrey : Colors.redAccent, fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AurumColors.accentGold, size: 20),
                              onPressed: () => _openEditDialog(s),
                            ),
                            IconButton(
                              icon: Icon(
                                isActive ? Icons.person_remove_outlined : Icons.person_add_outlined,
                                color: isActive ? Colors.redAccent : Colors.green,
                                size: 20,
                              ),
                              onPressed: () => _toggleActive(s),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s["email"] ?? "", style: const TextStyle(color: AurumColors.textGrey, fontSize: 13)),
                                const SizedBox(height: 12),
                                Text("Subjects (${subjects.length})",
                                    style: const TextStyle(color: AurumColors.accentGold, fontSize: 12, fontWeight: FontWeight.bold)),
                                ...subjects.map((sub) => Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text("${sub["subject_name"]} (Year ${sub["year"]})",
                                          style: const TextStyle(color: AurumColors.textWhite, fontSize: 13)),
                                    )),
                                const SizedBox(height: 12),
                                Text("Quizzes Created (${quizzes.length})",
                                    style: const TextStyle(color: AurumColors.accentGold, fontSize: 12, fontWeight: FontWeight.bold)),
                                ...quizzes.map((q) => Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text("Quiz #${q["quiz_id"]} · ${q["quiz_date"]} · Year ${q["year"]}",
                                          style: const TextStyle(color: AurumColors.textWhite, fontSize: 13)),
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
