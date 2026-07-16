import 'package:flutter/material.dart';
import 'add_quiz_page.dart';
import 'add_questions_page.dart';
import 'delete_quiz_page.dart';
import 'view_quiz_page.dart';

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
  final String token;

  const FacultyQuizPage({Key? key, required this.token}) : super(key: key);

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
            // ADD QUIZ
            // =========================
            _buildActionCard(
              context,
              title: "Create New Quiz",
              subtitle: "Set up topic, date, and time",
              icon: Icons.note_add_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AddQuizPage(token: token)),
                );
              },
            ),
            const SizedBox(height: 16),

            // =========================
            // ADD QUESTIONS
            // =========================
            _buildActionCard(
              context,
              title: "Upload Questions",
              subtitle: "Import CSV to existing quiz",
              icon: Icons.upload_file_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddQuestionsPage(token: token)),
                );
              },
            ),
            const SizedBox(height: 16),

            // =========================
            // VIEW QUIZ
            // =========================
            _buildActionCard(
              context,
              title: "View Quiz Details",
              subtitle: "Check questions and status",
              icon: Icons.visibility_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ViewQuizPage(token: token)),
                );
              },
            ),

            const SizedBox(height: 32),
            const Text(
              "DANGER ZONE",
              style: TextStyle(
                color: AurumColors.errorRed,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // =========================
            // DELETE QUIZ
            // =========================
            _buildActionCard(
              context,
              title: "Delete Quiz",
              subtitle: "Permanently remove a quiz",
              icon: Icons.delete_outline,
              isDestructive: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DeleteQuizPage(token: token)),
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
