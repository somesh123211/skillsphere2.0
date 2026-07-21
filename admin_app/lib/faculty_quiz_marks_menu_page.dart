import 'package:flutter/material.dart';

// Pages to navigate
import 'faculty_student_quiz_marks_page.dart';
import 'faculty_quiz_wise_marks_page.dart';
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

class FacultyQuizMarksMenuPage extends StatelessWidget {
  final AdminSession session;

  const FacultyQuizMarksMenuPage({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      appBar: AppBar(
        title: const Text("Faculty Marks"),
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            const Text(
              "Select a report type to view",
              style: TextStyle(color: AurumColors.textGrey, fontSize: 14),
            ),
            const SizedBox(height: 30),

            // =========================
            // SINGLE STUDENT MARKS
            // =========================
            _buildActionCard(
              context,
              title: "Single Student Report",
              subtitle: "View performance history by UID",
              icon: Icons.person_search_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FacultyStudentQuizMarksPage(session: session),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // =========================
            // QUIZ WISE MARKS
            // =========================
            _buildActionCard(
              context,
              title: "Quiz-wise Analysis",
              subtitle: "View class results for a specific quiz ID",
              icon: Icons.assignment_turned_in_rounded,
              isGold: true, // Special highlighting
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FacultyQuizWiseMarksPage(session: session),
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
  // CUSTOM ACTION CARD WIDGET
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
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AurumColors.textGrey, size: 16),
          ],
        ),
      ),
    );
  }
}
