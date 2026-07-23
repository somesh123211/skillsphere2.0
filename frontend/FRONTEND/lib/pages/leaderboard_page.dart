import 'dart:math' as math;
import 'dart:ui'; // Required for Glassmorphism
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class LeaderboardPage extends StatefulWidget {
  final String token;

  const LeaderboardPage({Key? key, required this.token}) : super(key: key);

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  // ==========================================
  //            BACKEND LOGIC (PRESERVED)
  // ==========================================

  // NOTE: Use 10.0.2.2 for Android Emulator
  final String baseUrl = "https://skillsphere-2-qanz.onrender.com";

  bool loading = true;
  List leaderboard = [];
  String monthName = "";

  // Animation Controller
  late AnimationController _starController;

  @override
  void initState() {
    super.initState();

    // Background Animation
    _starController =
        AnimationController(vsync: this, duration: const Duration(seconds: 60))
          ..repeat();

    fetchLeaderboard();
  }

  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }

  Future<void> fetchLeaderboard() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        "$baseUrl/api/leaderboard",
        options: Options(
          headers: {
            "Authorization": "Bearer ${widget.token}",
          },
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (response.statusCode == 200 && response.data["success"] == true) {
        if (mounted) {
          setState(() {
            leaderboard = response.data["top10"] ?? [];
            monthName = response.data["month"] ?? "";
            loading = false;
          });
        }
      } else {
        if (mounted) setState(() => loading = false);
      }
    } catch (e) {
      debugPrint("❌ Leaderboard error: $e");
      if (mounted) setState(() => loading = false);
    }
  }

  // ==========================================
  //               GAMIFIED UI BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    const Color colorCyan = Color(0xFF00E5FF);
    const Color colorGold = Color(0xFFFFD700);
    const Color colorSilver = Color(0xFFC0C0C0);
    const Color colorBronze = Color(0xFFCD7F32);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildGlassAppBar(colorCyan),
      backgroundColor: Colors.black,
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

          // LAYER 3: MAIN CONTENT
          SafeArea(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: colorCyan))
                : Column(
                    children: [
                      // HEADER TITLE (Month)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            Text(
                              "TOP STUDENTS",
                              style: TextStyle(
                                color: colorCyan,
                                letterSpacing: 3.0,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              monthName.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // LEADERBOARD LIST
                      Expanded(
                        child: leaderboard.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                itemCount: leaderboard.length,
                                itemBuilder: (context, index) {
                                  final item = leaderboard[index];
                                  final int rank = index + 1;

                                  // Determine Style based on Rank
                                  Color rankColor;
                                  double scale = 1.0;

                                  if (rank == 1) {
                                    rankColor = colorGold;
                                    scale = 1.05; // Slightly larger
                                  } else if (rank == 2) {
                                    rankColor = colorSilver;
                                  } else if (rank == 3) {
                                    rankColor = colorBronze;
                                  } else {
                                    rankColor = colorCyan.withOpacity(0.5);
                                  }

                                  return Transform.scale(
                                    scale: scale,
                                    child:
                                        _buildRankCard(item, rank, rankColor),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  PreferredSizeWidget _buildGlassAppBar(Color accent) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme:
          const IconThemeData(color: Colors.white), // ✅ Fixed: White Back Arrow
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.black.withOpacity(0.3)),
        ),
      ),
      title: const Text(
        "LEADERBOARD", // ✅ Fixed: White Title
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard,
              size: 60, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 20),
          Text(
            "NO DATA AVAILABLE",
            style: TextStyle(
                color: Colors.white.withOpacity(0.5), letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildRankCard(Map item, int rank, Color color) {
    bool isTop3 = rank <= 3;

    return Container(
      margin: EdgeInsets.only(bottom: isTop3 ? 20 : 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(
          color: color.withOpacity(isTop3 ? 0.8 : 0.3),
          width: isTop3 ? 2 : 1,
        ),
        boxShadow: isTop3
            ? [
                BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 1)
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // RANK BADGE
                Container(
                  width: 45,
                  height: 45,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.2),
                    border: Border.all(color: color),
                  ),
                  child: isTop3
                      ? Icon(Icons.emoji_events, color: color, size: 24)
                      : Text(
                          "#$rank",
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                ),

                const SizedBox(width: 20),

                // NAME & INFO
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item["name"] ?? "Unknown",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (rank == 1)
                        Text(
                          "DOMINATING",
                          style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2),
                        ),
                    ],
                  ),
                ),

                // SCORE
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "TOTAL SCORE",
                      style: TextStyle(
                          color: Colors.white38, fontSize: 8, letterSpacing: 1),
                    ),
                    Text(
                      "${item["total_score"]}",
                      style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
//           STAR PAINTER (REUSED)
// ==========================================

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
