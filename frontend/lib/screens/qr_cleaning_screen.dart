import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QRCleaningScreen extends StatefulWidget {
  const QRCleaningScreen({super.key});

  @override
  State<QRCleaningScreen> createState() => _QRCleaningScreenState();
}

class _QRCleaningScreenState extends State<QRCleaningScreen> {
  bool isProcessing = false;
  bool hasNavigatedToForm = false;
  String? lastMessage;

  Future<void> _handleCode(String? rawValue, [BarcodeType? _]) async {
    await _openFormAfterScan(rawValue);
  }

  Future<void> _openFormAfterScan(String? rawValue) async {
    if (rawValue == null || isProcessing || hasNavigatedToForm) return;

    setState(() {
      isProcessing = true;
      lastMessage = null;
    });

    int? roomId;
    try {
      roomId = int.parse(rawValue.trim());
    } catch (_) {
      setState(() {
        lastMessage =
            'QR beklenen formatta değil (sadece oda ID olmalı). Okunan: $rawValue';
        isProcessing = false;
      });
      return;
    }

    setState(() {
      hasNavigatedToForm = true;
      isProcessing = false;
    });

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CleaningLogFormScreen(roomId: roomId!)),
    );

    if (!mounted) return;
    setState(() {
      hasNavigatedToForm = false;
      lastMessage = 'Yeni kayıt için tekrar QR okutabilirsiniz.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR ile Temizlik Kaydı')),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: MobileScanner(
              onDetect: (capture) {
                final barcode = capture.barcodes.first;
                _handleCode(barcode.rawValue, barcode.type);
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              color: Colors.grey[100],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isProcessing)
                    const Center(child: CircularProgressIndicator())
                  else
                    const Text(
                      'Bir oda QR kodunu kameraya gösterin.\nQR içeriği oda ID olmalı (örnek: 1, 2, 3 ...)',
                    ),
                  const SizedBox(height: 12),
                  if (lastMessage != null)
                    Text(
                      lastMessage!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    // Geçici test butonu: QR okutulmuş gibi room_id=1 ile akışı tetikler.
                    child: ElevatedButton(
                      onPressed: () async {
                        await _handleCode('1');
                      },
                      child: const Text('Test için Oda 1 kaydı oluştur'),
                    ),
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

class CleaningLogFormScreen extends StatefulWidget {
  const CleaningLogFormScreen({super.key, required this.roomId});

  final int roomId;

  @override
  State<CleaningLogFormScreen> createState() => _CleaningLogFormScreenState();
}

class _CleaningLogFormScreenState extends State<CleaningLogFormScreen> {
  final TextEditingController notesController = TextEditingController();
  final ImagePicker picker = ImagePicker();

  bool isSubmitting = false;
  bool isLoadingRoomName = true;
  String roomName = '';
  String userName = '';
  int? userId;
  String? token;
  File? pickedImage;

  @override
  void initState() {
    super.initState();
    _prepareForm();
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  Future<void> _prepareForm() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token');

    setState(() {
      token = savedToken;
      userName = prefs.getString('userName') ?? '';
      userId = prefs.getInt('userId');
    });

    await _loadRoomName();
  }

  Future<void> _loadRoomName() async {
    if (token == null) {
      setState(() {
        roomName = 'Oda #${widget.roomId}';
        isLoadingRoomName = false;
      });
      return;
    }

    try {
      final url = Uri.parse('http://10.0.2.2:4000/api/rooms');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final rooms = jsonDecode(response.body) as List<dynamic>;
        final found = rooms.cast<Map<String, dynamic>>().firstWhere(
          (room) => room['id'] == widget.roomId,
          orElse: () => <String, dynamic>{},
        );

        setState(() {
          roomName = (found['name'] as String?) ?? 'Oda #${widget.roomId}';
          isLoadingRoomName = false;
        });
      } else {
        setState(() {
          roomName = 'Oda #${widget.roomId}';
          isLoadingRoomName = false;
        });
      }
    } catch (_) {
      setState(() {
        roomName = 'Oda #${widget.roomId}';
        isLoadingRoomName = false;
      });
    }
  }

  Future<void> _pickPhoto() async {
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
    );
    if (image == null) return;

    setState(() {
      pickedImage = File(image.path);
    });
  }

  Future<String?> _imageToBase64() async {
    if (pickedImage == null) return null;
    final bytes = await pickedImage!.readAsBytes();
    return base64Encode(bytes);
  }

  Future<void> _submitCleaningLog() async {
    if (isSubmitting) return;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oturum bulunamadı, tekrar giriş yapınız.'),
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final imageBase64 = await _imageToBase64();
      final url = Uri.parse('http://10.0.2.2:4000/api/cleaning-logs');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': userId,
          'room_id': widget.roomId,
          'status': 'completed',
          'notes': notesController.text.trim(),
          'image': imageBase64,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Temizlik kaydı başarıyla eklendi.')),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        String message = 'Kayıt oluşturulamadı (Kod: ${response.statusCode})';
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
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Temizlik Kaydı')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Oda Adı',
                border: const OutlineInputBorder(),
                hintText: isLoadingRoomName ? 'Yükleniyor...' : roomName,
              ),
              controller: TextEditingController(
                text: isLoadingRoomName ? '' : roomName,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Kullanıcı Adı',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: userName),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(
                pickedImage == null ? 'Fotoğraf Ekle' : 'Fotoğraf Seçildi',
              ),
            ),
            if (pickedImage != null) ...[
              const SizedBox(height: 8),
              Text(
                pickedImage!.path.split(Platform.pathSeparator).last,
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Not',
                hintText: 'İsteğe bağlı not ekleyin',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _submitCleaningLog,
                child: isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Temizlik Yapıldı'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
