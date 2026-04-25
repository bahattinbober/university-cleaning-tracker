import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminScheduledTaskScreen extends StatefulWidget {
  const AdminScheduledTaskScreen({super.key});

  @override
  State<AdminScheduledTaskScreen> createState() =>
      _AdminScheduledTaskScreenState();
}

class _AdminScheduledTaskScreenState extends State<AdminScheduledTaskScreen> {
  final TextEditingController roomIdController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController scheduledForController = TextEditingController();
  final TextEditingController assignedUserIdController =
      TextEditingController();

  bool isSubmitting = false;

  @override
  void dispose() {
    roomIdController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    scheduledForController.dispose();
    assignedUserIdController.dispose();
    super.dispose();
  }

  Future<void> _createScheduledTask() async {
    final roomId = int.tryParse(roomIdController.text.trim());
    final title = titleController.text.trim();
    final scheduledFor = scheduledForController.text.trim();
    final assignedUserIdText = assignedUserIdController.text.trim();
    final assignedUserId = assignedUserIdText.isEmpty
        ? null
        : int.tryParse(assignedUserIdText);

    if (roomId == null || title.isEmpty || scheduledFor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('room_id, başlık ve planlanan zaman zorunlu'),
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oturum bulunamadı, tekrar giriş yapınız.'),
          ),
        );
        return;
      }

      final response = await http.post(
        Uri.parse('http://10.0.2.2:4000/api/admin/scheduled-tasks'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'room_id': roomId,
          'title': title,
          'description': descriptionController.text.trim(),
          'scheduled_for': scheduledFor,
          'assigned_user_id': assignedUserId,
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Planlı görev oluşturuldu')),
        );
        Navigator.pop(context);
      } else {
        String message = 'Görev oluşturulamadı (Kod: ${response.statusCode})';
        try {
          final body = jsonDecode(response.body);
          if (body is Map<String, dynamic> && body['message'] != null) {
            message = body['message'] as String;
          }
        } catch (_) {}
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Bir hata oluştu: $e')));
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planlı Görev Oluştur')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: roomIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Oda ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Başlık',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: scheduledForController,
              decoration: const InputDecoration(
                labelText: 'Planlanan Tarih/Saat',
                hintText: '2026-03-24 14:30:00',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: assignedUserIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Atanacak Kullanıcı ID (opsiyonel)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _createScheduledTask,
                child: isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Görev Oluştur'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
