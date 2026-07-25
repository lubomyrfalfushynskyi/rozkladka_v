class Room {
  final int? id;
  final int floorId;
  final String name;
  final double area;
  final bool hasComputer;

  const Room({
    this.id,
    required this.floorId,
    required this.name,
    required this.area,
    required this.hasComputer,
  });

  Room copyWith({
    int? id,
    int? floorId,
    String? name,
    double? area,
    bool? hasComputer,
  }) =>
      Room(
        id: id ?? this.id,
        floorId: floorId ?? this.floorId,
        name: name ?? this.name,
        area: area ?? this.area,
        hasComputer: hasComputer ?? this.hasComputer,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'floorId': floorId,
        'name': name,
        'area': area,
        'hasComputer': hasComputer ? 1 : 0,
      };

  factory Room.fromMap(Map<String, Object?> map) => Room(
        id: map['id'] as int?,
        floorId: map['floorId'] as int,
        name: map['name'] as String,
        area: (map['area'] as num).toDouble(),
        hasComputer: (map['hasComputer'] as int) == 1,
      );
}
