import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui'; // Required for Glassmorphism effects
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// ✅ RESTORED ORIGINAL IMPORTS
import 'marks_history_page.dart';
import 'assignment_marks_history_page.dart';
import 'leaderboard_page.dart';
import 'quiz_review_page.dart';
import 'today_quizzes_list_page.dart';
// ✅ ADDED LOGIN PAGE IMPORT
import '../login_signup_page.dart';
import '../session_storage.dart';

class StudentProfilePage extends StatefulWidget {
  final String token;

  const StudentProfilePage({Key? key, required this.token}) : super(key: key);

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage>
    with TickerProviderStateMixin {
  // ==========================================
  //            BACKEND LOGIC (PRESERVED)
  // ==========================================

  final String baseUrl = "https://skillsphere2-0.onrender.com";

  Map<String, dynamic>? profile;
  Map<String, dynamic>? todayQuiz;
  Map<String, dynamic>? facultyTodayQuiz;

  bool isLoading = true;
  bool quizLoading = true;
  bool facultyQuizLoading = true;

  String? profileImageUrl;

  // Animation Controllers for UI
  late AnimationController _starController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    // UI Animations
    _starController =
        AnimationController(vsync: this, duration: const Duration(seconds: 60))
          ..repeat();

    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);

    fetchProfile();
  }

  @override
  void dispose() {
    _starController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ---------------- FETCH PROFILE ----------------
  Future<void> fetchProfile() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        '$baseUrl/get_student_profile',
        options: Options(
          headers: {'Authorization': 'Bearer ${widget.token}'},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        profile = response.data['profile'];

        // Add timestamp to prevent caching
        final img = profile!['profile_image']?.toString();

        if (img != null && (img.startsWith("http") || img.startsWith("data:"))) {
          profileImageUrl = img.startsWith("http") ? "$img?t=${DateTime.now().millisecondsSinceEpoch}" : img;
        } else {
          profileImageUrl = null;
        }

        await fetchTodayQuiz();
        await fetchFacultyQuizToday();

        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  ImageProvider? _getProfileImageProvider(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final str = url.trim();
    if (str.startsWith("data:image/")) {
      try {
        final parts = str.split(",");
        if (parts.length > 1) {
          return MemoryImage(base64Decode(parts[1]));
        }
      } catch (_) {}
    }
    if (str.startsWith("http")) {
      return NetworkImage(str);
    }
    return null;
  }

  // ---------------- DAILY QUIZ ----------------
  Future<void> fetchTodayQuiz() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        '$baseUrl/api/profile/today',
        queryParameters: {
          "uid": profile!["uid"],
          "year": profile!["year"],
        },
        options: Options(
          headers: {'Authorization': 'Bearer ${widget.token}'},
        ),
      );

      if (response.statusCode == 200) {
        todayQuiz = response.data;
      }
    } catch (_) {}

    if (mounted) setState(() => quizLoading = false);
  }

  // ---------------- FACULTY QUIZ ----------------
  Future<void> fetchFacultyQuizToday() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        '$baseUrl/api/profile/faculty_quiz/today',
        options: Options(
          headers: {'Authorization': 'Bearer ${widget.token}'},
        ),
      );

      if (response.statusCode == 200) {
        facultyTodayQuiz = response.data;
      }
    } catch (_) {}

    if (mounted) setState(() => facultyQuizLoading = false);
  }

  // ---------------- IMAGE UPLOAD ----------------
  Future<void> pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final dio = Dio();
    await dio.post(
      '$baseUrl/upload_profile_image',
      data: {'image_base64': base64Image},
      options: Options(headers: {'Authorization': 'Bearer ${widget.token}'}),
    );

    await fetchProfile();
  }

  // ---------------- LOGOUT LOGIC ----------------
  Future<void> _handleLogout() async {
    await SessionStorage.clearSession();
    if (!mounted) return;
    // Navigate to Login Page and remove all previous routes
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginSignupPage()),
      (route) => false, // Predicate: remove all
    );
  }

  // ==========================================
  //               GAMIFIED UI BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    // Cyberpunk Colors
    final Color colorCyan = const Color(0xFF00E5FF);
    final Color colorPink = const Color(0xFFFF2A6D);
    final Color colorGold = const Color(0xFFFFD700);
    final Color colorRed = const Color(0xFFFF0000);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildGlassAppBar(colorCyan),
      backgroundColor: Colors.black, // Base
      body: Stack(
        children: [
          // LAYER 1: DEEP SPACE BACKGROUND
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.5,
                colors: [Color(0xFF1a1a3e), Colors.black],
                stops: [0.0, 1.0],
              ),
            ),
          ),

          // LAYER 2: ANIMATED STARS
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _starController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _SpaceStarPainter(
                    animationValue: _starController.value,
                    starCount: 100,
                  ),
                );
              },
            ),
          ),

          // LAYER 3: CONTENT
          SafeArea(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: colorCyan))
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        // 1. AVATAR & NAME
                        _buildProfileHeader(colorCyan, colorPink),
                        const SizedBox(height: 35),

                        // 2. STATS SECTION
                        _buildSectionHeader(
                            "PERFORMANCE METRICS", Icons.analytics, colorGold),
                        const SizedBox(height: 15),
                        _buildQuizStats(colorGold, colorCyan),

                        const SizedBox(height: 35),

                        // 3. ACTION BUTTONS
                        _buildSectionHeader(
                            "OPERATIONS", Icons.grid_view, colorCyan),
                        const SizedBox(height: 15),
                        _buildActionButtons(colorCyan, colorPink),

                        const SizedBox(height: 35),

                        // 4. LOGOUT SECTION (NEW)
                        _buildSectionHeader(
                            "SYSTEM", Icons.settings_power, colorRed),
                        const SizedBox(height: 15),
                        _HoloButton(
                          label: "TERMINATE SESSION",
                          subtitle: "Securely logout from system",
                          icon: Icons.power_settings_new,
                          color: colorRed,
                          onTap: _handleLogout, // Call Logout Function
                        ),

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

  // ------------------------------------------
  //              WIDGET BUILDERS
  // ------------------------------------------

  PreferredSizeWidget _buildGlassAppBar(Color accent) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.black.withOpacity(0.3)),
        ),
      ),
      title: Text(
        "STUDENT PROFILE",
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
          shadows: [Shadow(color: accent, blurRadius: 10)],
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildProfileHeader(Color primary, Color secondary) {
    return Column(
      children: [
        // AVATAR WITH ROTATING RING
        Stack(
          alignment: Alignment.center,
          children: [
            // Outer Ring
            RotationTransition(
              turns: _starController,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(BorderSide(
                      color: primary.withOpacity(0.3),
                      width: 1,
                      style: BorderStyle.solid)),
                ),
              ),
            ),
            // Avatar
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: primary, width: 3),
                boxShadow: [
                  BoxShadow(
                      color: primary.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 5)
                ],
                image: _getProfileImageProvider(profileImageUrl) != null
                    ? DecorationImage(
                        image: _getProfileImageProvider(profileImageUrl)!,
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _getProfileImageProvider(profileImageUrl) == null
                  ? Icon(Icons.person,
                      size: 60, color: Colors.white.withOpacity(0.8))
                  : null,
            ),
            // Edit Badge
            Positioned(
              bottom: 5,
              right: 5,
              child: GestureDetector(
                onTap: pickAndUploadImage,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: secondary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: secondary.withOpacity(0.5), blurRadius: 10)
                    ],
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // NAME
        Text(
          profile!["name"].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),

        // BADGES
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _InfoBadge(
                text: "UID: ${profile!["uid"]}",
                color: Colors.white54,
                icon: Icons.badge),
            const SizedBox(width: 12),
            _InfoBadge(
                text: "${profile!["branch"]}",
                color: primary,
                icon: Icons.code),
          ],
        ),
      ],
    );
  }

  Widget _buildQuizStats(Color gold, Color cyan) {
    return Column(
      children: [
        // TODAY QUIZ CARD
        _GlassCard(
          borderColor: gold.withOpacity(0.5),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.emoji_events, color: gold, size: 24),
                  const SizedBox(width: 10),
                  Text("DAILY TARGET",
                      style: TextStyle(
                          color: gold,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2)),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  quizLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              todayQuiz?["attempted"] == true
                                  ? "COMPLETED"
                                  : "PENDING",
                              style: TextStyle(
                                  color: todayQuiz?["attempted"] == true
                                      ? Colors.greenAccent
                                      : Colors.white60,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              todayQuiz?["attempted"] == true
                                  ? "${todayQuiz!["score"]} / ${todayQuiz!["total"]}"
                                  : "-- / --",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Courier'),
                            ),
                          ],
                        ),
                  if (todayQuiz?["attempted"] == true)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: gold.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    TodayQuizzesListPage(token: widget.token, type: "ai")));
                      },
                      child: Text("VIEW ANSWERS",
                          style: TextStyle(
                              color: gold,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    )
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 15),

        // FACULTY QUIZ CARD
        _GlassCard(
          borderColor: cyan.withOpacity(0.5),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.school, color: cyan, size: 24),
                  const SizedBox(width: 10),
                  Text("FACULTY MISSION",
                      style: TextStyle(
                          color: cyan,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2)),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  facultyQuizLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              facultyTodayQuiz?["attempted"] == true
                                  ? "COMPLETED"
                                  : "PENDING",
                              style: TextStyle(
                                  color: facultyTodayQuiz?["attempted"] == true
                                      ? Colors.greenAccent
                                      : Colors.white60,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              facultyTodayQuiz?["attempted"] == true
                                  ? "${facultyTodayQuiz!["score"]} / ${facultyTodayQuiz!["total"]}"
                                  : "-- / --",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Courier'),
                            ),
                          ],
                        ),
                  if (facultyTodayQuiz?["attempted"] == true)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cyan.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    TodayQuizzesListPage(token: widget.token, type: "faculty")));
                      },
                      child: Text("VIEW ANSWERS",
                          style: TextStyle(
                              color: cyan,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    )
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Color cyan, Color pink) {
    return Column(
      children: [
        _HoloButton(
          label: "QUIZ HISTORY",
          subtitle: "View past performance data",
          icon: Icons.history_edu,
          color: cyan,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => MarksHistoryPage(token: widget.token))),
        ),
        const SizedBox(height: 15),
        _HoloButton(
          label: "ASSIGNMENT LOGS",
          subtitle: "Check submission records",
          icon: Icons.assignment_turned_in,
          color: Colors.purpleAccent,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      AssignmentMarksHistoryPage(token: widget.token))),
        ),
        const SizedBox(height: 15),
        _HoloButton(
          label: "LEADERBOARD",
          subtitle: "Compare ranking with peers",
          icon: Icons.emoji_events,
          color: pink,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => LeaderboardPage(token: widget.token))),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 14)),
        const SizedBox(width: 10),
        Expanded(
            child: Container(
                height: 1,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [color.withOpacity(0.5), Colors.transparent]))))
      ],
    );
  }
}

// ==========================================
//           CUSTOM WIDGETS & PAINTERS
// ==========================================

class _InfoBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  const _InfoBadge(
      {required this.text, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  const _GlassCard({required this.child, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _HoloButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HoloButton(
      {required this.label,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        color: color.withOpacity(0.05),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withOpacity(0.2),
          highlightColor: color.withOpacity(0.1),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1.0)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    color: color.withOpacity(0.5), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpaceStarPainter extends CustomPainter {
  final double animationValue;
  final int starCount;
  final math.Random random = math.Random(42);

  _SpaceStarPainter({required this.animationValue, required this.starCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    for (int i = 0; i < starCount; i++) {
      final double x = random.nextDouble() * size.width;
      final double y = random.nextDouble() * size.height;
      final double sizeVal = random.nextDouble() * 2 + 0.5;
      final double opacity =
          (math.sin((animationValue * 6.28) + random.nextDouble() * 10) + 1) /
              2;

      paint.color = Colors.white.withOpacity(opacity * 0.8);
      canvas.drawCircle(Offset(x, y), sizeVal, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpaceStarPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
