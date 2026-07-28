import 'extinguisher_model_catalog.dart';
import 'extinguisher_type.dart';

/// Модель вогнегасника, додана користувачем понад базову номенклатуру
/// (`ExtinguisherModelCatalog.all`). Зберігається в БД, на відміну від
/// базових моделей — тому має `id`.
class CustomExtinguisherModel {
  final int? id;
  final String code;
  final ExtinguisherType type;
  final double capacity;
  final ExtinguisherCategory category;

  const CustomExtinguisherModel({
    this.id,
    required this.code,
    required this.type,
    required this.capacity,
    required this.category,
  });

  ExtinguisherModel get asModel => ExtinguisherModel(
        code: code,
        type: type,
        capacity: capacity,
        category: category,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'code': code,
        'type': type.code,
        'capacity': capacity,
        'category': category.name,
      };

  factory CustomExtinguisherModel.fromMap(Map<String, Object?> map) => CustomExtinguisherModel(
        id: map['id'] as int?,
        code: map['code'] as String,
        type: ExtinguisherType.fromCode(map['type'] as String),
        capacity: map['capacity'] as double,
        category: ExtinguisherCategory.values.firstWhere((c) => c.name == map['category']),
      );
}
