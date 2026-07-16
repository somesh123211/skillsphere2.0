import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class MarksHistoryPage extends StatefulWidget {
  final String token;

  const MarksHistoryPage({Key? key, required this.token}) : super(key: key);

  @override
  State<MarksHistoryPage> createState() => _MarksHistoryPageState();
}

class _MarksHistoryPageState extends State<MarksHistoryPage> {
  // ==========================================
  //            BACKEND LOGIC
  // ==========================================

  // NOTE: Use 10.0.2.2 for Android Emulator, 127.0.0.1 for Web
  final String baseUrl = "https://skillsphere1-0-0.onrender.com";

  bool loading = true;
  List<Map<String, dynamic>> history = [];

  // Initialize with current date to prevent null errors
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  int totalScored = 0;
  int totalPossible = 0;
  String? errorMsg;

  final List<String> months = const [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

  @override
  void initState() {
    super.initState();
    fetchMarksHistory();
  }

  Future<void> fetchMarksHistory() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        "$baseUrl/api/profile/marks_history",
        queryParameters: {
          "month": selectedMonth,
          "year": selectedYear,
        },
        options: Options(
          headers: {
            "Authorization": "Bearer ${widget.token}",
          },
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (response.statusCode == 200 &&
          response.data != null &&
          response.data["success"] == true) {
        if (mounted) {
          setState(() {
            // SAFE LIST PARSING
            final List rawList = response.data["history"] ?? [];
            history = rawList.map((e) => Map<String, dynamic>.from(e)).toList();

            totalScored = response.data["total_scored"] ?? 0;
            totalPossible = response.data["total_possible"] ?? 0;
            loading = false;
            errorMsg = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMsg = "Failed to load history";
            loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMsg = "Network error";
          loading = false;
        });
      }
    }
  }

  // ==========================================
  //               PREMIUM UI BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    const Color bgDark = Color(0xFF0F0F13);
    const Color cardColor = Color(0xFF1A1A24);
    const Color accentColor = Color(0xFF6C63FF);
    const Color goldColor = Color(0xFFFFD700);

    // Safety check for month index
    String currentMonthName = "Unknown";
    if (selectedMonth >= 1 && selectedMonth <= 12) {
      currentMonthName = months[selectedMonth - 1];
    }

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(
            color: Colors.white), // ✅ Fixed: White Back Arrow
        title: const Text(
          "PERFORMANCE LOG",
          style: TextStyle(
              color: Colors.white, // ✅ Fixed: White Text
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
              fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          // ---------------- FILTER & SUMMARY HEADER ----------------
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Column(
              children: [
                // Month Selector Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("TIMELINE:",
                        style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accentColor.withOpacity(0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: selectedMonth,
                          dropdownColor: cardColor,
                          icon: Icon(Icons.arrow_drop_down, color: accentColor),
                          style: const TextStyle(color: Colors.white),
                          items: List.generate(12, (i) {
                            return DropdownMenuItem(
                              value: i + 1,
                              child: Text(months[i]),
                            );
                          }),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              selectedMonth = v;
                              loading = true;
                            });
                            fetchMarksHistory();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Total Marks Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withOpacity(0.2),
                        Colors.transparent
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "TOTAL ACCUMULATED",
                            style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                letterSpacing: 1.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "$currentMonthName $selectedYear",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Text(
                        "$totalScored / $totalPossible",
                        style: const TextStyle(
                            color: goldColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Courier'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ---------------- HISTORY LIST ----------------
          Expanded(
            child: loading
                ? Center(child: CircularProgressIndicator(color: accentColor))
                : errorMsg != null
                    ? Center(
                        child: Text(errorMsg!,
                            style: const TextStyle(color: Colors.redAccent)))
                    : history.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history_toggle_off,
                                    color: Colors.white24, size: 60),
                                const SizedBox(height: 15),
                                const Text("NO RECORDS FOUND",
                                    style: TextStyle(
                                        color: Colors.white30,
                                        letterSpacing: 2)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: history.length,
                            itemBuilder: (context, index) {
                              final item = history[index];

                              // Safe Data Access with defaults
                              final int score = item["score"] ?? 0;
                              final int total = item["total"] ?? 0;
                              final String date =
                                  item["quiz_date"] ?? "Unknown Date";

                              // Logic: Percentage Color
                              double percentage =
                                  total > 0 ? (score / total) : 0.0;

                              Color statusColor;
                              IconData statusIcon;

                              if (percentage >= 0.8) {
                                statusColor =
                                    const Color(0xFF00FF88); // Neon Green
                                statusIcon = Icons.check_circle;
                              } else if (percentage >= 0.5) {
                                statusColor = const Color(0xFFFFD700); // Gold
                                statusIcon = Icons.change_history;
                              } else {
                                statusColor =
                                    const Color(0xFFFF2A6D); // Neon Red
                                statusIcon = Icons.warning;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 15),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4))
                                  ],
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.05)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // COLORED STATUS STRIP
                                        Container(
                                          width: 6,
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            boxShadow: [
                                              BoxShadow(
                                                  color: statusColor
                                                      .withOpacity(0.5),
                                                  blurRadius: 10)
                                            ],
                                          ),
                                        ),

                                        // CONTENT
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 16),
                                            child: Row(
                                              children: [
                                                // LEFT: INFO
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .calendar_today,
                                                              color: Colors
                                                                  .white38,
                                                              size: 14),
                                                          const SizedBox(
                                                              width: 6),
                                                          Text(
                                                            date,
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      // Percentage Bar
                                                      LinearProgressIndicator(
                                                        value: percentage,
                                                        backgroundColor:
                                                            Colors.white10,
                                                        color: statusColor,
                                                        minHeight: 4,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(2),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                const SizedBox(width: 16),

                                                // RIGHT: SCORE BADGE
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: statusColor
                                                        .withOpacity(0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    border: Border.all(
                                                        color: statusColor
                                                            .withOpacity(0.3)),
                                                  ),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(statusIcon,
                                                          color: statusColor,
                                                          size: 20),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        "$score/$total",
                                                        style: TextStyle(
                                                            color: statusColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
