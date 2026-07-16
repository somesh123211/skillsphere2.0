import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

class ViewQuizPage extends StatefulWidget {
  final String token;
  const ViewQuizPage({Key? key, required this.token}) : super(key: key);

  @override
  State<ViewQuizPage> createState() => _ViewQuizPageState();
}

class _ViewQuizPageState extends State<ViewQuizPage> {
  final String baseUrl = "https://skillsphere1-0-0.onrender.com";

  final TextEditingController quizIdController = TextEditingController();

  Map<String, dynamic>? quiz;
  List questions = [];
  bool loading = false;
  String? error;

  Future<void> fetchQuiz() async {
    if (quizIdController.text.isEmpty) {
      setState(() => error = "Please enter a Quiz ID");
      return;
    }

    setState(() {
      loading = true;
      quiz = null;
      questions = [];
      error = null;
    });

    try {
      final res = await http.get(
        Uri.parse(
          "$baseUrl/api/admin/faculty-quiz/view?quiz_id=${quizIdController.text}",
        ),
        headers: {
          "Authorization": "Bearer ${widget.token}",
        },
      );

      final data = json.decode(res.body);

      if (data["success"] == true) {
        setState(() {
          quiz = data["quiz"];
          questions = data["questions"];
        });
      } else {
        setState(() {
          error = data["message"] ?? "Quiz not found";
        });
      }
    } catch (e) {
      setState(() {
        error = "Server error or connection failed";
      });
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      appBar: AppBar(
        title: const Text("View Quiz Details"),
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
          // SEARCH SECTION
          // =========================
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AurumColors.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quizIdController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AurumColors.textWhite),
                    cursorColor: AurumColors.accentGold,
                    decoration: InputDecoration(
                      hintText: "Enter Quiz ID (e.g. 101)",
                      hintStyle: const TextStyle(color: AurumColors.textGrey),
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
                    onSubmitted: (_) => loading ? null : fetchQuiz(),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: loading ? null : fetchQuiz,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: AurumColors.goldGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: loading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Icon(Icons.search, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),

          // =========================
          // ERROR MESSAGE
          // =========================
          if (error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AurumColors.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AurumColors.errorRed.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AurumColors.errorRed),
                  const SizedBox(width: 10),
                  Text(
                    error!,
                    style: const TextStyle(color: AurumColors.errorRed),
                  ),
                ],
              ),
            ),

          // =========================
          // QUIZ CONTENT
          // =========================
          if (quiz != null)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Quiz Meta Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AurumColors.goldGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AurumColors.accentGold.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "QUIZ #${quiz!["quiz_id"]}",
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "Year ${quiz!["year"]}",
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.black12, height: 24),
                        _buildMetaRow("Date", "${quiz!["quiz_date"]}"),
                        const SizedBox(height: 4),
                        _buildMetaRow("Time",
                            "${quiz!["quiz_start_time"]} - ${quiz!["quiz_end_time"]}"),
                        const SizedBox(height: 4),
                        _buildMetaRow("Created By", "${quiz!["created_by"]}"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    "QUESTIONS LIST",
                    style: TextStyle(
                      color: AurumColors.textGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Questions List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      final q = questions[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AurumColors.cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Question Header
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Q${index + 1}.",
                                  style: const TextStyle(
                                    color: AurumColors.accentGold,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "${q["question"]}",
                                    style: const TextStyle(
                                      color: AurumColors.textWhite,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Options
                            _buildOption("A", q["option_a"]),
                            _buildOption("B", q["option_b"]),
                            _buildOption("C", q["option_c"]),
                            _buildOption("D", q["option_d"]),

                            const SizedBox(height: 16),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 8),

                            // Correct Answer
                            Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: AurumColors.successGreen, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  "Correct Answer: ",
                                  style: TextStyle(
                                    color: AurumColors.successGreen
                                        .withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  "${q["correct_option"]}".toUpperCase(),
                                  style: const TextStyle(
                                    color: AurumColors.successGreen,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildMetaRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            "$label:",
            style: TextStyle(
              color: Colors.black.withOpacity(0.6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildOption(String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AurumColors.surfaceDark,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: AurumColors.textGrey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AurumColors.textGrey,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
