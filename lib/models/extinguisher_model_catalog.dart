import 'extinguisher_type.dart';

enum ExtinguisherCategory {
  portable,
  mobile;

  String get label => this == ExtinguisherCategory.portable ? 'переносний' : 'пересувний';
}

/// Конкретна модель вогнегасника з номенклатури (напр. "ВП-5").
class ExtinguisherModel {
  final String code;
  final ExtinguisherType type;
  final double capacity;
  final ExtinguisherCategory category;

  const ExtinguisherModel({
    required this.code,
    required this.type,
    required this.capacity,
    required this.category,
  });

  String get label {
    final capacityText = capacity == capacity.roundToDouble()
        ? capacity.toStringAsFixed(0)
        : capacity.toStringAsFixed(1);
    return '$code ($capacityText ${type.unit}, ${category.label})';
  }
}

/// Номенклатура вогнегасників за типами (переносні/пересувні моделі).
class ExtinguisherModelCatalog {
  static const List<ExtinguisherModel> all = [
    // Порошкові (ВП / ОП)
    ExtinguisherModel(code: 'ВП-1', type: ExtinguisherType.vp, capacity: 1, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВП-2', type: ExtinguisherType.vp, capacity: 2, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВП-3', type: ExtinguisherType.vp, capacity: 3, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВП-5', type: ExtinguisherType.vp, capacity: 5, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВП-6', type: ExtinguisherType.vp, capacity: 6, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВП-9', type: ExtinguisherType.vp, capacity: 9, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВП-12', type: ExtinguisherType.vp, capacity: 12, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВП-20', type: ExtinguisherType.vp, capacity: 20, category: ExtinguisherCategory.mobile),
    ExtinguisherModel(code: 'ВП-50', type: ExtinguisherType.vp, capacity: 50, category: ExtinguisherCategory.mobile),
    ExtinguisherModel(code: 'ВП-100', type: ExtinguisherType.vp, capacity: 100, category: ExtinguisherCategory.mobile),

    // Вуглекислотні (ВВК / ОУ)
    ExtinguisherModel(code: 'ВВК-1.4', type: ExtinguisherType.vvk, capacity: 1.4, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВВК-2', type: ExtinguisherType.vvk, capacity: 2, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВВК-3.5', type: ExtinguisherType.vvk, capacity: 3.5, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВВК-5', type: ExtinguisherType.vvk, capacity: 5, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВВК-7', type: ExtinguisherType.vvk, capacity: 7, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВВК-10', type: ExtinguisherType.vvk, capacity: 10, category: ExtinguisherCategory.mobile),
    ExtinguisherModel(code: 'ВВК-20', type: ExtinguisherType.vvk, capacity: 20, category: ExtinguisherCategory.mobile),
    ExtinguisherModel(code: 'ВВК-50', type: ExtinguisherType.vvk, capacity: 50, category: ExtinguisherCategory.mobile),
    ExtinguisherModel(code: 'ВВК-55', type: ExtinguisherType.vvk, capacity: 55, category: ExtinguisherCategory.mobile),

    // Водопінні (ВВП)
    ExtinguisherModel(code: 'ВВП-2', type: ExtinguisherType.vvp, capacity: 2, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВВП-4', type: ExtinguisherType.vvp, capacity: 4, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВВП-6', type: ExtinguisherType.vvp, capacity: 6, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВВП-9', type: ExtinguisherType.vvp, capacity: 9, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВВП-25', type: ExtinguisherType.vvp, capacity: 25, category: ExtinguisherCategory.mobile),
    ExtinguisherModel(code: 'ВВП-50', type: ExtinguisherType.vvp, capacity: 50, category: ExtinguisherCategory.mobile),
    ExtinguisherModel(code: 'ВВП-100', type: ExtinguisherType.vvp, capacity: 100, category: ExtinguisherCategory.mobile),

    // Водяні (ВВ)
    ExtinguisherModel(code: 'ВВ-5', type: ExtinguisherType.vv, capacity: 5, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВВ-6', type: ExtinguisherType.vv, capacity: 6, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВВ-9', type: ExtinguisherType.vv, capacity: 9, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВВ-10', type: ExtinguisherType.vv, capacity: 10, category: ExtinguisherCategory.portable),
    ExtinguisherModel(code: 'ВВ-50', type: ExtinguisherType.vv, capacity: 50, category: ExtinguisherCategory.mobile),
    ExtinguisherModel(code: 'ВВ-100', type: ExtinguisherType.vv, capacity: 100, category: ExtinguisherCategory.mobile),
  ];

  static List<ExtinguisherModel> forType(ExtinguisherType type) =>
      all.where((m) => m.type == type).toList();

  /// Знаходить модель за типом і ємністю (для відображення вже збережених
  /// записів). Повертає null, якщо значення не відповідає жодній моделі з
  /// номенклатури (напр. старі дані, введені довільним числом до переходу
  /// на список моделей).
  static ExtinguisherModel? findByTypeAndCapacity(ExtinguisherType type, double capacity) {
    for (final model in all) {
      if (model.type == type && (model.capacity - capacity).abs() < 0.001) {
        return model;
      }
    }
    return null;
  }
}
