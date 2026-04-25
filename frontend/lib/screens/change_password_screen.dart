import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isLoading = false;

  Future<void> _changePassword() async {
    final oldPassword = oldPasswordController.text.trim();
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar('Tüm alanlar zorunludur');
      return;
    }
    if (newPassword.length < 8) {
      _showSnackBar('Yeni şifre en az 8 karakter olmalı');
      return;
    }
    if (newPassword != confirmPassword) {
      _showSnackBar('Yeni şifreler eşleşmiyor');
      return;
    }
    if (oldPassword == newPassword) {
      _showSnackBar('Yeni şifre eskisinden farklı olmalı');
      return;
    }

    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    try {
      final response = await http.put(
        Uri.parse('http://10.0.2.2:4000/api/auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        }),
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        await prefs.remove('token');
        await prefs.remove('userName');
        await prefs.remove('userRole');
        await prefs.remove('userId');

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şifre değiştirildi. Lütfen tekrar giriş yapın.')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        String message = 'Şifre değiştirilemedi';
        try {
          final body = jsonDecode(response.body);
          if (body is Map<String, dynamic> && body['message'] != null) {
            message = body['message'] as String;
          }
        } catch (_) {}
        _showSnackBar(message);
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar('Bir hata oluştu: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Şifre Değiştir'),
        backgroundColor: Colors.grey[100],
      ),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          width: 320,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Şifre Değiştir',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: oldPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Eski Şifre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Yeni Şifre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Yeni Şifre Tekrar',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _changePassword,
                  child: isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Şifreyi Değiştir'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
