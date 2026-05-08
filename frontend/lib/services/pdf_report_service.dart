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
}
