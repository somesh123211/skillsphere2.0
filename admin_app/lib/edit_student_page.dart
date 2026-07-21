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

class EditStudentPage extends StatefulWidget {
  final AdminSession session;
  final Map<String, dynamic> student;

  const EditStudentPage({
    Key? key,
    required this.session,
    required this.student,
  }) : super(key: key);

  @override
  State<EditStudentPage> createState() => _EditStudentPageState();
}

class _EditStudentPageState extends State<EditStudentPage> {
  final String baseUrl = "http://localhost:5000";

  late final TextEditingController nameCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController branchCtrl;
  late int selectedYear;

  bool get canEditBranch => widget.session.isSuperAdmin;
  // HOD may advance/correct a student's year within their own department
  // (e.g. end-of-year promotion); branch/department transfer still needs
  // super_admin.
  bool get canEditYear => widget.session.isSuperAdmin || widget.session.isHod;

  bool saving = false;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.student["name"]?.toString() ?? "");
    emailCtrl = TextEditingController(text: widget.student["email"]?.toString() ?? "");
    branchCtrl = TextEditingController(text: widget.student["branch"]?.toString() ?? "");
    selectedYear = int.tryParse(widget.student["year"]?.toString() ?? "") ?? 1;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    branchCtrl.dispose();
    super.dispose();
  }

  void showMessage(String msg, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _save() async {
    if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
      showMessage("Name and email are required");
      return;
    }

    setState(() => saving = true);

    final body = <String, dynamic>{
      "name": nameCtrl.text.trim(),
      "email": emailCtrl.text.trim(),
    };
    if (canEditBranch) {
      body["branch"] = branchCtrl.text.trim();
    }
    if (canEditYear) {
      body["year"] = selectedYear;
    }

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/admin/student/${widget.student["uid"]}/update"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.session.token}",
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }
      showMessage(data["message"] ?? "Failed to update student");
    } catch (e) {
      debugPrint("Edit student error: $e");
      showMessage("Unable to connect to the server. Please try again.");
    }

    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      appBar: AppBar(
        title: const Text("Edit Student"),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildField("Name", nameCtrl),
            const SizedBox(height: 16),
            _buildField("Email", emailCtrl),
            const SizedBox(height: 16),
            _buildField("Branch", branchCtrl, enabled: canEditBranch),
            const SizedBox(height: 16),
            _buildYearDropdown(),
            if (!canEditBranch || !canEditYear) ...[
              const SizedBox(height: 8),
              Text(
                canEditYear
                    ? "Only a super admin can change branch."
                    : "Only a super admin can change branch or year.",
                style: const TextStyle(color: AurumColors.textGrey, fontSize: 12),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AurumColors.accentGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text("Save Changes",
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AurumColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withOpacity(canEditYear ? 0.1 : 0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<int>(
          value: selectedYear,
          isExpanded: true,
          dropdownColor: AurumColors.surfaceDark,
          decoration: const InputDecoration(
            labelText: "Year",
            labelStyle: TextStyle(color: AurumColors.textGrey),
            border: InputBorder.none,
          ),
          style: TextStyle(
            color: canEditYear ? AurumColors.textWhite : AurumColors.textGrey,
          ),
          icon: canEditYear
              ? const Icon(Icons.arrow_drop_down, color: AurumColors.accentGold)
              : const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: 1, child: Text("Year 1")),
            DropdownMenuItem(value: 2, child: Text("Year 2")),
            DropdownMenuItem(value: 3, child: Text("Year 3")),
            DropdownMenuItem(value: 4, child: Text("Year 4")),
          ],
          onChanged: canEditYear
              ? (v) => setState(() => selectedYear = v!)
              : null,
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller,
      {bool enabled = true}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: TextStyle(
        color: enabled ? AurumColors.textWhite : AurumColors.textGrey,
      ),
      cursorColor: AurumColors.accentGold,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AurumColors.textGrey),
        filled: true,
        fillColor: AurumColors.surfaceDark,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AurumColors.accentGold),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
    );
  }
}
