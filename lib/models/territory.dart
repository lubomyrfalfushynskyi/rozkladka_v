class Territory {
  final int? id;
  final int divisionId;
  final String name;
  final double area;
  final int assignedShields;

  const Territory({
    this.id,
    required this.divisionId,
    required this.name,
    required this.area,
    this.assignedShields = 0,
  });

  Territory copyWith({
    int? id,
    int? divisionId,
    String? name,
    double? area,
    int? assignedShields,
  }) =>
      Territory(
        id: id ?? this.id,
        divisionId: divisionId ?? this.divisionId,
        name: name ?? this.name,
        area: area ?? this.area,
        assignedShields: assignedShields ?? this.assignedShields,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'divisionId': divisionId,
        'name': name,
        'area': area,
        'assignedShields': assignedShields,
      };

  factory Territory.fromMap(Map<String, Object?> map) => Territory(
        id: map['id'] as int?,
        divisionId: map['divisionId'] as int,
        name: map['name'] as String,
        area: (map['area'] as num).toDouble(),
        assignedShields: (map['assignedShields'] as int?) ?? 0,
      );
}
