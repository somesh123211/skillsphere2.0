import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FacultyQuizPage extends StatefulWidget {
  final String token;
  final int quizId;

  const FacultyQuizPage({
    super.key,
    required this.token,
    required this.quizId,
  });

  @override
  State<FacultyQuizPage> createState() => _FacultyQuizPageState();
}

class _FacultyQuizPageState extends State<FacultyQuizPage> {
  final String baseUrl = "http://localhost:5000";

  bool loading = true;
  bool submitting = false;
  bool autoSubmitted = false;
  bool quizFinished = false;
  bool optionsDisabled = false;

  String quizName = "";
  List<Map<String, dynamic>> questions = [];

  // Question ID -> Selected Option key (A / B / C / D)
  final Map<int, String?> answers = {};

  int remainingSeconds = 0;
  Timer? countdownTimer;

  // ================= INIT =================
  @override
  void initState() {
    super.initState();
    fetchFacultyQuiz();
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  // ================= TIMER =================
  void startCountdown() {
    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() => remainingSeconds--);
      } else {
        timer.cancel();

        if (!autoSubmitted && !submitting) {
          autoSubmitted = true;
          optionsDisabled = true;
          submitFacultyQuiz(auto: true);
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
  Future<void> fetchFacultyQuiz() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/faculty_quiz?quiz_id=${widget.quizId}"),
        headers: {
          "Authorization": "Bearer ${widget.token}",
        },
      );

      final data = jsonDecode(response.body);

      if (data["attempted"] == true) {
        quizFinished = true;
        optionsDisabled = true;
        setState(() => loading = false);
        _showLockedDialog();
        return;
      }

      if (response.statusCode == 200 && data["success"] == true) {
        setState(() {
          quizName = data["quiz_name"]?.toString() ?? "";
          remainingSeconds = (data["remaining_seconds"] as num?)?.toInt() ?? 0;
          questions = List<Map<String, dynamic>>.from(data["questions"] ?? []);

          for (var q in questions) {
            final qid = q["question_id"];
            final selected = q["selected_answer"];
            if (selected != null && selected.toString().isNotEmpty) {
              answers[qid] = selected.toString();
            }
          }
          loading = false;
        });
        startCountdown();
      } else {
        setState(() => loading = false);
        _showErrorDialog(data["message"] ?? data["error"] ?? "Failed to load quiz");
      }
    } catch (e) {
      debugPrint("Faculty quiz fetch error: $e");
      setState(() => loading = false);
      _showErrorDialog("Unable to connect to the server. Please check your internet connection and try again.");
    }
  }

  void _showLockedDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("Quiz Locked"),
          content: const Text(
            "You have already attempted this faculty quiz.\n"
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
  }

  void _showErrorDialog(String msg) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("Faculty Quiz"),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("Back"),
            ),
          ],
        ),
      );
    });
  }

  // ================= AUTOSAVE ANSWER =================
  Future<void> autosaveAnswer(int questionId, String selectedOption) async {
    try {
      await http.post(
        Uri.parse("$baseUrl/api/faculty_quiz/autosave"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
        body: jsonEncode({
          "quiz_id": widget.quizId,
          "question_id": questionId,
          "selected_answer": selectedOption,
        }),
      );
    } catch (e) {
      // Best-effort - the final submit is still authoritative.
    }
  }

  // ================= SUBMIT QUIZ =================
  Future<void> submitFacultyQuiz({bool auto = false}) async {
    if (submitting) return;

    setState(() => submitting = true);
    countdownTimer?.cancel();

    try {
      final payload = {
        "quiz_id": widget.quizId,
        "answers": questions.map((q) {
          return {
            "question_id": q["question_id"],
            "selected_answer": answers[q["question_id"]] ?? "",
          };
        }).toList(),
      };

      final response = await http.post(
        Uri.parse("$baseUrl/api/faculty_quiz/submit"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      quizFinished = true;
      optionsDisabled = true;
      setState(() => submitting = false);

      if (auto && response.statusCode == 200) {
        Navigator.pop(context);
        return;
      }

      if (response.statusCode == 200) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const AlertDialog(
            title: Text("Quiz Submitted"),
            content: Text(
              "Faculty quiz submitted successfully.\n"
              "Check profile section for marks.",
            ),
          ),
        );

        Future.delayed(const Duration(seconds: 4), () {
          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).pop();
          Navigator.of(context).pop();
        });
      } else {
        final data = jsonDecode(response.body);
        showMsg(data["error"] ?? "Failed to submit quiz");
      }
    } catch (_) {
      setState(() => submitting = false);
      showMsg("Network error submitting quiz");
    }
  }

  // ================= BACK BLOCK =================
  Future<bool> onWillPop() async {
    if (!quizFinished) {
      showMsg("Back navigation disabled during quiz");
      return false;
    }
    return true;
  }

  void showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(quizName.isNotEmpty ? quizName : "Faculty Quiz"),
          automaticallyImplyLeading: false,
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : questions.isEmpty
                ? const Center(child: Text("No faculty quiz available"))
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
                                      : () => submitFacultyQuiz(),
                                  child: submitting
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : const Text("Submit Faculty Quiz"),
                                ),
                              );
                            }

                            final q = questions[index];
                            final qid = q["question_id"];
                            final options =
                                List<Map<String, dynamic>>.from(q["options"]);

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
                                    ...options.map((opt) {
                                      final key = opt["key"].toString();
                                      final text = opt["text"].toString();

                                      return RadioListTile<String>(
                                        title: Text(text),
                                        value: key,
                                        groupValue: answers[qid],
                                        onChanged: optionsDisabled
                                            ? null
                                            : (val) {
                                                setState(() {
                                                  answers[qid] = val;
                                                });
                                                if (val != null) {
                                                  autosaveAnswer(qid, val);
                                                }
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
