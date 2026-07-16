import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class QuizReviewPage extends StatefulWidget {
  final String token;

  const QuizReviewPage({
    Key? key,
    required this.token,
  }) : super(key: key);

  @override
  State<QuizReviewPage> createState() => _QuizReviewPageState();
}

class _QuizReviewPageState extends State<QuizReviewPage> {
  // ==========================================
  //            BACKEND LOGIC
  // ==========================================

  // NOTE: Use 10.0.2.2 for Android Emulator, 127.0.0.1 for Web/iOS
  final String baseUrl = "https://skillsphere1-0-0.onrender.com";

  bool loading = true;
  List<Map<String, dynamic>> answers = [];
  int score = 0;
  int total = 0;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    fetchReview();
  }

  Future<void> fetchReview() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        "$baseUrl/api/quiz/review",
        options: Options(
          headers: {
            "Authorization": "Bearer ${widget.token}",
          },
        ),
      );

      if (response.statusCode == 200 &&
          response.data != null &&
          response.data["success"] == true) {
        if (mounted) {
          setState(() {
            score = response.data["score"] ?? 0;
            total = response.data["total"] ?? 0;

            final List list = response.data["answers"] ?? [];
            answers = list.map((e) => Map<String, dynamic>.from(e)).toList();

            loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMsg = "Failed to load quiz review";
            loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMsg = "Network error while loading review";
          loading = false;
        });
      }
    }
  }

  // ==========================================
  //               CLEAN UI BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    // Simple Dark Theme Colors
    const Color bgDark = Color(0xFF121212);
    const Color cardColor = Color(0xFF1E1E1E);
    const Color correctColor = Colors.greenAccent;
    const Color wrongColor = Colors.redAccent;

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        title: const Text(
          "Quiz Results",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold), // FIXED COLOR
        ),
        centerTitle: true,
        iconTheme:
            const IconThemeData(color: Colors.white), // Makes back arrow white
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMsg != null
              ? Center(
                  child: Text(errorMsg!,
                      style: const TextStyle(color: Colors.red)),
                )
              : Column(
                  children: [
                    // ---------------- SCORE HEADER ----------------
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: cardColor,
                        border: Border(
                          bottom: BorderSide(color: Colors.white10),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "YOUR SCORE",
                            style: TextStyle(
                              color: Colors.white54,
                              letterSpacing: 1.5,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "$score / $total",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          LinearProgressIndicator(
                            value: total == 0 ? 0 : score / total,
                            backgroundColor: Colors.white10,
                            color:
                                score > (total / 2) ? correctColor : wrongColor,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ),
                    ),

                    // ---------------- QUESTIONS LIST ----------------
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: answers.length,
                        itemBuilder: (context, index) {
                          final q = answers[index];
                          final bool isCorrect = q["is_correct"] == true;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCorrect
                                    ? correctColor.withOpacity(0.3)
                                    : wrongColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Question Text
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Q${index + 1}.",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        q["question"] ?? "No Question",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),
                                const Divider(color: Colors.white10),
                                const SizedBox(height: 8),

                                // User Answer
                                Row(
                                  children: [
                                    Icon(
                                      isCorrect
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color:
                                          isCorrect ? correctColor : wrongColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text("Your Answer: ",
                                        style:
                                            TextStyle(color: Colors.white54)),
                                    Expanded(
                                      child: Text(
                                        q["your_answer"] ?? "Skipped",
                                        style: TextStyle(
                                          color: isCorrect
                                              ? correctColor
                                              : wrongColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Correct Answer (Only show if wrong)
                                if (!isCorrect) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline,
                                          color: Colors.white54, size: 20),
                                      const SizedBox(width: 8),
                                      const Text("Correct Answer: ",
                                          style:
                                              TextStyle(color: Colors.white54)),
                                      Expanded(
                                        child: Text(
                                          q["correct_answer"] ?? "N/A",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ]
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
