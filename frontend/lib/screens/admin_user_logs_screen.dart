import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/translations.dart';
import '../widgets/empty_state.dart';

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

  static const _months = [
    '',
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

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

      final response = await http.get(
        Uri.parse(
          'http://10.0.2.2:4000/api/admin/user-logs/${widget.userId}',
        ),
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
          errorMessage = 'Kayıtlar alınamadı (kod: ${response.statusCode}).';
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

  // "2026-04-25 09:30:00" → "25 Nisan 2026 - 09:30"
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

  Widget? _buildThumbnail(String? rawImage) {
    if (rawImage == null || rawImage.trim().isEmpty) return null;
    final imageData = rawImage.trim();
    final isUrl =
        imageData.startsWith('http://') || imageData.startsWith('https://');

    Widget imageWidget;
    if (isUrl) {
      imageWidget = Image.network(
        imageData,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
      );
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
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          color: Colors.black,
          padding: const EdgeInsets.all(8),
          child: InteractiveViewer(
            child: isUrl
                ? Image.network(imageData, fit: BoxFit.contain)
                : Image.memory(
                    base64Decode(imageData.split(',').last),
                    fit: BoxFit.contain,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(String name) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.heading2),
                if (logs.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${logs.length} kayıt',
                    style: AppTextStyles.caption,
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.assignment, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _logCard(Map<String, dynamic> log) {
    final roomName = log['room_name']?.toString() ?? 'Oda';
    final cleanedAt = _formatDate(log['cleaned_at']?.toString());
    final notes = log['notes']?.toString() ?? '';
    final hasNotes = notes.trim().isNotEmpty;
    final rawImage = log['image']?.toString();
    final hasImage = rawImage != null && rawImage.trim().isNotEmpty;
    // status bu endpoint'ten dönmüyor; tüm kayıtlar 'completed' olduğundan fallback.
    final status = log['status']?.toString() ?? 'completed';
    final statusLabel = StatusTranslator.cleaningStatus(status);
    final thumbnail = _buildThumbnail(rawImage);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.staffAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.cleaning_services,
                color: AppColors.staffAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$roomName  —  $statusLabel',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(cleanedAt, style: AppTextStyles.caption),
                  if (hasNotes) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.note_alt,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            notes,
                            style: AppTextStyles.caption.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (hasImage) ...[
                    const SizedBox(height: AppSpacing.xs),
                    const Row(
                      children: [
                        Icon(
                          Icons.photo,
                          size: 12,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Fotoğraflı',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.success,
                          ),
                        ),
                      ],
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
  }

  @override
  Widget build(BuildContext context) {
    final titleName = widget.userName?.trim().isNotEmpty == true
        ? widget.userName!
        : 'Kullanıcı #${widget.userId}';

    return Scaffold(
      appBar: AppBar(
        title: Text('$titleName - Kayıtlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUserLogs,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchUserLogs,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _summaryCard(titleName)),
                      if (logs.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyState(
                            icon: Icons.history_outlined,
                            title: 'Henüz Kayıt Yok',
                            message:
                                '$titleName için temizlik kaydı bulunmuyor.',
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, index) => _logCard(
                                logs[index] as Map<String, dynamic>,
                              ),
                              childCount: logs.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
