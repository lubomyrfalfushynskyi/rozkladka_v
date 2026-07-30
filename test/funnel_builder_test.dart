import 'package:flutter_test/flutter_test.dart';

import 'package:rozkladka_v/models/extinguisher.dart';
import 'package:rozkladka_v/models/extinguisher_type.dart';
import 'package:rozkladka_v/models/floor.dart';
import 'package:rozkladka_v/models/room.dart';
import 'package:rozkladka_v/models/summary_data.dart';
import 'package:rozkladka_v/models/territory.dart';
import 'package:rozkladka_v/services/calculation_service.dart';

FloorSummaryEntry _floorEntry({
  required int divisionId,
  required String divisionName,
  required int buildingId,
  required String buildingName,
  required Floor floor,
  List<Room> rooms = const [],
  List<Extinguisher> floorExtinguishers = const [],
  Map<int, List<Extinguisher>> extinguishersByRoomId = const {},
}) {
  final calc = CalculationService.calculateFloor(
    floor,
    rooms,
    floorExtinguishers: floorExtinguishers,
    extinguishersByRoomId: extinguishersByRoomId,
  );
  return FloorSummaryEntry(
    divisionId: divisionId,
    divisionName: divisionName,
    buildingId: buildingId,
    buildingName: buildingName,
    floor: floor,
    calc: calc,
  );
}

void main() {
  test('глобальний рівень: розбивка по управліннях, підсумок = сума', () {
    final floorA = const Floor(id: 1, buildingId: 1, name: 'Поверх A', totalArea: 100);
    final floorB = const Floor(id: 2, buildingId: 2, name: 'Поверх B', totalArea: 200);
    final entries = [
      _floorEntry(divisionId: 1, divisionName: 'Управління 1', buildingId: 1, buildingName: 'Буд 1', floor: floorA),
      _floorEntry(divisionId: 2, divisionName: 'Управління 2', buildingId: 2, buildingName: 'Буд 2', floor: floorB),
    ];

    final tables = FunnelBuilder.build(floorEntries: entries, territoryEntries: const []);
    final substance = tables.firstWhere((t) => t.title.contains('по управліннях') && t.unit == 'л');

    expect(substance.rows, hasLength(2));
    expect(substance.rows.map((r) => r.object), containsAll(['Управління 1', 'Управління 2']));
    // 100 м² -> 10 л; 200 м² -> 20 л (1 л на 10 м²).
    expect(substance.total.need, 30);
  });

  test('рівень управління: розбивка по будівлях і територіях окремо', () {
    final floor = const Floor(id: 1, buildingId: 1, name: 'Поверх', totalArea: 100);
    final entries = [
      _floorEntry(divisionId: 1, divisionName: 'Управління', buildingId: 1, buildingName: 'Буд А', floor: floor),
    ];
    final territory = const Territory(id: 1, divisionId: 1, name: 'Двір', area: 12000, assignedShields: 1);
    final territoryEntries = [
      TerritorySummaryEntry(divisionId: 1, divisionName: 'Управління', calc: CalculationService.calculateTerritory(territory)),
    ];

    final tables = FunnelBuilder.build(
      floorEntries: entries,
      territoryEntries: territoryEntries,
      filterDivisionId: 1,
    );

    final substance = tables.firstWhere((t) => t.title.contains('по будівлях') && t.unit == 'л');
    expect(substance.rows.single.object, 'Буд А');

    final shields = tables.firstWhere((t) => t.title.contains('щити'));
    expect(shields.rows.single.object, 'Двір');
    expect(shields.rows.single.need, 3); // 12000/5000 = 2.4 -> округлення вгору -> 3
    expect(shields.rows.single.available, 1);
    expect(shields.rows.single.shortage, 2);
  });

  test('рівень поверху: розбивка ВВК по кабінетах, речовина без розбивки', () {
    final room1 = const Room(id: 1, floorId: 1, name: 'Каб 1', area: 15, hasComputer: true);
    final room2 = const Room(id: 2, floorId: 1, name: 'Каб 2', area: 25, hasComputer: true);
    final floor = const Floor(id: 1, buildingId: 1, name: 'Поверх', totalArea: 200);
    final extinguisher = Extinguisher(
      serialNumber: 'SN',
      inventoryNumber: '1234',
      type: ExtinguisherType.vvk,
      capacityLiters: 5,
      roomId: 1,
    );
    final entry = _floorEntry(
      divisionId: 1,
      divisionName: 'Управління',
      buildingId: 1,
      buildingName: 'Буд',
      floor: floor,
      rooms: [room1, room2],
      extinguishersByRoomId: {
        1: [extinguisher],
      },
    );

    final tables = FunnelBuilder.build(
      floorEntries: [entry],
      territoryEntries: const [],
      filterDivisionId: 1,
      filterBuildingId: 1,
      filterFloorId: 1,
    );

    final substance = tables.firstWhere((t) => t.title.contains('загальна площа'));
    expect(substance.rows, isEmpty); // на рівні поверху речовина без подальшої розбивки
    expect(substance.total.object, 'Поверх');

    final vvk = tables.firstWhere((t) => t.title.contains('по кабінетах'));
    expect(vvk.rows, hasLength(2));
    final row1 = vvk.rows.firstWhere((r) => r.object == 'Каб 1');
    final row2 = vvk.rows.firstWhere((r) => r.object == 'Каб 2');
    expect(row1.available, 1);
    expect(row1.shortage, 0);
    expect(row2.available, 0);
    expect(row2.shortage, 1);
    expect(vvk.total.need, 2);
    expect(vvk.total.available, 1);
    expect(vvk.total.shortage, 1);
  });

  test('території не показуються на рівні будівлі/поверху', () {
    final floor = const Floor(id: 1, buildingId: 1, name: 'Поверх', totalArea: 100);
    final entries = [
      _floorEntry(divisionId: 1, divisionName: 'Управління', buildingId: 1, buildingName: 'Буд', floor: floor),
    ];
    final territory = const Territory(id: 1, divisionId: 1, name: 'Двір', area: 12000);
    final territoryEntries = [
      TerritorySummaryEntry(divisionId: 1, divisionName: 'Управління', calc: CalculationService.calculateTerritory(territory)),
    ];

    final tables = FunnelBuilder.build(
      floorEntries: entries,
      territoryEntries: territoryEntries,
      filterDivisionId: 1,
      filterBuildingId: 1,
    );

    expect(tables.any((t) => t.title.contains('щити')), isFalse);
  });
}
