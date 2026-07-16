import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ✅ ADD THIS IMPORT
import 'package:placement_portal/pages/quiz_review_page.dart';

class DailyQuizPage extends StatefulWidget {
  final String token;

  const DailyQuizPage({super.key, required this.token});

  @override
  State<DailyQuizPage> createState() => _DailyQuizPageState();
}

class _DailyQuizPageState extends State<DailyQuizPage> {
  final String baseUrl = "https://skillsphere1-0-0.onrender.com";

  bool loading = true;
  bool submitting = false;
  bool autoSubmitted = false;
  bool quizFinished = false;
  bool optionsDisabled = false;

  List questions = [];
  final Map<int, String?> answers = {};

  static const int quizDurationSeconds = 600;
  int remainingSeconds = quizDurationSeconds;
  Timer? countdownTimer;

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    fetchQuiz();
    startCountdown();
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  // ================= TIMER =================
  void startCountdown() {
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() => remainingSeconds--);
      } else {
        timer.cancel();

        if (!autoSubmitted && !submitting) {
          autoSubmitted = true;
          optionsDisabled = true;
          submitQuiz(auto: true);
        }
      }
    });
  }

  String formatTime(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  // ================= FETCH QUIZ =================
  Future<void> fetchQuiz() async {
    try {
      final res = await http.get(
        Uri.parse("$baseUrl/daily_quiz"),
        headers: {"Authorization": "Bearer ${widget.token}"},
      );

      final data = jsonDecode(res.body);

      if (data["attempted"] == true) {
        quizFinished = true;
        optionsDisabled = true;
        loading = false;
        countdownTimer?.cancel();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text("Quiz Locked"),
              content: const Text(
                "You have already attempted today's quiz.\n"
                "Check profile section for marks.",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        });
        return;
      }

      if (res.statusCode == 200 && data["success"] == true) {
        setState(() {
          questions = data["questions"];
          loading = false;
        });
      } else {
        loading = false;
      }
    } catch (_) {
      loading = false;
    }
  }

  // ================= SUBMIT QUIZ =================
  Future<void> submitQuiz({bool auto = false}) async {
    if (submitting || quizFinished) return;

    quizFinished = true;
    optionsDisabled = true;
    setState(() => submitting = true);
    countdownTimer?.cancel();

    try {
      final payload = {
        "answers": questions.map((q) {
          return {
            "question_id": q["question_id"],
            "selected_answer": answers[q["question_id"]],
          };
        }).toList(),
      };

      final res = await http.post(
        Uri.parse("$baseUrl/api/quiz/submit"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
        body: jsonEncode(payload),
      );

      setState(() => submitting = false);
      if (!mounted) return;

      // ✅ AUTO SUBMIT → OPEN REVIEW PAGE
      if (auto && res.statusCode == 200) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QuizReviewPage(token: widget.token),
          ),
        );
        return;
      }

      // ✅ MANUAL SUBMIT → OPEN REVIEW PAGE
      if (res.statusCode == 200) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QuizReviewPage(token: widget.token),
          ),
        );
      }
    } catch (_) {
      setState(() => submitting = false);
    }
  }

  // ================= BACK BLOCK =================
  Future<bool> onWillPop() async {
    if (!quizFinished) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Back navigation disabled during quiz")),
      );
      return false;
    }
    return true;
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Daily Placement Quiz"),
          automaticallyImplyLeading: false,
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : questions.isEmpty
                ? const Center(child: Text("No quiz available today"))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          "Time Remaining: ${formatTime(remainingSeconds)}",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: questions.length + 1,
                          itemBuilder: (context, index) {
                            if (index == questions.length) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 20),
                                child: ElevatedButton(
                                  onPressed: submitting || optionsDisabled
                                      ? null
                                      : () => submitQuiz(),
                                  child: submitting
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : const Text("Submit Quiz"),
                                ),
                              );
                            }

                            final q = questions[index];
                            final qid = q["question_id"];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Q${index + 1}. ${q["question"]}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 10),
                                    ...List.generate(q["options"].length, (i) {
                                      final opt = q["options"][i];
                                      return RadioListTile<String>(
                                        title: Text(opt),
                                        value: opt,
                                        groupValue: answers[qid],
                                        onChanged: optionsDisabled
                                            ? null
                                            : (val) {
                                                setState(() {
                                                  answers[qid] = val;
                                                });
                                              },
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
