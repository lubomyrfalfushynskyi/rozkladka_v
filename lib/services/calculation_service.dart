import 'dart:math' as math;

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
  static const String smallComputerRoomExtinguisherClass = 'до 20 м² — вогнегасник 2 л';
  static const String largeComputerRoomExtinguisherClass = 'понад 20 м² — вогнегасник 3,5 кг';

  static const double territoryAreaPerShield = 5000.0;
}

class RoomRequirement {
  final Room room;
  final String extinguisherClass;

  const RoomRequirement({required this.room, required this.extinguisherClass});
}

class FloorCalculation {
  final Floor floor;
  final List<RoomRequirement> computerRooms;
  final double computerRoomsArea;
  final double remainingArea;
  final double requiredLiters;

  const FloorCalculation({
    required this.floor,
    required this.computerRooms,
    required this.computerRoomsArea,
    required this.remainingArea,
    required this.requiredLiters,
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

  static FloorCalculation calculateFloor(Floor floor, List<Room> rooms) {
    final computerRooms = rooms.where((r) => r.hasComputer).toList();
    final computerRoomsArea = computerRooms.fold<double>(0, (sum, r) => sum + r.area);
    final remainingArea = math.max(0.0, floor.totalArea - computerRoomsArea);
    final requiredLiters =
        (remainingArea / FireSafetyNorms.areaUnitForLiters * FireSafetyNorms.litersPerTenSquareMeters)
            .ceilToDouble();

    return FloorCalculation(
      floor: floor,
      computerRooms: computerRooms
          .map((r) => RoomRequirement(room: r, extinguisherClass: extinguisherClassFor(r.area)))
          .toList(),
      computerRoomsArea: computerRoomsArea,
      remainingArea: remainingArea,
      requiredLiters: requiredLiters,
    );
  }

  static TerritoryCalculation calculateTerritory(Territory territory) {
    final shields = (territory.area / FireSafetyNorms.territoryAreaPerShield).ceil();
    return TerritoryCalculation(territory: territory, requiredShields: shields);
  }
}
