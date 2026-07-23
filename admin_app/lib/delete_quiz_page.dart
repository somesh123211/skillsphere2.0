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
  static const Color errorRed = Color(0xFFCF6679);

  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldStart, goldEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient redGradient = LinearGradient(
    colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class DeleteQuizPage extends StatefulWidget {
  final AdminSession session;
  final int? initialQuizId;
  const DeleteQuizPage({Key? key, required this.session, this.initialQuizId})
      : super(key: key);

  @override
  State<DeleteQuizPage> createState() => _DeleteQuizPageState();
}

class _DeleteQuizPageState extends State<DeleteQuizPage> {
  final String baseUrl = "https://skillsphere-2-qanz.onrender.com";

  final TextEditingController quizIdController = TextEditingController();

  Map<String, dynamic>? quiz;
  bool searching = false;
  bool deleting = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuizId != null) {
      quizIdController.text = widget.initialQuizId.toString();
      WidgetsBinding.instance.addPostFrameCallback((_) => searchQuiz());
    }
  }

  // 🔍 SEARCH QUIZ (Logic Unchanged)
  Future<void> searchQuiz() async {
    setState(() {
      searching = true;
      quiz = null;
      error = null;
    });

    try {
      final res = await http.get(
        Uri.parse(
          "$baseUrl/api/admin/faculty-quiz/delete-search?quiz_id=${quizIdController.text}",
        ),
        headers: {
          "Authorization": "Bearer ${widget.session.token}",
        },
      ).timeout(const Duration(seconds: 10));

      final data = json.decode(res.body);

      setState(() {
        quiz = data["quiz"];
        if (quiz == null) {
          error = "Quiz not found";
        }
      });
    } catch (e) {
      setState(() {
        error = "Server not reachable";
      });
    } finally {
      setState(() {
        searching = false;
      });
    }
  }

  // ❌ DELETE QUIZ (Logic Unchanged)
  Future<void> deleteQuiz() async {
    setState(() => deleting = true);

    try {
      final res = await http.delete(
        Uri.parse("$baseUrl/api/admin/faculty-quiz/delete"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.session.token}",
        },
        body: json.encode({
          "quiz_id": quiz!["quiz_id"],
        }),
      );

      final data = json.decode(res.body);

      if (data["success"] == true) {
        quiz = null;
        quizIdController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Quiz deleted successfully"),
            backgroundColor: AurumColors.accentGold,
          ),
        );
      } else {
        error = data["message"] ?? "Delete failed";
      }
    } catch (e) {
      error = "Delete failed";
    } finally {
      setState(() => deleting = false);
    }
  }

  // ⚠️ CONFIRMATION DIALOG (Styled)
  void confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AurumColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Confirm Deletion",
          style: TextStyle(
              color: AurumColors.errorRed, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "This will permanently delete the quiz and its associated questions. This action cannot be undone.\n\nAre you sure?",
          style: TextStyle(color: AurumColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AurumColors.errorRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              deleteQuiz();
            },
            child: const Text("Permanently Delete",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
        title: const Text("Delete Quiz"),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // =========================
            // SEARCH CARD
            // =========================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AurumColors.cardSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "FIND QUIZ",
                    style: TextStyle(
                      color: AurumColors.accentGold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quizIdController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AurumColors.textWhite),
                    cursorColor: AurumColors.accentGold,
                    decoration: InputDecoration(
                      hintText: "Enter Quiz ID (e.g. 101)",
                      hintStyle: const TextStyle(color: AurumColors.textGrey),
                      filled: true,
                      fillColor: AurumColors.backgroundBlack,
                      prefixIcon: const Icon(Icons.search,
                          color: AurumColors.accentGold),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward,
                            color: AurumColors.accentGold),
                        onPressed: searching ? null : searchQuiz,
                      ),
                    ),
                    onSubmitted: (_) => searching ? null : searchQuiz(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // =========================
            // STATES (Loading / Error)
            // =========================
            if (searching)
              const CircularProgressIndicator(color: AurumColors.accentGold),

            if (error != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AurumColors.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AurumColors.errorRed.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AurumColors.errorRed),
                    const SizedBox(width: 12),
                    Text(
                      error!,
                      style: const TextStyle(color: AurumColors.errorRed),
                    ),
                  ],
                ),
              ),

            // =========================
            // RESULT CARD (Danger Zone)
            // =========================
            if (quiz != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AurumColors.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AurumColors.errorRed.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: AurumColors.errorRed.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded,
                            color: AurumColors.errorRed),
                        SizedBox(width: 10),
                        Text(
                          "QUIZ FOUND",
                          style: TextStyle(
                            color: AurumColors.errorRed,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 30),

                    if (quiz!["quiz_name"] != null &&
                        "${quiz!["quiz_name"]}".isNotEmpty) ...[
                      _buildInfoRow(Icons.badge_outlined, "Name",
                          "${quiz!["quiz_name"]}"),
                      const SizedBox(height: 12),
                    ],
                    _buildInfoRow(Icons.tag, "Quiz ID", "${quiz!["quiz_id"]}"),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                        Icons.calendar_today, "Date", "${quiz!["quiz_date"]}"),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.access_time, "Time",
                        "${quiz!["quiz_start_time"]} - ${quiz!["quiz_end_time"]}"),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                        Icons.school, "Year", "Year ${quiz!["year"]}"),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                        Icons.person, "Creator", "${quiz!["created_by"]}"),

                    const SizedBox(height: 30),

                    // DELETE BUTTON
                    InkWell(
                      onTap: deleting ? null : confirmDelete,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: AurumColors.redGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AurumColors.errorRed.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: deleting
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.delete_forever,
                                      color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    "DELETE QUIZ",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper for Details
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AurumColors.textGrey, size: 20),
        const SizedBox(width: 12),
        Text(
          "$label: ",
          style: const TextStyle(color: AurumColors.textGrey, fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AurumColors.textWhite,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
