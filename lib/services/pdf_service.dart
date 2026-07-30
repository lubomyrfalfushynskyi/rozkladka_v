import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/summary_data.dart';

/// Формує друковану PDF-версію звіту-воронки (той самий розрахунок, що й
/// на екрані "Статистика": об'єкт/потреба/наявно/недостача) — для
/// офіційної звітності, а не для передачі даних між пристроями (для цього
/// є CSV).
class PdfService {
  static Future<Uint8List> buildSummaryReport({
    required String scopeTitle,
    required List<FunnelTable> tables,
  }) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));

    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final generatedAt = '${two(now.day)}.${two(now.month)}.${now.year} ${two(now.hour)}:${two(now.minute)}';
    final hasShortage = tables.any((t) => t.hasShortage);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Зведений звіт — $scopeTitle', style: pw.TextStyle(font: bold, fontSize: 18)),
            pw.Text('Сформовано: $generatedAt', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 12),
          ],
        ),
        build: (context) => [
          if (hasShortage)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              margin: const pw.EdgeInsets.only(bottom: 12),
              decoration: pw.BoxDecoration(
                color: PdfColors.red50,
                border: pw.Border.all(color: PdfColors.red200),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text('Виявлено недостачу — деталі в таблицях нижче', style: pw.TextStyle(font: bold, color: PdfColors.red900)),
            ),
          for (final table in tables) ...[
            pw.Text('${table.title}, ${table.unit}', style: pw.TextStyle(font: bold, fontSize: 13)),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(font: bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: ['Об\'єкт', 'Потреба', 'Наявно', 'Недостача'],
              data: [
                [
                  table.total.object,
                  _formatNumber(table.total.need),
                  _formatNumber(table.total.available),
                  _formatNumber(table.total.shortage),
                ],
                for (final row in table.rows)
                  [
                    row.object,
                    _formatNumber(row.need),
                    _formatNumber(row.available),
                    _formatNumber(row.shortage),
                  ],
              ],
            ),
            pw.SizedBox(height: 16),
          ],
        ],
      ),
    );

    return doc.save();
  }

  static String _formatNumber(num value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}
