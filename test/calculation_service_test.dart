import 'package:flutter_test/flutter_test.dart';
import 'package:rozkladka_v/models/extinguisher.dart';
import 'package:rozkladka_v/models/extinguisher_model_catalog.dart';
import 'package:rozkladka_v/models/extinguisher_type.dart';
import 'package:rozkladka_v/models/floor.dart';
import 'package:rozkladka_v/models/room.dart';
import 'package:rozkladka_v/models/territory.dart';
import 'package:rozkladka_v/services/calculation_service.dart';

void main() {
  group('extinguisherClassFor', () {
    test('до 20 м² — менший клас', () {
      expect(
        CalculationService.extinguisherClassFor(20),
        FireSafetyNorms.smallComputerRoomExtinguisherClass,
      );
    });

    test('понад 20 м² — більший клас', () {
      expect(
        CalculationService.extinguisherClassFor(20.1),
        FireSafetyNorms.largeComputerRoomExtinguisherClass,
      );
    });
  });

  group('calculateFloor — базовий розрахунок', () {
    test('без кабінетів з ПК — вся площа йде на загальну норму', () {
      final floor = const Floor(id: 1, buildingId: 1, name: '1 поверх', totalArea: 500);
      final calc = CalculationService.calculateFloor(floor, const []);

      expect(calc.computerRoomsArea, 0);
      expect(calc.remainingArea, 500);
      expect(calc.requiredLiters, 50); // 500 / 10 * 1
    });

    test('кабінети з ПК віднімаються із загальної площі', () {
      final floor = const Floor(id: 1, buildingId: 1, name: '1 поверх', totalArea: 500);
      final rooms = [
        const Room(id: 1, floorId: 1, name: 'Каб. 1', area: 30, hasComputer: true),
        const Room(id: 2, floorId: 1, name: 'Каб. 2', area: 20, hasComputer: false),
      ];
      final calc = CalculationService.calculateFloor(floor, rooms);

      expect(calc.computerRoomsArea, 30);
      expect(calc.remainingArea, 470);
      expect(calc.requiredLiters, 47);
      expect(calc.computerRooms.length, 1);
    });

    test('округлення необхідних літрів завжди в більшу сторону', () {
      final floor = const Floor(id: 1, buildingId: 1, name: '1 поверх', totalArea: 445);
      final calc = CalculationService.calculateFloor(floor, const []);

      expect(calc.requiredLiters, 45); // 44.5 -> ceil -> 45
    });
  });

  group('calculateFloor — недостача загальної площі', () {
    test('без жодного вогнегасника — недостача дорівнює всій нормі', () {
      final floor = const Floor(id: 1, buildingId: 1, name: '1 поверх', totalArea: 300);
      final calc = CalculationService.calculateFloor(floor, const []);

      expect(calc.requiredLiters, 30);
      expect(calc.assignedCapacityLiters, 0);
      expect(calc.shortageLiters, 30);
    });

    test('часткове забезпечення — недостача це різниця', () {
      final floor = const Floor(id: 1, buildingId: 1, name: '1 поверх', totalArea: 300);
      final extinguishers = [
        const Extinguisher(
          serialNumber: 'SN1',
          inventoryNumber: 'INV1',
          type: ExtinguisherType.vp,
          capacityLiters: 10,
          floorId: 1,
        ),
      ];
      final calc = CalculationService.calculateFloor(
        floor,
        const [],
        floorExtinguishers: extinguishers,
      );

      expect(calc.requiredLiters, 30);
      expect(calc.assignedCapacityLiters, 10);
      expect(calc.shortageLiters, 20);
    });

    test('повне забезпечення (з надлишком) — недостача 0, не відʼємна', () {
      final floor = const Floor(id: 1, buildingId: 1, name: '1 поверх', totalArea: 300);
      final extinguishers = [
        const Extinguisher(
          serialNumber: 'SN1',
          inventoryNumber: 'INV1',
          type: ExtinguisherType.vp,
          capacityLiters: 50,
          floorId: 1,
        ),
      ];
      final calc = CalculationService.calculateFloor(
        floor,
        const [],
        floorExtinguishers: extinguishers,
      );

      expect(calc.shortageLiters, 0);
    });
  });

  group('calculateFloor — недостача по кабінетах з ПК', () {
    test('кабінет без вогнегасника — недостача 1', () {
      final floor = const Floor(id: 1, buildingId: 1, name: '1 поверх', totalArea: 500);
      final rooms = [const Room(id: 1, floorId: 1, name: 'Каб. 1', area: 30, hasComputer: true)];
      final calc = CalculationService.calculateFloor(floor, rooms);

      expect(calc.computerRooms.single.assignedCount, 0);
      expect(calc.computerRooms.single.shortageCount, 1);
    });

    test('кабінет із призначеним вогнегасником ВВК — недостача 0', () {
      final floor = const Floor(id: 1, buildingId: 1, name: '1 поверх', totalArea: 500);
      final rooms = [const Room(id: 1, floorId: 1, name: 'Каб. 1', area: 30, hasComputer: true)];
      final byRoom = {
        1: [
          const Extinguisher(
            serialNumber: 'SN2',
            inventoryNumber: 'INV2',
            type: ExtinguisherType.vvk,
            capacityLiters: 5,
            roomId: 1,
          ),
        ],
      };
      final calc = CalculationService.calculateFloor(floor, rooms, extinguishersByRoomId: byRoom);

      expect(calc.computerRooms.single.assignedCount, 1);
      expect(calc.computerRooms.single.shortageCount, 0);
    });
  });

  group('calculateTerritory', () {
    test('рівно кратна площа', () {
      final territory = const Territory(id: 1, name: 'Двір', area: 10000);
      expect(CalculationService.calculateTerritory(territory).requiredShields, 2);
    });

    test('нерівна площа округлюється вгору', () {
      final territory = const Territory(id: 1, name: 'Двір', area: 10001);
      expect(CalculationService.calculateTerritory(territory).requiredShields, 3);
    });
  });

  group('ExtinguisherType', () {
    test('коди відповідають чотирьом типам', () {
      expect(ExtinguisherType.vp.code, 'ВП');
      expect(ExtinguisherType.vvk.code, 'ВВК');
      expect(ExtinguisherType.vvp.code, 'ВВП');
      expect(ExtinguisherType.vv.code, 'ВВ');
    });

    test('fromCode повертає правильний тип', () {
      expect(ExtinguisherType.fromCode('ВВК'), ExtinguisherType.vvk);
    });

    test('fromCode для невідомого коду повертає ВП як безпечний дефолт', () {
      expect(ExtinguisherType.fromCode('???'), ExtinguisherType.vp);
    });

    test('одиниця виміру: ВП/ВВК — кг, ВВП/ВВ — л', () {
      expect(ExtinguisherType.vp.unit, 'кг');
      expect(ExtinguisherType.vvk.unit, 'кг');
      expect(ExtinguisherType.vvp.unit, 'л');
      expect(ExtinguisherType.vv.unit, 'л');
    });
  });

  group('ExtinguisherModelCatalog', () {
    test('кожен тип має хоча б одну модель', () {
      for (final type in ExtinguisherType.values) {
        expect(ExtinguisherModelCatalog.forType(type), isNotEmpty, reason: 'тип $type без моделей');
      }
    });

    test('ємності моделей унікальні в межах одного типу (немає колізій пошуку)', () {
      for (final type in ExtinguisherType.values) {
        final capacities = ExtinguisherModelCatalog.forType(type).map((m) => m.capacity).toList();
        expect(capacities.length, capacities.toSet().length, reason: 'дублікати ємностей у типі $type');
      }
    });

    test('findByTypeAndCapacity знаходить точну модель', () {
      final model = ExtinguisherModelCatalog.findByTypeAndCapacity(ExtinguisherType.vvk, 3.5);
      expect(model?.code, 'ВВК-3.5');
    });

    test('findByTypeAndCapacity повертає null для значення поза номенклатурою', () {
      expect(ExtinguisherModelCatalog.findByTypeAndCapacity(ExtinguisherType.vp, 999), isNull);
    });
  });
}
