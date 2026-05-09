import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfReportService {
  /// KPI verisinden A4 dikey performans raporu üretir.
  /// Türkçe karakter desteği için Google Fonts (NotoSans) kullanılır.
  static Future<List<int>> generate(Map<String, dynamic> kpiData) async {
    final pdf = pw.Document();

    final logoBytes =
        await rootBundle.load('assets/images/pau-logo.png');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
    );

    final user = kpiData['user'] as Map<String, dynamic>;
    final score = kpiData['overall_score'] as int;
    final grade = kpiData['grade'] as String;
    final level = kpiData['level'] as Map<String, dynamic>;
    final components = kpiData['components'] as Map<String, dynamic>;
    final stats = kpiData['stats'] as Map<String, dynamic>;
    final benchmark = kpiData['benchmark'] as Map<String, dynamic>;
    final achievements =
        kpiData['achievements'] as Map<String, dynamic>;
    final recommendations = kpiData['recommendations'] as List;

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // BAŞLIK
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 70,
                height: 70,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PAMUKKALE UNIVERSITESI',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Muhendislik Fakultesi - Bilgisayar Muhendisligi',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(height: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'PERSONEL PERFORMANS DEGERLENDIRME RAPORU',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          // KULLANICI BİLGİSİ
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _kvRow('Kullanici', user['name']?.toString() ?? '-'),
                    _kvRow('E-posta', user['email']?.toString() ?? '-'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _kvRow('Rapor Tarihi', dateStr),
                    _kvRow('Donem', 'Son 7 Gun'),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // GENEL SKOR
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border:
                  pw.Border.all(color: PdfColors.grey400, width: 1),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'GENEL PERFORMANS SKORU',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      '$score',
                      style: pw.TextStyle(
                        fontSize: 48,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      ' / 100',
                      style: pw.TextStyle(
                        fontSize: 18,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    _badge('Not: $grade'),
                    pw.SizedBox(width: 12),
                    _badge('Seviye: ${level['name']}'),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // 4 BİLEŞEN
          _sectionTitle('4 BILESEN ANALIZI - BALANCED SCORECARD'),
          pw.SizedBox(height: 8),
          _componentTable(components),

          pw.SizedBox(height: 16),

          // KARŞILAŞTIRMA
          _sectionTitle('KARSILASTIRMA VE HEDEF'),
          pw.SizedBox(height: 8),
          _benchmarkTable(stats, benchmark),

          pw.SizedBox(height: 16),

          // GELİŞİM ÖNERİLERİ
          _sectionTitle('GELISIM ONERILERI'),
          pw.SizedBox(height: 8),
          ...recommendations.map((r) {
            final rec = r as Map<String, dynamic>;
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    rec['title']?.toString() ?? '',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    rec['message']?.toString() ?? '',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            );
          }),

          pw.SizedBox(height: 16),

          // BAŞARI GÖSTERGELERİ
          _sectionTitle(
              'BASARI GOSTERGELERI (${achievements['completed_count']}/${achievements['total_count']})'),
          pw.SizedBox(height: 8),
          _achievementGrid(achievements['items'] as List),

          pw.SizedBox(height: 24),

          // İMZA ALANI
          pw.Row(
            children: [
              pw.Expanded(child: _signatureBox('Personel')),
              pw.SizedBox(width: 20),
              pw.Expanded(child: _signatureBox('Yonetici')),
            ],
          ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Sayfa ${context.pageNumber} / ${context.pagesCount}  |  PAU Temizlik Takip Sistemi',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
            ),
          ),
        ),
      ),
    );

    return pdf.save();
  }

  // ── Helpers ────────────────────────────────────────────────────

  static pw.Widget _kvRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Text(
            '$label: ',
            style: pw.TextStyle(
                fontSize: 9, color: PdfColors.grey700),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _badge(String text) {
    return pw.Container(
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey800,
        ),
      ),
    );
  }

  static pw.Widget _sectionTitle(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(
          vertical: 4, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey800,
        borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static pw.Widget _componentTable(
      Map<String, dynamic> components) {
    final items = [
      {'name': 'Verimlilik', 'weight': 40, 'key': 'productivity'},
      {'name': 'Kalite', 'weight': 30, 'key': 'quality'},
      {'name': 'Zamanlama', 'weight': 20, 'key': 'timeliness'},
      {'name': 'Uyumluluk', 'weight': 10, 'key': 'compliance'},
    ];

    return pw.Table(
      border:
          pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration:
              const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableHeader('Bilesen'),
            _tableHeader('Agirlik'),
            _tableHeader('Skor'),
            _tableHeader('Gorsel'),
          ],
        ),
        ...items.map((item) {
          final comp =
              components[item['key']] as Map<String, dynamic>?;
          final value = comp?['value'] as int? ?? 0;
          return pw.TableRow(
            children: [
              _tableCell(item['name'] as String),
              _tableCell('%${item['weight']}'),
              _tableCell('$value / 100', bold: true),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: _bar(value),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
            fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _tableCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight:
              bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _bar(int value) {
    final barColor = value >= 70
        ? PdfColors.green600
        : value >= 40
            ? PdfColors.orange600
            : PdfColors.red600;
    return pw.Stack(
      children: [
        pw.Container(
          height: 8,
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
        ),
        pw.Container(
          height: 8,
          width: value.clamp(0, 100).toDouble(),
          decoration: pw.BoxDecoration(
            color: barColor,
            borderRadius: const pw.BorderRadius.all(
                pw.Radius.circular(4)),
          ),
        ),
      ],
    );
  }

  static pw.Widget _benchmarkTable(Map<String, dynamic> stats,
      Map<String, dynamic> benchmark) {
    final targetVal = benchmark['target'];
    final targetCompletion = benchmark['target_completion'];

    return pw.Table(
      border:
          pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(children: [
          _tableCell('Kullanici kayitlari'),
          _tableCell('${stats['total']}', bold: true),
        ]),
        pw.TableRow(children: [
          _tableCell('Sistem ortalamasi'),
          _tableCell('${benchmark['system_average_records']}'),
        ]),
        pw.TableRow(children: [
          _tableCell('Atanan haftalik hedef'),
          _tableCell(
            targetVal != null ? '$targetVal kayit' : 'Atanmamis',
            bold: true,
          ),
        ]),
        if (targetCompletion != null)
          pw.TableRow(
            decoration:
                const pw.BoxDecoration(color: PdfColors.grey100),
            children: [
              _tableCell('Hedef tamamlama orani', bold: true),
              _tableCell('%$targetCompletion', bold: true),
            ],
          ),
      ],
    );
  }

  static pw.Widget _achievementGrid(List items) {
    final rows = <pw.TableRow>[];
    for (var i = 0; i < items.length; i += 2) {
      final left = items[i] as Map<String, dynamic>;
      final right =
          i + 1 < items.length ? items[i + 1] as Map<String, dynamic> : null;
      rows.add(pw.TableRow(children: [
        _achievementCell(left),
        right != null ? _achievementCell(right) : pw.Container(),
      ]));
    }

    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(1),
      },
      children: rows,
    );
  }

  static pw.Widget _achievementCell(Map<String, dynamic> item) {
    final completed = item['completed'] as bool? ?? false;
    final progress = item['progress'] as int? ?? 0;

    return pw.Container(
      margin: const pw.EdgeInsets.all(2),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: completed ? PdfColors.blue50 : PdfColors.grey100,
        borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(
          color: completed ? PdfColors.blue200 : PdfColors.grey300,
          width: 0.5,
        ),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 14,
            height: 14,
            decoration: pw.BoxDecoration(
              color: completed
                  ? PdfColors.blue600
                  : PdfColors.grey400,
              shape: pw.BoxShape.circle,
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              completed ? 'OK' : '...',
              style: pw.TextStyle(
                fontSize: 6,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  item['name']?.toString() ?? '',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
                pw.Text(
                  completed ? 'Tamamlandi' : '%$progress',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: completed
                        ? PdfColors.blue600
                        : PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _signatureBox(String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          height: 50,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(
                  color: PdfColors.grey600, width: 0.5),
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: pw.TextStyle(
              fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Ad-Soyad / Imza / Tarih',
          style: pw.TextStyle(
              fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    );
  }

  // ── Envanter PDF ─────────────────────────────────────────────────────────

  static Future<void> generateInventoryReport({
    required List<Map<String, dynamic>> inventoryItems,
    required Map<String, dynamic> abcData,
  }) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final logoBytes =
        await rootBundle.load('assets/images/pau-logo.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

    final normalCount = inventoryItems
        .where((i) => i['alert_level'] == 'normal')
        .length;
    final reorderCount = inventoryItems
        .where((i) => i['alert_level'] == 'reorder')
        .length;
    final criticalCount = inventoryItems
        .where((i) =>
            i['alert_level'] == 'critical' ||
            i['alert_level'] == 'depleted')
        .length;
    final orderItems = inventoryItems
        .where((i) =>
            i['alert_level'] == 'reorder' ||
            i['alert_level'] == 'critical' ||
            i['alert_level'] == 'depleted')
        .toList();
    final abcItems =
        (abcData['items'] as List).cast<Map<String, dynamic>>();
    final abcSummary = abcData['summary'] as Map<String, dynamic>;

    final theme = pw.ThemeData.withFont(base: font, bold: fontBold);

    // ─── SAYFA 1 ───────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Başlık + Logo
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                    width: 60,
                    height: 60,
                    child: pw.Image(logoImage)),
                pw.SizedBox(width: 15),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Stok Envanter Raporu',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Pamukkale Universitesi - Bilgisayar Muhendisligi',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Tarih: $dateStr',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Surum: 1.0',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.blue700),
            pw.SizedBox(height: 15),

            // Özet
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Genel Ozet',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      _invSummaryBox('Toplam',
                          '${inventoryItems.length}', PdfColors.blue700),
                      pw.SizedBox(width: 8),
                      _invSummaryBox(
                          'Normal', '$normalCount', PdfColors.green700),
                      pw.SizedBox(width: 8),
                      _invSummaryBox('Siparis', '$reorderCount',
                          PdfColors.orange700),
                      pw.SizedBox(width: 8),
                      _invSummaryBox(
                          'Kritik', '$criticalCount', PdfColors.red700),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 15),

            // ABC başlık
            pw.Text(
              'ABC Analizi (Pareto)',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            pw.Text(
              'Son 30 gun kullanim hacmine gore siniflandirma',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 8),

            // ABC kutuları
            pw.Row(
              children: [
                _invAbcBox(
                    'A',
                    '${abcSummary['a_count']} kalem',
                    '%${abcSummary['a_percentage']}',
                    PdfColors.red700),
                pw.SizedBox(width: 8),
                _invAbcBox(
                    'B',
                    '${abcSummary['b_count']} kalem',
                    '%${abcSummary['b_percentage']}',
                    PdfColors.orange700),
                pw.SizedBox(width: 8),
                _invAbcBox(
                    'C',
                    '${abcSummary['c_count']} kalem',
                    '%${abcSummary['c_percentage']}',
                    PdfColors.green700),
              ],
            ),
            pw.SizedBox(height: 12),

            // ABC tablosu (top 10)
            pw.Text(
              'En Cok Kullanilan 10 Kalem',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            _invAbcTable(abcItems.take(10).toList()),
          ],
        ),
      ),
    );

    // ─── SAYFA 2 ───────────────────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: theme,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Stok Envanter Raporu - Sayfa 2',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(dateStr,
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),

            // Sipariş önerileri (varsa)
            if (orderItems.isNotEmpty) ...[
              pw.Text(
                'Siparis Onerileri (Wilson EOQ)',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange800,
                ),
              ),
              pw.SizedBox(height: 6),
              _invOrderTable(orderItems),
              pw.SizedBox(height: 15),
            ],

            // EOQ tablosu
            pw.Text(
              'Optimum Siparis Miktari (Wilson EOQ)',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.purple800,
              ),
            ),
            pw.SizedBox(height: 6),
            _invEoqTable(inventoryItems
                .where((i) => (i['eoq_optimal_order'] as num? ?? 0) > 0)
                .toList()),
            pw.SizedBox(height: 12),

            // Tüm stok tablosu
            pw.Text(
              'Tum Stok Kalemleri',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            pw.SizedBox(height: 6),
            _invAllStockTable(inventoryItems),
            pw.Spacer(),

            // Akademik referanslar
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Akademik Dayanaklar',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '- Pareto, V. (1906) - ABC Siniflandirmasi\n'
                    '- Wilson, R. H. (1934) - Reorder Point Modeli\n'
                    '- ISO 9001:2015 - Envanter Yonetim Standartlari',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // İmza
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                        width: 150, height: 1, color: PdfColors.grey),
                    pw.SizedBox(height: 3),
                    pw.Text('Hazirlayan',
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                        width: 150, height: 1, color: PdfColors.grey),
                    pw.SizedBox(height: 3),
                    pw.Text('Onaylayan',
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'stok-envanter-raporu-$dateStr.pdf',
    );
  }

  // ── Envanter PDF Helpers ──────────────────────────────────────────────────

  static pw.Widget _invSummaryBox(
      String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius:
              const pw.BorderRadius.all(pw.Radius.circular(4)),
          border: pw.Border.all(color: color, width: 1.5),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
            pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _invAbcBox(
      String cls, String count, String pct, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          border: pw.Border(
            left: pw.BorderSide(color: color, width: 3),
          ),
        ),
        child: pw.Row(
          children: [
            pw.Container(
              width: 30,
              height: 30,
              decoration: pw.BoxDecoration(
                color: color,
                borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4)),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                cls,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  count,
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(pct,
                    style: pw.TextStyle(fontSize: 10, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _invAbcTable(List<Map<String, dynamic>> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(30),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(2),
        3: pw.FixedColumnWidth(50),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _invTh('Sinif'),
            _invTh('Urun'),
            _invTh('Kullanim'),
            _invTh('Yuzde'),
          ],
        ),
        ...items.map((item) {
          final cls = item['abc_class']?.toString() ?? 'C';
          PdfColor color = PdfColors.green700;
          if (cls == 'A') color = PdfColors.red700;
          if (cls == 'B') color = PdfColors.orange700;
          return pw.TableRow(
            children: [
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(4),
                color: color,
                child: pw.Text(
                  cls,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              _invTd(item['name']?.toString() ?? '-'),
              _invTd(
                  '${item['total_usage']} ${item['unit'] ?? ''}'),
              _invTd('%${item['percentage']}'),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _invOrderTable(List<Map<String, dynamic>> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration:
              const pw.BoxDecoration(color: PdfColors.orange100),
          children: [
            _invTh('Urun'),
            _invTh('Mevcut'),
            _invTh('ROP'),
            _invTh('Onerilen'),
          ],
        ),
        ...items.map(
          (item) => pw.TableRow(
            children: [
              _invTd(item['name']?.toString() ?? '-'),
              _invTd(
                  '${item['current_amount']} ${item['unit'] ?? ''}'),
              _invTd(
                  '${item['reorder_point'] ?? '-'} ${item['unit'] ?? ''}'),
              _invTd(
                  '${item['suggested_order'] ?? '-'} ${item['unit'] ?? ''}'),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _invAllStockTable(
      List<Map<String, dynamic>> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration:
              const pw.BoxDecoration(color: PdfColors.blue100),
          children: [
            _invTh('Urun'),
            _invTh('Mevcut'),
            _invTh('Min'),
            _invTh('Durum'),
          ],
        ),
        ...items.map((item) {
          final lvl = item['alert_level']?.toString() ?? 'normal';
          String label = 'Normal';
          PdfColor color = PdfColors.green700;
          if (lvl == 'depleted') {
            label = 'Tukendi';
            color = PdfColors.grey700;
          } else if (lvl == 'critical') {
            label = 'Kritik';
            color = PdfColors.red700;
          } else if (lvl == 'reorder') {
            label = 'Siparis';
            color = PdfColors.orange700;
          }
          return pw.TableRow(
            children: [
              _invTd(item['name']?.toString() ?? '-'),
              _invTd(
                  '${item['current_amount']} ${item['unit'] ?? ''}'),
              _invTd(
                  '${item['min_threshold']} ${item['unit'] ?? ''}'),
              pw.Container(
                padding: const pw.EdgeInsets.all(3),
                alignment: pw.Alignment.center,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: color,
                    borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(3)),
                  ),
                  child: pw.Text(
                    label,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _invEoqTable(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Text(
          'Henuz tuketim verisi olmayan kalemler icin EOQ hesaplanamaz.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      );
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.purple100),
          children: [
            _invTh('Urun'),
            _invTh('Q* (EOQ)'),
            _invTh('Yillik Tal.'),
            _invTh('Sip. Aralik'),
          ],
        ),
        ...items.map(
          (item) => pw.TableRow(
            children: [
              _invTd(item['name']?.toString() ?? '-'),
              _invTd('${item['eoq_optimal_order']} ${item['unit'] ?? ''}'),
              _invTd('${item['annual_demand']} ${item['unit'] ?? ''}'),
              _invTd('${item['days_between_orders'] ?? '-'} gun'),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _invTh(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
            fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _invTd(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child:
          pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }
}
