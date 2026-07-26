import 'extinguisher_type.dart';

/// Вогнегасник належить або кабінету з ПК (roomId), або загальній площі
/// поверху (floorId) — рівно одне з двох, ніколи обидва й ніколи жодне.
class Extinguisher {
  final int? id; // ідентифікатор / порядковий номер — AUTOINCREMENT в БД
  final String serialNumber; // заводський номер
  final String inventoryNumber; // інвентарний номер
  final ExtinguisherType type;
  final double capacityLiters;
  final int? roomId;
  final int? floorId;

  const Extinguisher({
    this.id,
    required this.serialNumber,
    required this.inventoryNumber,
    required this.type,
    required this.capacityLiters,
    this.roomId,
    this.floorId,
  });

  Extinguisher copyWith({
    int? id,
    String? serialNumber,
    String? inventoryNumber,
    ExtinguisherType? type,
    double? capacityLiters,
    int? roomId,
    int? floorId,
  }) =>
      Extinguisher(
        id: id ?? this.id,
        serialNumber: serialNumber ?? this.serialNumber,
        inventoryNumber: inventoryNumber ?? this.inventoryNumber,
        type: type ?? this.type,
        capacityLiters: capacityLiters ?? this.capacityLiters,
        roomId: roomId ?? this.roomId,
        floorId: floorId ?? this.floorId,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'serialNumber': serialNumber,
        'inventoryNumber': inventoryNumber,
        'type': type.code,
        'capacityLiters': capacityLiters,
        'roomId': roomId,
        'floorId': floorId,
      };

  factory Extinguisher.fromMap(Map<String, Object?> map) => Extinguisher(
        id: map['id'] as int?,
        serialNumber: map['serialNumber'] as String,
        inventoryNumber: map['inventoryNumber'] as String,
        type: ExtinguisherType.fromCode(map['type'] as String),
        capacityLiters: (map['capacityLiters'] as num).toDouble(),
        roomId: map['roomId'] as int?,
        floorId: map['floorId'] as int?,
      );
}
