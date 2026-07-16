import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui'; // Required for Glassmorphism
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'daily_quiz_page.dart';
import 'faculty_quiz_page.dart';
import 'pages/student_profile.dart';

class StudentDashboard extends StatefulWidget {
  final String token;
  final Map<String, dynamic> studentData;

  const StudentDashboard({
    super.key,
    required this.token,
    required this.studentData,
  });

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with TickerProviderStateMixin {
  // ================= LOGIC (STRICTLY PRESERVED) =================

  // NOTE: If using Android Emulator, change to "http://10.0.2.2:5000"
  final String baseUrl = "https://skillsphere1-0-0.onrender.com";

  bool loadingProfile = true;
  bool loadingTodayQuiz = true;
  bool loadingFacultyQuiz = true;

  String name = "";
  String branch = "";
  String? profileImageUrl;

  bool todayQuizAvailable = false;
  bool todayQuizAttempted = false;

  List<Map<String, dynamic>> facultyQuizzes = [];

  Timer? uiTimer;

  // Animation Controller for the Moving Background
  late AnimationController _warpController;

  @override
  void initState() {
    super.initState();

    // Animation: Loop for moving stars (Warp Effect)
    _warpController =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat();

    fetchProfile();
    fetchTodayQuizStatus();
    fetchFacultyQuizzes();

    // 🔄 Refresh countdown every second to keep timers live
    uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    uiTimer?.cancel();
    _warpController.dispose();
    super.dispose();
  }

  // --- API CALL 1: PROFILE ---
  Future<void> fetchProfile() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/get_student_profile'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (res.statusCode != 200) {
        setState(() => loadingProfile = false);
        return;
      }

      final data = jsonDecode(res.body);
      final p = data['profile'];

      setState(() {
        name = p['name'] ?? "";
        branch = p['branch'] ?? "";
        final img = p['profile_image'];

        if (img != null && img.toString().startsWith("http")) {
          profileImageUrl = "$img?t=${DateTime.now().millisecondsSinceEpoch}";
        } else {
          profileImageUrl = null;
        }

        loadingProfile = false;
      });
    } catch (_) {
      setState(() => loadingProfile = false);
    }
  }

  // --- API CALL 2: TODAY QUIZ STATUS ---
  Future<void> fetchTodayQuizStatus() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/quiz/today/status'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          todayQuizAvailable = data['available'] == true;
          todayQuizAttempted = data['attempted'] == true;
          loadingTodayQuiz = false;
        });
      } else {
        setState(() => loadingTodayQuiz = false);
      }
    } catch (_) {
      setState(() => loadingTodayQuiz = false);
    }
  }

  // --- API CALL 3: FACULTY QUIZ LIST ---
  Future<void> fetchFacultyQuizzes() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/faculty_quiz/list'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );

      if (res.statusCode != 200) {
        setState(() {
          facultyQuizzes = [];
          loadingFacultyQuiz = false;
        });
        return;
      }

      final data = jsonDecode(res.body);
      final raw = data['quizzes'] ?? [];

      setState(() {
        facultyQuizzes = raw
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .where((q) => !isEnded(q))
            .toList();

        loadingFacultyQuiz = false;
      });
    } catch (_) {
      setState(() {
        facultyQuizzes = [];
        loadingFacultyQuiz = false;
      });
    }
  }

  Future<void> handleRefresh() async {
    setState(() {
      loadingTodayQuiz = true;
      loadingFacultyQuiz = true;
    });
    await Future.wait([
      fetchProfile(),
      fetchTodayQuizStatus(),
      fetchFacultyQuizzes(),
    ]);
  }

  // --- DATE/TIME HELPERS ---
  DateTime buildDateTime(String date, String time) {
    final d = date.split('-').map(int.parse).toList();
    final t = time.split(':').map(int.parse).toList();
    return DateTime(d[0], d[1], d[2], t[0], t[1], t.length > 2 ? t[2] : 0);
  }

  bool isUpcoming(Map q) {
    final now = DateTime.now();
    final start = buildDateTime(q['quiz_date'], q['quiz_start_time']);
    return now.isBefore(start);
  }

  bool isLive(Map q) {
    final now = DateTime.now();
    final start = buildDateTime(q['quiz_date'], q['quiz_start_time']);
    final end = buildDateTime(q['quiz_date'], q['quiz_end_time']);
    return now.isAfter(start) && now.isBefore(end);
  }

  bool isEnded(Map q) {
    final now = DateTime.now();
    final end = buildDateTime(q['quiz_date'], q['quiz_end_time']);
    return now.isAfter(end);
  }

  String startCountdown(Map q) {
    final start = buildDateTime(q['quiz_date'], q['quiz_start_time']);
    final diff = start.difference(DateTime.now());
    if (diff.inSeconds <= 0) return "";
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    final s = diff.inSeconds.remainder(60);
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  String endCountdown(Map q) {
    final end = buildDateTime(q['quiz_date'], q['quiz_end_time']);
    final diff = end.difference(DateTime.now());
    if (diff.inSeconds <= 0) return "";
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    final s = diff.inSeconds.remainder(60);
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  // ================= UI (GAMIFIED THEME) =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildGlassAppBar(),
      backgroundColor: Colors.black, // Darkest base
      body: Stack(
        children: [
          // LAYER 1: DEEP GALAXY GRADIENT
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF020024), // Very dark blue
                  Color(0xFF090979), // Space Blue
                  Colors.black, // Void
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // LAYER 2: MOVING WARP STARFIELD
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _warpController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _WarpStarPainter(
                    animationValue: _warpController.value,
                    starCount: 150,
                  ),
                );
              },
            ),
          ),

          // LAYER 3: MAIN CONTENT
          SafeArea(
            child: RefreshIndicator(
              color: const Color(0xFF00D4FF),
              onRefresh: handleRefresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 30),
                  _buildSectionTitle(
                      "DAILY QUEST", Icons.bolt, const Color(0xFFFFD700)),
                  const SizedBox(height: 12),
                  _buildDailyQuizCard(),
                  const SizedBox(height: 30),
                  _buildSectionTitle("ACTIVE MISSIONS", Icons.sports_esports,
                      const Color(0xFF00D4FF)),
                  const SizedBox(height: 12),
                  _buildFacultyQuizList(),

                  const SizedBox(height: 40),
                  // ================= FOOTER =================
                  const Center(
                    child: Text(
                      "Designed and Developed by YSBP",
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Components ---

  PreferredSizeWidget _buildGlassAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.black.withOpacity(0.3)),
        ),
      ),
      title: const Text("COMMAND CENTER",
          style: TextStyle(
              letterSpacing: 2,
              fontWeight: FontWeight.w900,
              color: Colors.white)),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.sync, color: Color(0xFF00D4FF)),
          onPressed: handleRefresh,
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return _GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00D4FF), width: 2),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF00D4FF).withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2)
              ],
            ),
            child: CircleAvatar(
              radius: 35,
              backgroundImage: profileImageUrl != null
                  ? NetworkImage(profileImageUrl!)
                  : null,
              backgroundColor: Colors.grey[900],
              child: profileImageUrl == null
                  ? const Icon(Icons.person, size: 35, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                loadingProfile
                    ? _buildShimmerText(width: 150)
                    : Text(name.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0)),
                const SizedBox(height: 5),
                loadingProfile
                    ? _buildShimmerText(width: 100)
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24)),
                        child: Text(branch,
                            style: const TextStyle(
                                color: Color(0xFF00D4FF),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => StudentProfilePage(token: widget.token)));
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.settings, color: Colors.white70),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: color.withOpacity(0.3))),
      ],
    );
  }

  Widget _buildDailyQuizCard() {
    if (loadingTodayQuiz)
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD700)));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
            colors: [Color(0xFFF2994A), Color(0xFFF2C94C)]),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFF2994A).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: (todayQuizAvailable && !todayQuizAttempted)
              ? () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DailyQuizPage(token: widget.token)));
                  fetchTodayQuizStatus();
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      shape: BoxShape.circle),
                  child: Icon(
                      todayQuizAttempted
                          ? Icons.check_circle
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Daily Challenge",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        !todayQuizAvailable
                            ? "No quest available today"
                            : todayQuizAttempted
                                ? "Quest Completed"
                                : "Ready to Start",
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9), fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (todayQuizAvailable && !todayQuizAttempted)
                  const Icon(Icons.arrow_forward_ios,
                      color: Colors.white70, size: 16)
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFacultyQuizList() {
    if (loadingFacultyQuiz)
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D4FF)));
    if (facultyQuizzes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(Icons.inbox, size: 40, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 10),
            Text("No active missions",
                style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ],
        ),
      );
    }

    return Column(
      children: facultyQuizzes.map((q) => _buildQuizCard(q)).toList(),
    );
  }

  Widget _buildQuizCard(Map q) {
    bool attempted = q['attempted'] == true;
    bool live = isLive(q);
    bool upcoming = isUpcoming(q);

    Color statusColor = live
        ? const Color(0xFF00FF88)
        : (upcoming ? const Color(0xFF00D4FF) : Colors.grey);
    String statusText = live ? "LIVE" : (upcoming ? "UPCOMING" : "ENDED");

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: _GlassContainer(
        padding: const EdgeInsets.all(0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: (live && !attempted)
                ? () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => FacultyQuizPage(
                                token: widget.token, quizId: q['quiz_id'])));
                    fetchFacultyQuizzes();
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: statusColor.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            if (live) _BlinkingDot(color: statusColor),
                            if (live) const SizedBox(width: 6),
                            Text(statusText,
                                style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      if (attempted)
                        const Icon(Icons.check_circle,
                            color: Color(0xFF00FF88), size: 18),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text("Mission ID: ${q['quiz_id']}",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (upcoming)
                    Row(
                      children: [
                        const Icon(Icons.timer,
                            size: 14, color: Color(0xFF00D4FF)),
                        const SizedBox(width: 6),
                        Text("Starts in: ${startCountdown(q)}",
                            style: const TextStyle(
                                color: Color(0xFF00D4FF),
                                fontSize: 12,
                                fontFamily: 'monospace')),
                      ],
                    ),
                  if (live)
                    Row(
                      children: [
                        const Icon(Icons.hourglass_bottom,
                            size: 14, color: Color(0xFFFF5555)),
                        const SizedBox(width: 6),
                        Text("Ends in: ${endCountdown(q)}",
                            style: const TextStyle(
                                color: Color(0xFFFF5555),
                                fontSize: 12,
                                fontFamily: 'monospace')),
                      ],
                    ),
                  if (live && !attempted) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF00D4FF), Color(0xFF0055FF)]),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF0055FF).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text("START MISSION",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerText({required double width}) {
    return Container(
      width: width,
      height: 16,
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4)),
    );
  }
}

// ================= HELPERS UI =================

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _GlassContainer({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  final Color color;
  const _BlinkingDot({required this.color});
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    );
  }
}

// ================= BACKGROUND PAINTER =================

class _WarpStarPainter extends CustomPainter {
  final double animationValue;
  final int starCount;
  final math.Random random = math.Random(42);

  _WarpStarPainter({required this.animationValue, required this.starCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    for (int i = 0; i < starCount; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;
      double speed = 0.5 + random.nextDouble() * 2.0;

      double moveX = (x - (animationValue * size.width * speed)) % size.width;
      if (moveX < 0) moveX += size.width;

      double sizeVal = random.nextDouble() * 2 + 0.5;
      paint.color = Colors.white.withOpacity((sizeVal / 3) * 0.8);
      canvas.drawCircle(Offset(moveX, y), sizeVal, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WarpStarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
