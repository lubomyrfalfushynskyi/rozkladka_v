import 'dart:math' as math;

import '../models/extinguisher.dart';
import '../models/extinguisher_type.dart';
import '../models/floor.dart';
import '../models/room.dart';
import '../models/territory.dart';

/// Норми протипожежного оснащення.
///
/// TODO: звірити точні цифри (клас/масу вогнегасника для кабінетів з ПК,
/// одиниці заряду для звичайних приміщень) з конкретним пунктом наказу —
/// зараз зафіксовано зі слів користувача, без посилання на номер наказу.
class FireSafetyNorms {
  static const double litersPerTenSquareMeters = 1.0;
  static const double areaUnitForLiters = 10.0;

  static const double computerRoomAreaThreshold = 20.0;
  static const String smallComputerRoomExtinguisherClass = 'до 20 м² — вогнегасник 2 л';
  static const String largeComputerRoomExtinguisherClass = 'понад 20 м² — вогнегасник 3,5 кг';

  static const double territoryAreaPerShield = 5000.0;

  /// Кабінети з комп'ютерною технікою обслуговуються виключно
  /// вуглекислотними вогнегасниками — фіксоване правило, не налаштовується.
  static const ExtinguisherType computerRoomExtinguisherType = ExtinguisherType.vvk;

  /// Скільки вогнегасників потрібно на один кабінет з ПК.
  static const int extinguishersRequiredPerComputerRoom = 1;
}

class RoomRequirement {
  final Room room;
  final String extinguisherClass;
  final int assignedCount;
  final int shortageCount;

  const RoomRequirement({
    required this.room,
    required this.extinguisherClass,
    required this.assignedCount,
    required this.shortageCount,
  });
}

class FloorCalculation {
  final Floor floor;
  final List<RoomRequirement> computerRooms;
  final double computerRoomsArea;
  final double remainingArea;
  final double requiredLiters;
  final double assignedCapacityLiters;
  final double shortageLiters;

  const FloorCalculation({
    required this.floor,
    required this.computerRooms,
    required this.computerRoomsArea,
    required this.remainingArea,
    required this.requiredLiters,
    required this.assignedCapacityLiters,
    required this.shortageLiters,
  });
}

class TerritoryCalculation {
  final Territory territory;
  final int requiredShields;

  const TerritoryCalculation({required this.territory, required this.requiredShields});
}

class CalculationService {
  static String extinguisherClassFor(double roomArea) {
    return roomArea <= FireSafetyNorms.computerRoomAreaThreshold
        ? FireSafetyNorms.smallComputerRoomExtinguisherClass
        : FireSafetyNorms.largeComputerRoomExtinguisherClass;
  }

  static FloorCalculation calculateFloor(
    Floor floor,
    List<Room> rooms, {
    List<Extinguisher> floorExtinguishers = const [],
    Map<int, List<Extinguisher>> extinguishersByRoomId = const {},
  }) {
    final computerRooms = rooms.where((r) => r.hasComputer).toList();
    final computerRoomsArea = computerRooms.fold<double>(0, (sum, r) => sum + r.area);
    final remainingArea = math.max(0.0, floor.totalArea - computerRoomsArea);
    final requiredLiters =
        (remainingArea / FireSafetyNorms.areaUnitForLiters * FireSafetyNorms.litersPerTenSquareMeters)
            .ceilToDouble();

    final assignedCapacityLiters = floorExtinguishers.fold<double>(0, (sum, e) => sum + e.capacityLiters);
    final shortageLiters = math.max(0.0, requiredLiters - assignedCapacityLiters);

    final roomRequirements = computerRooms.map((r) {
      final assigned = (r.id != null ? extinguishersByRoomId[r.id] : null) ?? const <Extinguisher>[];
      return RoomRequirement(
        room: r,
        extinguisherClass: extinguisherClassFor(r.area),
        assignedCount: assigned.length,
        shortageCount: math.max(0, FireSafetyNorms.extinguishersRequiredPerComputerRoom - assigned.length),
      );
    }).toList();

    return FloorCalculation(
      floor: floor,
      computerRooms: roomRequirements,
      computerRoomsArea: computerRoomsArea,
      remainingArea: remainingArea,
      requiredLiters: requiredLiters,
      assignedCapacityLiters: assignedCapacityLiters,
      shortageLiters: shortageLiters,
    );
  }

  static TerritoryCalculation calculateTerritory(Territory territory) {
    final shields = (territory.area / FireSafetyNorms.territoryAreaPerShield).ceil();
    return TerritoryCalculation(territory: territory, requiredShields: shields);
  }
}
