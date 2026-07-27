class Territory {
  final int? id;
  final int divisionId;
  final String name;
  final double area;

  const Territory({this.id, required this.divisionId, required this.name, required this.area});

  Territory copyWith({int? id, int? divisionId, String? name, double? area}) => Territory(
        id: id ?? this.id,
        divisionId: divisionId ?? this.divisionId,
        name: name ?? this.name,
        area: area ?? this.area,
      );

  Map<String, Object?> toMap() => {'id': id, 'divisionId': divisionId, 'name': name, 'area': area};

  factory Territory.fromMap(Map<String, Object?> map) => Territory(
        id: map['id'] as int?,
        divisionId: map['divisionId'] as int,
        name: map['name'] as String,
        area: (map['area'] as num).toDouble(),
      );
}
