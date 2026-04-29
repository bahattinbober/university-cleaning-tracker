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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showFullImage(
          imageData,
          isUrl,
          roomName: roomName,
          cleanedAt: cleanedAt,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageWidget,
        ),
      ),
    );
  }

  void _showFullImage(
    String imageData,
    bool isUrl, {
    String? roomName,
    String? cleanedAt,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FullScreenImageViewer(
          imageData: imageData,
          isUrl: isUrl,
          roomName: roomName,
          cleanedAt: cleanedAt,
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
    final thumbnail = _buildThumbnail(
      rawImage,
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

class FullScreenImageViewer extends StatefulWidget {
  const FullScreenImageViewer({
    super.key,
    required this.imageData,
    required this.isUrl,
    this.roomName,
    this.cleanedAt,
  });

  final String imageData;
  final bool isUrl;
  final String? roomName;
  final String? cleanedAt;

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  final _transformController = TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.isUrl
        ? Image.network(widget.imageData, fit: BoxFit.contain)
        : Image.memory(
            base64Decode(widget.imageData.split(',').last),
            fit: BoxFit.contain,
          );

    final hasInfo = widget.roomName != null || widget.cleanedAt != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Temizlik Fotoğrafı'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          GestureDetector(
            onDoubleTap: _resetZoom,
            child: Center(
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.5,
                maxScale: 4.0,
                panEnabled: true,
                child: image,
              ),
            ),
          ),
          if (hasInfo)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                color: Colors.black.withValues(alpha: 0.7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.roomName != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.meeting_room,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.roomName!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      )
                    else
                      const SizedBox.shrink(),
                    if (widget.cleanedAt != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.cleanedAt!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
