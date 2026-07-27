import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// --- IMPORTS ---
import 'package:placement_portal/pages/quiz_review_page.dart';
import 'platform/fullscreen.dart';
import 'platform/unload_guard.dart';

class DailyQuizPage extends StatefulWidget {
  final String token;
  final int? quizId;

  const DailyQuizPage({super.key, required this.token, this.quizId});

  @override
  State<DailyQuizPage> createState() => _DailyQuizPageState();
}

class _DailyQuizPageState extends State<DailyQuizPage> with WidgetsBindingObserver {
  final String baseUrl = "https://skillsphere-2-qanz.onrender.com";

  bool loading = true;
  bool submitting = false;
  bool autoSubmitted = false;
  bool quizFinished = false;
  bool optionsDisabled = false;

  List questions = [];
  final Map<int, String?> answers = {};
  String quizDateStr = "";

  int remainingSeconds = 0;
  Timer? countdownTimer;

  // ================= INIT =================
  bool _wasBackgrounded = false;
  int _warningCount = 0;
  static const int _maxWarnings = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchQuiz();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    countdownTimer?.cancel();
    UnloadGuard.disable();
    exitFullscreen();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (quizFinished) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      _showBackgroundWarning();
    }
  }

  void _showBackgroundWarning() {
    if (!mounted || quizFinished) return;
    _warningCount++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || quizFinished) return;

      if (_warningCount >= _maxWarnings) {
        submitQuiz(auto: true);
        return;
      }

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Warning ($_warningCount/$_maxWarnings)"),
          content: Text(
            "You left or switched away from the quiz. Your answers so far are saved.\n\n"
            "Leaving again will cause your quiz to be automatically submitted!",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK, I understand"),
            ),
          ],
        ),
      );
    });
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
      final url = widget.quizId != null
          ? "$baseUrl/daily_quiz?quiz_id=${widget.quizId}"
          : "$baseUrl/daily_quiz";
      final res = await http.get(
        Uri.parse(url),
        headers: {"Authorization": "Bearer ${widget.token}"},
      );

      final data = jsonDecode(res.body);

      if (data["attempted"] == true) {
        quizFinished = true;
        optionsDisabled = true;
        loading = false;
        countdownTimer?.cancel();
        _showLockedDialog();
        return;
      }

      if (res.statusCode == 200 && data["success"] == true) {
        setState(() {
          questions = data["questions"];
          quizDateStr = data["quiz_date"] ?? "";
          remainingSeconds = (data["remaining_seconds"] as num?)?.toInt() ?? 600;

          // Populate pre-saved autosave answers (Stage 15)
          for (var q in questions) {
            final qid = q["question_id"];
            if (q["selected_answer"] != null && q["selected_answer"].toString().isNotEmpty) {
              answers[qid] = q["selected_answer"].toString();
            }
          }
          loading = false;
        });
        startCountdown();
        requestFullscreen();
        UnloadGuard.enable(onLeft: () {
          _wasBackgrounded = true;
        });
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        setState(() => loading = false);
        _showErrorDialog(data["message"] ?? "Failed to load today's Ai Quiz");
      }
    } catch (e) {
      debugPrint("Daily quiz fetch error: $e");
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
          title: const Text("Quiz Already Attempted"),
          content: const Text(
            "You have already attempted this quiz.\n"
            "You can review your marks and answers anytime from the Student Profile.",
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

  void _showSuccessDialog({bool auto = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(auto ? Icons.warning_amber_rounded : Icons.check_circle,
                color: auto ? Colors.orangeAccent : Colors.green, size: 28),
            const SizedBox(width: 10),
            Text(auto ? "Quiz Auto-Submitted" : "Quiz Submitted"),
          ],
        ),
        content: Text(
          auto
              ? "You left/switched away from the quiz or time expired. Your answers have been submitted.\n\nRedirecting back in 5 seconds..."
              : "Your quiz response has been successfully submitted.\n\nRedirecting back in 5 seconds...",
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              Navigator.of(context).pop();
            },
            child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _showErrorDialog(String msg) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("Ai Quiz"),
          content: Text(msg),
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

  // ================= AUTOSAVE ANSWER =================
  Future<void> autosaveAnswer(int questionId, String selectedAnswer) async {
    if (quizDateStr.isEmpty) return;
    try {
      await http.post(
        Uri.parse("$baseUrl/api/daily_quiz/autosave"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
        body: jsonEncode({
          "quiz_date": quizDateStr,
          "quiz_id": widget.quizId,
          "question_id": questionId,
          "selected_answer": selectedAnswer,
        }),
      );
    } catch (e) {
      print("Autosave error: $e");
    }
  }

  // ================= SUBMIT QUIZ =================
  Future<void> submitQuiz({bool auto = false}) async {
    if (submitting || quizFinished) return;

    quizFinished = true;
    optionsDisabled = true;
    setState(() => submitting = true);
    countdownTimer?.cancel();
    UnloadGuard.disable();
    exitFullscreen();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

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

      if (res.statusCode == 200) {
        _showSuccessDialog(auto: auto);
      } else {
        final data = jsonDecode(res.body);
        _showSubmitError(data["error"] ?? "Failed to submit quiz");
      }
    } catch (_) {
      setState(() => submitting = false);
      _showSubmitError("Network error submitting quiz");
    }
  }

  void _showSubmitError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
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
          title: const Text("Daily Skill Quiz"),
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
