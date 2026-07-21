import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SignupPage extends StatefulWidget {
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  final String baseUrl = "http://localhost:5000";
  bool loading = false;

  Future<void> signup() async {
    setState(() => loading = true);

    final response = await http.post(
      Uri.parse("$baseUrl/api/admin/signup"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": nameCtrl.text.trim(),
        "email": emailCtrl.text.trim(),
        "password": passCtrl.text.trim(),
      }),
    );

    setState(() => loading = false);

    final data = jsonDecode(response.body);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(data["message"] ?? data["error"])),
    );

    if (response.statusCode == 201) {
      Navigator.pop(context); // back to login
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Signup")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : signup,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Signup"),
            ),
          ],
        ),
      ),
    );
  }
}
