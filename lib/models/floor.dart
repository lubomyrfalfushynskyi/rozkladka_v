class Floor {
  final int? id;
  final int buildingId;
  final String name;
  final double totalArea;

  const Floor({
    this.id,
    required this.buildingId,
    required this.name,
    required this.totalArea,
  });

  Floor copyWith({int? id, int? buildingId, String? name, double? totalArea}) =>
      Floor(
        id: id ?? this.id,
        buildingId: buildingId ?? this.buildingId,
        name: name ?? this.name,
        totalArea: totalArea ?? this.totalArea,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'buildingId': buildingId,
        'name': name,
        'totalArea': totalArea,
      };

  factory Floor.fromMap(Map<String, Object?> map) => Floor(
        id: map['id'] as int?,
        buildingId: map['buildingId'] as int,
        name: map['name'] as String,
        totalArea: (map['totalArea'] as num).toDouble(),
      );
}
