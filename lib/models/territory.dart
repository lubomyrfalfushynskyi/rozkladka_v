class Territory {
  final int? id;
  final String name;
  final double area;

  const Territory({this.id, required this.name, required this.area});

  Territory copyWith({int? id, String? name, double? area}) => Territory(
        id: id ?? this.id,
        name: name ?? this.name,
        area: area ?? this.area,
      );

  Map<String, Object?> toMap() => {'id': id, 'name': name, 'area': area};

  factory Territory.fromMap(Map<String, Object?> map) => Territory(
        id: map['id'] as int?,
        name: map['name'] as String,
        area: (map['area'] as num).toDouble(),
      );
}
