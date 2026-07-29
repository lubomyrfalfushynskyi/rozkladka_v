import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/summary_data.dart';

/// Формує друковану PDF-версію зведеного звіту (той самий розрахунок, що й
/// на екрані "Статистика") — для офіційної звітності, а не для передачі
/// даних між пристроями (для цього є CSV).
class PdfService {
  static Future<Uint8List> buildSummaryReport({
    required String scopeTitle,
    required SummaryTotals totals,
    required List<FloorSummaryEntry> floorEntries,
    required List<TerritorySummaryEntry> territoryEntries,
  }) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));

    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final generatedAt = '${two(now.day)}.${two(now.month)}.${now.year} ${two(now.hour)}:${two(now.minute)}';

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
          if (totals.hasShortage)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              margin: const pw.EdgeInsets.only(bottom: 12),
              decoration: pw.BoxDecoration(
                color: PdfColors.red50,
                border: pw.Border.all(color: PdfColors.red200),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Виявлено недостачу', style: pw.TextStyle(font: bold, color: PdfColors.red900)),
                  if (totals.totalShortageLiters > 0)
                    pw.Text(
                      'Бракує вогнегасної речовини (загальні приміщення): '
                      '${_formatNumber(totals.totalShortageLiters)} од.',
                    ),
                  if (totals.totalMissingRoomExtinguishers > 0)
                    pw.Text('Бракує вогнегасників ВВК у кабінетах з ПК: ${totals.totalMissingRoomExtinguishers} шт.'),
                ],
              ),
            ),
          pw.Text('Загалом по будівлях', style: pw.TextStyle(font: bold, fontSize: 13)),
          pw.SizedBox(height: 4),
          pw.Text('Вогнегасна речовина (звичайні приміщення): ${_formatNumber(totals.totalLiters)} л'),
          pw.Text('Вогнегасники для кабінетів з ПК (за нормою):'),
          if (totals.extinguisherCounts.isEmpty) pw.Text('  — немає кабінетів з ПК'),
          for (final entry in totals.extinguisherCounts.entries) pw.Text('  • ${entry.value} шт. — ${entry.key}'),
          pw.SizedBox(height: 16),
          if (territoryEntries.isNotEmpty) ...[
            pw.Text('Територія (ТВУЗ)', style: pw.TextStyle(font: bold, fontSize: 13)),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(font: bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: ['Управління', 'Територія', 'Площа, м²', 'Потрібно щитів'],
              data: [
                for (final t in territoryEntries)
                  [
                    t.divisionName,
                    t.calc.territory.name,
                    _formatNumber(t.calc.territory.area),
                    t.calc.requiredShields.toString(),
                  ],
              ],
            ),
            pw.SizedBox(height: 16),
          ],
          pw.Text('Деталізація по поверхах', style: pw.TextStyle(font: bold, fontSize: 13)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(font: bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headers: ['Управління', 'Будівля', 'Поверх', 'Площа', 'Потрібно, л', 'Наявно', 'Недостача', 'Каб. з ПК'],
            data: [
              for (final f in floorEntries)
                [
                  f.divisionName,
                  f.buildingName,
                  f.floor.name,
                  _formatNumber(f.calc.remainingArea),
                  _formatNumber(f.calc.requiredLiters),
                  _formatNumber(f.calc.assignedCapacityLiters),
                  f.calc.shortageLiters > 0 ? _formatNumber(f.calc.shortageLiters) : '—',
                  f.calc.computerRooms.length.toString(),
                ],
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  static String _formatNumber(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}
