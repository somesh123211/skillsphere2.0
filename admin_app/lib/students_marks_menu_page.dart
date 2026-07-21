import 'package:flutter/material.dart';

// DAILY QUIZ PAGE
import 'daily_quiz_marks_select_page.dart';
import 'faculty_quiz_marks_menu_page.dart';
import 'admin_leaderboard_page.dart';
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

class StudentsMarksMenuPage extends StatelessWidget {
  final AdminSession session;

  const StudentsMarksMenuPage({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      appBar: AppBar(
        title: const Text("Marks & Analytics"),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            const Text(
              "SELECT CATEGORY",
              style: TextStyle(
                color: AurumColors.textGrey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // =========================
            // DAILY QUIZ MARKS
            // =========================
            _buildActionCard(
              context,
              title: "Ai Quiz Reports",
              subtitle: "View daily performance records",
              icon: Icons.calendar_month_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DailyQuizMarksSelectPage(
                      session: session,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // =========================
            // FACULTY QUIZ MARKS
            // =========================
            _buildActionCard(
              context,
              title: "Faculty Quiz Reports",
              subtitle: "View subject-specific quiz marks",
              icon: Icons.assignment_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FacultyQuizMarksMenuPage(
                      session: session,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),
            const Text(
              "GLOBAL RANKINGS",
              style: TextStyle(
                color: AurumColors.accentGold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // =========================
            // LEADER BOARD (Highlighted)
            // =========================
            _buildActionCard(
              context,
              title: "View Leaderboard",
              subtitle: "Check top performing students",
              icon: Icons.emoji_events_outlined,
              isGold: true, // Special Gold Style
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminLeaderboardPage(
                      session: session,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // CUSTOM ACTION CARD
  // =========================
  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isGold = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AurumColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isGold
                ? AurumColors.accentGold.withOpacity(0.5)
                : Colors.white.withOpacity(0.05),
            width: isGold ? 1.5 : 1,
          ),
          boxShadow: isGold
              ? [
                  BoxShadow(
                    color: AurumColors.accentGold.withOpacity(0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: isGold
                    ? AurumColors.goldGradient
                    : LinearGradient(
                        colors: [AurumColors.surfaceDark, Colors.black],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isGold ? Colors.black : AurumColors.accentGold,
                size: 28,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AurumColors.textWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AurumColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: isGold ? AurumColors.accentGold : AurumColors.textGrey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
