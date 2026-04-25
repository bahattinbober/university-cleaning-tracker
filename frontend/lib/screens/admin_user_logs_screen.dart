import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminUserLogsScreen extends StatefulWidget {
  const AdminUserLogsScreen({
    super.key,
    required this.userId,
    this.userName,
  });

  final int userId;
  final String? userName;

  @override
  State<AdminUserLogsScreen> createState() => _AdminUserLogsScreenState();
}

class _AdminUserLogsScreenState extends State<AdminUserLogsScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> logs = [];

  @override
  void initState() {
    super.initState();
    _fetchUserLogs();
  }

  Future<void> _fetchUserLogs() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        setState(() {
          errorMessage = 'Oturum bulunamadı, tekrar giriş yapınız.';
          isLoading = false;
        });
        return;
      }

      final url = Uri.parse(
        'http://10.0.2.2:4000/api/admin/user-logs/${widget.userId}',
      );
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body is Map<String, dynamic>
            ? (body['logs'] as List<dynamic>? ?? <dynamic>[])
            : <dynamic>[];
        setState(() {
          logs = data;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              'Kayıtlar alınamadı (kod: ${response.statusCode}).';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Bir hata oluştu: $e';
        isLoading = false;
      });
    }
  }

  Widget? _buildImagePreview(String? rawImage) {
    if (rawImage == null || rawImage.trim().isEmpty) return null;

    final imageData = rawImage.trim();
    final isUrl = imageData.startsWith('http://') || imageData.startsWith('https://');

    Widget imageWidget;
    if (isUrl) {
      imageWidget = Image.network(
        imageData,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
      );
    } else {
      try {
        imageWidget = Image.memory(
          base64Decode(imageData),
          width: 80,
          height: 80,
          fit: BoxFit.cover,
        );
      } catch (_) {
        return null;
      }
    }

    return GestureDetector(
      onTap: () => _showFullImage(imageData, isUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imageWidget,
      ),
    );
  }

  void _showFullImage(String imageData, bool isUrl) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.all(8),
            child: InteractiveViewer(
              child: isUrl
                  ? Image.network(imageData, fit: BoxFit.contain)
                  : Image.memory(base64Decode(imageData), fit: BoxFit.contain),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleName = widget.userName?.trim().isNotEmpty == true
        ? widget.userName
        : 'Kullanıcı #${widget.userId}';

    return Scaffold(
      appBar: AppBar(
        title: Text('$titleName Temizlik Kayıtları'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : logs.isEmpty
                  ? const Center(
                      child: Text('Bu kullanıcıya ait temizlik kaydı bulunamadı.'),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchUserLogs,
                      child: ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index] as Map<String, dynamic>;
                          final roomName = log['room_name']?.toString() ?? 'Oda';
                          final cleanedAt = log['cleaned_at']?.toString() ?? '-';
                          final notes = log['notes']?.toString() ?? '';
                          final imagePreview = _buildImagePreview(
                            log['image']?.toString(),
                          );

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          roomName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('Tarih: $cleanedAt'),
                                        if (notes.trim().isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text('Not: $notes'),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (imagePreview != null) ...[
                                    const SizedBox(width: 12),
                                    imagePreview,
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
