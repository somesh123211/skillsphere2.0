import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

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

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CSV Picker Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AurumColors.backgroundBlack,
        colorScheme: const ColorScheme.dark(
          primary: AurumColors.accentGold,
          surface: AurumColors.surfaceDark,
        ),
      ),
      home: const CsvPickerTestPage(),
    );
  }
}

class CsvPickerTestPage extends StatefulWidget {
  const CsvPickerTestPage({super.key});

  @override
  State<CsvPickerTestPage> createState() => _CsvPickerTestPageState();
}

class _CsvPickerTestPageState extends State<CsvPickerTestPage> {
  String? _status = "No file selected";
  bool _isLoading = false;

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _status = "Picking file...";
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ["csv"],
        withData: true, // Crucial for Web & sometimes Mobile
      );

      print("RESULT OBJECT: $result");

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;

        print("FILE NAME: ${file.name}");
        print("FILE SIZE: ${file.size} bytes");

        setState(() {
          _status = "✅ Picked: ${file.name}\nSize: ${file.size} bytes";
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Success: ${file.name}"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _status = "⚠️ User canceled picker";
        });
        print("RESULT IS NULL OR EMPTY");
      }
    } catch (e) {
      setState(() {
        _status = "❌ Error: $e";
      });
      print("ERROR: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurumColors.backgroundBlack,
      appBar: AppBar(
        title: const Text("CSV Picker Debugger"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: AurumColors.textWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status Display Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AurumColors.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.description_outlined,
                        size: 40, color: AurumColors.textGrey),
                    const SizedBox(height: 16),
                    const Text(
                      "PICKER STATUS",
                      style: TextStyle(
                        color: AurumColors.accentGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _status ?? "Waiting...",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AurumColors.textWhite,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Test Button
              InkWell(
                onTap: _isLoading ? null : _pickFile,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: AurumColors.goldGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AurumColors.accentGold.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.touch_app, color: Colors.black),
                            SizedBox(width: 8),
                            Text(
                              "TEST CSV PICKER",
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
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
  }
}
