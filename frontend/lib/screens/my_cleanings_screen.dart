import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../utils/translations.dart';
import 'admin_user_logs_screen.dart' show FullScreenImageViewer;

class MyCleaningsScreen extends StatefulWidget {
  const MyCleaningsScreen({super.key});

  @override
  State<MyCleaningsScreen> createState() => _MyCleaningsScreenState();
}

class _MyCleaningsScreenState extends State<MyCleaningsScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> logs = [];

  static const _months = [
    '',
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  @override
  void initState() {
    super.initState();
    _fetchMyLogs();
  }

  Future<void> _fetchMyLogs() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        setState(() { errorMessage = 'Oturum bulunamadı, tekrar giriş yapınız.'; isLoading = false; });
        return;
      }

      final response = await http.get(
        Uri.parse('http://192.168.1.27:4000/api/cleaning/my'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() { logs = jsonDecode(response.body) as List; isLoading = false; });
      } else {
        setState(() { errorMessage = 'Kayıtlar alınamadı (kod: ${response.statusCode}).'; isLoading = false; });
      }
    } catch (e) {
      setState(() { errorMessage = 'Bir hata oluştu: $e'; isLoading = false; });
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw.trim().replaceAll(' ', 'T'));
      final day = dt.day.toString().padLeft(2, '0');
      final month = _months[dt.month];
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day $month ${dt.year} - $hour:$minute';
    } catch (_) {
      return raw.trim();
    }
  }

  Widget? _buildThumbnail(
    String? rawImage, {
    String? roomName,
    String? cleanedAt,
  }) {
    if (rawImage == null || rawImage.trim().isEmpty) return null;
    final imageData = rawImage.trim();
    final isUrl =
        imageData.startsWith('http://') || imageData.startsWith('https://');

    Widget imageWidget;
    if (isUrl) {
      imageWidget = Image.network(imageData, width: 50, height: 50, fit: BoxFit.cover);
    } else {
      try {
        imageWidget = Image.memory(
          base64Decode(imageData.split(',').last),
          width: 50,
          height: 50,
          fit: BoxFit.cover,
        );
      } catch (_) {
        return null;
      }
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => FullScreenImageViewer(
              imageData: imageData,
              isUrl: isUrl,
              roomName: roomName,
              cleanedAt: cleanedAt,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageWidget,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Temizlik Kayıtlarım')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : logs.isEmpty
                  ? const EmptyState(
                      icon: Icons.cleaning_services_outlined,
                      title: 'Henüz Kayıt Yok',
                      message: 'Temizlik kaydı eklendiğinde burada görünecek.',
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchMyLogs,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          final roomName = log['room_name']?.toString() ?? 'Oda';
                          final status = StatusTranslator.cleaningStatus(
                            log['status']?.toString(),
                          );
                          final notes = log['notes']?.toString() ?? '';
                          final cleanedAt = _formatDate(log['cleaned_at']?.toString());
                          final thumbnail = _buildThumbnail(
                            log['image']?.toString(),
                            roomName: roomName,
                            cleanedAt: cleanedAt,
                          );

                          return Card(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.staffAccent
                                        .withValues(alpha: 0.15),
                                    child: const Icon(
                                      Icons.check_circle_outline,
                                      color: AppColors.staffAccent,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$roomName — $status',
                                          style: AppTextStyles.body.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          cleanedAt,
                                          style: AppTextStyles.caption,
                                        ),
                                        if (notes.isNotEmpty) ...[
                                          const SizedBox(height: AppSpacing.xs),
                                          Text(
                                            notes,
                                            style: AppTextStyles.caption
                                                .copyWith(
                                              fontStyle: FontStyle.italic,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (thumbnail != null) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    thumbnail,
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
