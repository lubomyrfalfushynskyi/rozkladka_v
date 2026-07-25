class Building {
  final int? id;
  final String name;

  const Building({this.id, required this.name});

  Building copyWith({int? id, String? name}) =>
      Building(id: id ?? this.id, name: name ?? this.name);

  Map<String, Object?> toMap() => {'id': id, 'name': name};

  factory Building.fromMap(Map<String, Object?> map) => Building(
        id: map['id'] as int?,
        name: map['name'] as String,
      );
}
