import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

class StaffManagementPage extends StatefulWidget {
  final AdminSession session;

  const StaffManagementPage({Key? key, required this.session}) : super(key: key);

  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  final String baseUrl = "https://skillsphere2-0.onrender.com";

  bool loading = true;
  List staff = [];
  List departments = []; // [{id, name}], only needed for super_admin/admin

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, String> get _headers => {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${widget.session.token}",
      };

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final staffRes =
          await http.get(Uri.parse("$baseUrl/api/admin/staff"), headers: _headers);
      final staffData = jsonDecode(staffRes.body);
      if (staffRes.statusCode == 200 && staffData["success"] == true) {
        staff = staffData["staff"];
      }

      if (widget.session.isSuperAdmin) {
        final deptRes = await http.get(Uri.parse("$baseUrl/api/admin/departments"),
            headers: _headers);
        final deptData = jsonDecode(deptRes.body);
        if (deptRes.statusCode == 200 && deptData["success"] == true) {
          departments = deptData["departments"];
        }
      }
    } catch (e) {
      debugPrint("Staff load error: $e");
      _showMessage("Unable to connect to the server. Please try again.");
    }
    if (mounted) setState(() => loading = false);
  }

  void _showMessage(String msg, {bool error = true}) {
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
    try {
      final response = isActive
          ? await http.delete(Uri.parse("$baseUrl/api/admin/staff/$id/delete"),
              headers: _headers)
          : await http.post(Uri.parse("$baseUrl/api/admin/staff/$id/activate"),
              headers: _headers);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data["success"] == true) {
        _load();
      } else {
        _showMessage(data["error"] ?? "Action failed");
      }
    } catch (e) {
      debugPrint("Staff toggle-active error: $e");
      _showMessage("Unable to connect to the server. Please try again.");
    }
  }

  Future<void> _openCreateDialog() async {
    await showDialog(
      context: context,
      builder: (_) => StaffFormDialog(
        session: widget.session,
        departments: departments,
        onSubmit: (body) async {
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
        departments: departments,
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
        title: const Text("Staff Management"),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AurumColors.accentGold,
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.black),
        label: const Text("Add Staff", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AurumColors.accentGold))
          : staff.isEmpty
              ? const Center(
                  child: Text("No staff found", style: TextStyle(color: AurumColors.textGrey)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: staff.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _buildStaffCard(staff[index]),
                ),
    );
  }

  Widget _buildStaffCard(Map member) {
    final bool isActive = member["is_active"] == 1 || member["is_active"] == true;
    return Container(
      decoration: BoxDecoration(
        color: AurumColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          member["name"] ?? "Unknown",
          style: const TextStyle(color: AurumColors.textWhite, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(member["email"] ?? "", style: const TextStyle(color: AurumColors.textGrey, fontSize: 13)),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildBadge((member["role"] ?? "").toString().replaceAll("_", " ").toUpperCase()),
                if (member["dept_name"] != null) ...[
                  const SizedBox(width: 6),
                  Text(member["dept_name"], style: const TextStyle(color: AurumColors.textGrey, fontSize: 12)),
                ],
                if (!isActive) ...[
                  const SizedBox(width: 6),
                  const Text("INACTIVE", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AurumColors.accentGold),
              tooltip: "Edit",
              onPressed: () => _openEditDialog(member),
            ),
            IconButton(
              icon: Icon(
                isActive ? Icons.person_remove_outlined : Icons.person_add_outlined,
                color: isActive ? Colors.redAccent : Colors.green,
              ),
              tooltip: isActive ? "Deactivate" : "Activate",
              onPressed: () => _toggleActive(member),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AurumColors.accentGold.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(color: AurumColors.accentGold, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

/// Shared create/edit form. If [existing] is null this is a create form.
class StaffFormDialog extends StatefulWidget {
  final AdminSession session;
  final List departments;
  final Map? existing;
  final Future<void> Function(Map<String, dynamic> body) onSubmit;

  const StaffFormDialog({
    required this.session,
    required this.departments,
    required this.onSubmit,
    this.existing,
  });

  @override
  State<StaffFormDialog> createState() => StaffFormDialogState();
}

class StaffFormDialogState extends State<StaffFormDialog> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  String role = "faculty";
  int? deptId;
  bool submitting = false;

  bool get isEdit => widget.existing != null;
  bool get isHodCaller => widget.session.isHod;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      nameCtrl.text = widget.existing!["name"]?.toString() ?? "";
      emailCtrl.text = widget.existing!["email"]?.toString() ?? "";
      role = widget.existing!["role"]?.toString() ?? "faculty";
      deptId = widget.existing!["dept_id"] is int ? widget.existing!["dept_id"] : null;
    } else if (isHodCaller) {
      role = "faculty";
      deptId = widget.session.deptId;
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) return;
    if (!isEdit && passwordCtrl.text.trim().isEmpty) return;

    setState(() => submitting = true);

    final body = <String, dynamic>{
      "name": nameCtrl.text.trim(),
      "email": emailCtrl.text.trim(),
    };
    if (!isEdit) {
      body["password"] = passwordCtrl.text.trim();
      body["role"] = role;
      if (role != "super_admin" && role != "admin") body["dept_id"] = deptId;
    } else if (!isHodCaller) {
      // Only super_admin/admin may change role/dept on edit.
      body["role"] = role;
      body["dept_id"] = deptId;
    }

    await widget.onSubmit(body);
    if (mounted) setState(() => submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    // Super admin's own role is never editable here (matches the backend
    // rule that no one can create or promote into another super admin) -
    // hiding the picker also avoids it having no matching dropdown item.
    final canPickRole = !isHodCaller && role != "super_admin";
    final needsDept = role == "hod" || role == "faculty";

    return AlertDialog(
      backgroundColor: AurumColors.surfaceDark,
      title: Text(isEdit ? "Edit Staff" : "Add Staff",
          style: const TextStyle(color: AurumColors.textWhite)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field("Name", nameCtrl),
            const SizedBox(height: 12),
            _field("Email", emailCtrl),
            if (!isEdit) ...[
              const SizedBox(height: 12),
              _field("Password", passwordCtrl, obscure: true),
              const SizedBox(height: 4),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "8+ characters, with uppercase, lowercase, a digit and a special character.",
                  style: TextStyle(color: AurumColors.textGrey, fontSize: 11),
                ),
              ),
            ],
            if (canPickRole) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                dropdownColor: AurumColors.surfaceDark,
                style: const TextStyle(color: AurumColors.textWhite),
                decoration: _dec("Role"),
                items: const [
                  DropdownMenuItem(value: "admin", child: Text("Admin")),
                  DropdownMenuItem(value: "hod", child: Text("HOD")),
                  DropdownMenuItem(value: "faculty", child: Text("Faculty")),
                ],
                onChanged: (v) => setState(() => role = v ?? role),
              ),
            ],
            if (canPickRole && needsDept) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: widget.departments.any((d) => d["id"] == deptId) ? deptId : null,
                dropdownColor: AurumColors.surfaceDark,
                style: const TextStyle(color: AurumColors.textWhite),
                decoration: _dec("Department"),
                items: widget.departments
                    .map<DropdownMenuItem<int>>((d) => DropdownMenuItem(
                          value: d["id"] as int,
                          child: Text(d["name"], overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => deptId = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: AurumColors.textGrey)),
        ),
        ElevatedButton(
          onPressed: submitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AurumColors.accentGold),
          child: Text(isEdit ? "Save" : "Create",
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AurumColors.textGrey),
        filled: true,
        fillColor: AurumColors.backgroundBlack,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );

  Widget _field(String label, TextEditingController ctrl, {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: AurumColors.textWhite),
      decoration: _dec(label),
    );
  }
}
