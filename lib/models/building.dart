class Building {
  final int? id;
  final int divisionId;
  final String name;

  const Building({this.id, required this.divisionId, required this.name});

  Building copyWith({int? id, int? divisionId, String? name}) => Building(
        id: id ?? this.id,
        divisionId: divisionId ?? this.divisionId,
        name: name ?? this.name,
      );

  Map<String, Object?> toMap() => {'id': id, 'divisionId': divisionId, 'name': name};

  factory Building.fromMap(Map<String, Object?> map) => Building(
        id: map['id'] as int?,
        divisionId: map['divisionId'] as int,
        name: map['name'] as String,
      );
}
