import 'package:flutter_test/flutter_test.dart';

import 'package:rozkladka_v/models/floor.dart';
import 'package:rozkladka_v/models/summary_data.dart';
import 'package:rozkladka_v/models/territory.dart';
import 'package:rozkladka_v/services/calculation_service.dart';
import 'package:rozkladka_v/services/pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildSummaryReport повертає коректний PDF-документ', () async {
    final floor = const Floor(id: 1, buildingId: 1, name: 'Поверх 1', totalArea: 300);
    final floorCalc = CalculationService.calculateFloor(floor, const []);
    final floorEntries = [
      FloorSummaryEntry(
        divisionId: 1,
        divisionName: 'Тестове управління',
        buildingId: 1,
        buildingName: 'Тестова будівля',
        floor: floor,
        calc: floorCalc,
      ),
    ];
    final territory = const Territory(id: 1, divisionId: 1, name: 'Двір', area: 12000, assignedShields: 1);
    final territoryEntries = [
      TerritorySummaryEntry(
        divisionId: 1,
        divisionName: 'Тестове управління',
        calc: CalculationService.calculateTerritory(territory),
      ),
    ];

    final tables = FunnelBuilder.build(
      floorEntries: floorEntries,
      territoryEntries: territoryEntries,
      filterDivisionId: 1,
    );

    final bytes = await PdfService.buildSummaryReport(
      scopeTitle: 'Тестове управління',
      tables: tables,
      meta: const PdfReportMeta(divisions: 1, buildings: 1, floors: 1, computerRooms: 0, territories: 1),
    );

    expect(bytes, isNotEmpty);
    // Кожен коректний PDF-файл починається з магічного заголовка "%PDF".
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
