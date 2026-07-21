import 'package:flutter/material.dart';
import 'login_signup_page.dart';
import 'student_dashboard.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skill Sphere',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const LoginSignupPage(),
      routes: {
        // You can define named routes if needed later
      },
    );
  }
}
