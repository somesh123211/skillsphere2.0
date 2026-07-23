import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color errorRed = Color(0xFFCF6679);
  static const Color warningAmber = Color(0xFFFFB74D);

  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldStart, goldEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class SuperAdminGenerationAnalyticsPage extends StatefulWidget {
  final AdminSession session;

  const SuperAdminGenerationAnalyticsPage({
    Key? key,
    required this.session,
  }) : super(key: key);

  @override
  State<SuperAdminGenerationAnalyticsPage> createState() =>
      _SuperAdminGenerationAnalyticsPageState();
}

class _SuperAdminGenerationAnalyticsPageState
    extends State<SuperAdminGenerationAnalyticsPage> {
  final String baseUrl = "https://skillsphere-2-qanz.onrender.com";

  DateTime selectedDate = DateTime.now();
  int? selectedYear; // null means All Years

  bool loading = false;
  Map<String, dynamic> summary = {};
  List<dynamic> quizzes = [];

  @override
  void initState() {
    super.initState();
    fetchAnalytics();
  }

  Future<void> fetchAnalytics() async {
    setState(() => loading = true);

    final dateStr =
        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    final queryParams = {
      "date": dateStr,
      if (selectedYear != null) "year": "$selectedYear",
    };

    final uri = Uri.parse("$baseUrl/api/admin/super/quiz-generation-analytics")
        .replace(queryParameters: queryParams);

    try {
      final res = await http.get(
        uri,
        headers: {"Authorization": "Bearer ${widget.session.token}"},
      );
      final data = jsonDecode(res.body);

      if (data["success"] == true) {
        setState(() {
          summary = data["summary"] ?? {};
          quizzes = data["quizzes"] ?? [];
        });
      } else {
        showError(data["message"] ?? "Failed to load generation analytics");
      }
    } catch (e) {
      debugPrint("Analytics fetch error: $e");
      showError("Could not connect to server. Please try again.");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AurumColors.accentGold,
              onPrimary: Colors.black,
              surface: AurumColors.surfaceDark,
              onSurface: AurumColors.textWhite,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
      fetchAnalytics();
    }
  }

  void showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AurumColors.errorRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDateStr =
        "${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}";

    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      appBar: AppBar(
        title: const Text("Generation Analytics"),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: fetchAnalytics,
            tooltip: "Refresh Analytics",
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: AurumColors.accentGold),
            )
          : RefreshIndicator(
              color: AurumColors.accentGold,
              backgroundColor: AurumColors.surfaceDark,
              onRefresh: fetchAnalytics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Subtitle
                    const Text(
                      "Super Admin System Generation Metrics",
                      style: TextStyle(
                          color: AurumColors.textGrey,
                          fontSize: 13,
                          letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 16),

                    // Filters Row
                    Row(
                      children: [
                        // Date Picker Button
                        Expanded(
                          child: InkWell(
                            onTap: pickDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AurumColors.cardSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded,
                                      color: AurumColors.accentGold, size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    formattedDateStr,
                                    style: const TextStyle(
                                      color: AurumColors.textWhite,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Year Dropdown Filter
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AurumColors.cardSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.08)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: selectedYear,
                              dropdownColor: AurumColors.surfaceDark,
                              icon: const Icon(Icons.arrow_drop_down,
                                  color: AurumColors.accentGold),
                              items: const [
                                DropdownMenuItem(
                                    value: null,
                                    child: Text("All Years",
                                        style: TextStyle(
                                            color: AurumColors.textWhite,
                                            fontSize: 13))),
                                DropdownMenuItem(
                                    value: 1,
                                    child: Text("Year 1",
                                        style: TextStyle(
                                            color: AurumColors.textWhite,
                                            fontSize: 13))),
                                DropdownMenuItem(
                                    value: 2,
                                    child: Text("Year 2",
                                        style: TextStyle(
                                            color: AurumColors.textWhite,
                                            fontSize: 13))),
                                DropdownMenuItem(
                                    value: 3,
                                    child: Text("Year 3",
                                        style: TextStyle(
                                            color: AurumColors.textWhite,
                                            fontSize: 13))),
                                DropdownMenuItem(
                                    value: 4,
                                    child: Text("Year 4",
                                        style: TextStyle(
                                            color: AurumColors.textWhite,
                                            fontSize: 13))),
                              ],
                              onChanged: (val) {
                                setState(() => selectedYear = val);
                                fetchAnalytics();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Top Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: "Sets Generated",
                            value: "${summary["total_sets_generated"] ?? 0}",
                            icon: Icons.layers_rounded,
                            accentColor: AurumColors.accentGold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: "Questions",
                            value:
                                "${summary["total_questions_pregenerated"] ?? 0}",
                            icon: Icons.quiz_rounded,
                            accentColor: const Color(0xFF6C5CE7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildMetricCard(
                      title: "Avg Generation Duration",
                      value: summary["avg_generation_time"] ?? "0 sec",
                      subtitle:
                          "Average time per topic across all classes on this date",
                      icon: Icons.timer_rounded,
                      accentColor: AurumColors.successGreen,
                      fullWidth: true,
                    ),

                    const SizedBox(height: 28),

                    // List Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Generated Topics Breakdown",
                          style: TextStyle(
                            color: AurumColors.textWhite,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${quizzes.length} Quizzes",
                          style: const TextStyle(
                              color: AurumColors.accentGold,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Quizzes List
                    quizzes.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: AurumColors.cardSurface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.inbox_rounded,
                                    color: AurumColors.textGrey, size: 40),
                                SizedBox(height: 12),
                                Text(
                                  "No quiz generation records found for this date",
                                  style: TextStyle(
                                      color: AurumColors.textGrey,
                                      fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: quizzes.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, idx) {
                              final item = quizzes[idx];
                              return _buildQuizAnalyticsTile(item);
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    String? subtitle,
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurumColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AurumColors.textGrey, fontSize: 12)),
              Icon(icon, color: accentColor, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: AurumColors.textWhite,
              fontSize: fullWidth ? 22 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(
                    color: AurumColors.textGrey, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _buildQuizAnalyticsTile(Map<String, dynamic> item) {
    final year = item["year"] ?? 1;
    final dept = item["department"] ?? "AI";
    final topic = item["topic"] ?? "Untitled";
    final subject = item["subject"] ?? "General";
    final status = item["status"] ?? "UNKNOWN";
    final generatedSets = item["generated_sets"] ?? 0;
    final totalSets = item["total_sets_required"] ?? 1;
    final formattedDuration = item["formatted_duration"] ?? "0 sec";
    final createdByName = item["created_by_name"] ?? item["created_by"] ?? "Admin";

    Color statusColor;
    if (status == "READY" || status == "COMPLETED") {
      statusColor = AurumColors.successGreen;
    } else if (status == "GENERATING" || status == "QUEUED") {
      statusColor = AurumColors.warningAmber;
    } else {
      statusColor = AurumColors.errorRed;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurumColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Badges Row
          Row(
            children: [
              // Year Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AurumColors.accentGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "Year $year",
                  style: const TextStyle(
                    color: AurumColors.accentGold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Department Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  dept,
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Topic Name
          Text(
            topic,
            style: const TextStyle(
              color: AurumColors.textWhite,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Subject: $subject",
            style: const TextStyle(
              color: AurumColors.textGrey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),

          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),

          // Generation Duration & Sets Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Duration Badge
              Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      color: AurumColors.accentGold, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    "Duration: $formattedDuration",
                    style: const TextStyle(
                      color: AurumColors.accentGold,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // Sets Count
              Text(
                "$generatedSets / $totalSets Sets Generated",
                style: const TextStyle(
                  color: AurumColors.textWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Created By
          Text(
            "Created By: $createdByName",
            style: const TextStyle(
              color: AurumColors.textGrey,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
