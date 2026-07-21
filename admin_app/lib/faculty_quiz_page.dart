import 'package:flutter/material.dart';
import 'add_faculty_quiz_page.dart';
import 'faculty_quiz_list_page.dart';
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

class FacultyQuizPage extends StatelessWidget {
  final AdminSession session;

  const FacultyQuizPage({Key? key, required this.session}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      appBar: AppBar(
        title: const Text("Quiz Dashboard"),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "MANAGE QUIZZES",
              style: TextStyle(
                color: AurumColors.textGrey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // =========================
            // CREATE QUIZ (name, time, duration + CSV upload, all in one)
            // =========================
            _buildActionCard(
              context,
              title: "Create Quiz",
              subtitle: "Name, schedule, duration and CSV questions in one step",
              icon: Icons.note_add_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddFacultyQuizPage(session: session)),
                );
              },
            ),
            const SizedBox(height: 16),

            // =========================
            // MY QUIZZES (view / delete / class marks)
            // =========================
            _buildActionCard(
              context,
              title: "My Quizzes",
              subtitle: "View, delete, or see class marks for a quiz",
              icon: Icons.list_alt_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => FacultyQuizListPage(session: session)),
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
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AurumColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDestructive
                ? AurumColors.errorRed.withOpacity(0.3)
                : Colors.white.withOpacity(0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: isDestructive
                    ? AurumColors.redGradient
                    : AurumColors.goldGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.white : Colors.black,
                size: 26,
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
                      color: isDestructive
                          ? AurumColors.errorRed
                          : AurumColors.textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
              color:
                  isDestructive ? AurumColors.errorRed : AurumColors.textGrey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
