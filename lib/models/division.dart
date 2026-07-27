class Division {
  final int? id;
  final String name;

  const Division({this.id, required this.name});

  Division copyWith({int? id, String? name}) =>
      Division(id: id ?? this.id, name: name ?? this.name);

  Map<String, Object?> toMap() => {'id': id, 'name': name};

  factory Division.fromMap(Map<String, Object?> map) => Division(
        id: map['id'] as int?,
        name: map['name'] as String,
      );
}
