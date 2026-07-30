import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/summary_data.dart';

/// Контекст обсягу даних, що потрапив у звіт — щоб PDF був самодостатнім
/// документом, а не лише голими підсумковими числами.
class PdfReportMeta {
  final int divisions;
  final int buildings;
  final int floors;
  final int computerRooms;
  final int territories;

  const PdfReportMeta({
    required this.divisions,
    required this.buildings,
    required this.floors,
    required this.computerRooms,
    required this.territories,
  });
}

/// Формує друковану PDF-версію звіту-воронки (той самий розрахунок, що й
/// на екрані "Статистика": об'єкт — наявно/потреба) — для офіційної
/// звітності, а не для передачі даних між пристроями (для цього є CSV).
class PdfService {
  static Future<Uint8List> buildSummaryReport({
    required String scopeTitle,
    required List<FunnelTable> tables,
    required PdfReportMeta meta,
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
            pw.SizedBox(height: 6),
            pw.Text(
              'У межах звіту: управлінь — ${meta.divisions}, будівель — ${meta.buildings}, поверхів — ${meta.floors}, '
              'кабінетів з ПК — ${meta.computerRooms}, територій — ${meta.territories}.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
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
            if (table.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                margin: const pw.EdgeInsets.only(bottom: 12),
                decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Text(
                  'Дані відсутні в системі: ${table.emptyMessage}',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800, fontStyle: pw.FontStyle.italic),
                ),
              )
            else ...[
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(font: bold, fontSize: 9),
                cellStyle: const pw.TextStyle(fontSize: 9),
                textStyleBuilder: (columnIndex, data, rowNum) {
                  final isTotalRow = rowNum == 1;
                  final shortage = isTotalRow ? table.total.shortage : table.rows[rowNum - 2].shortage;
                  return pw.TextStyle(
                    fontSize: 9,
                    font: isTotalRow ? bold : regular,
                    color: shortage > 0 ? PdfColors.red800 : PdfColors.black,
                  );
                },
                headers: ['Об\'єкт', 'Наявно / Потреба'],
                data: [
                  [table.total.object, table.total.fractionLabel],
                  for (final row in table.rows) [row.object, row.fractionLabel],
                ],
              ),
              pw.SizedBox(height: 16),
            ],
          ],
        ],
      ),
    );

    return doc.save();
  }
}
