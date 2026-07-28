import 'package:flutter/material.dart';

import '../models/custom_extinguisher_model.dart';
import '../models/extinguisher_model_catalog.dart';
import '../models/extinguisher_type.dart';
import '../services/database_service.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/page_help.dart';

class ExtinguisherCatalogScreen extends StatefulWidget {
  const ExtinguisherCatalogScreen({super.key});

  @override
  State<ExtinguisherCatalogScreen> createState() => _ExtinguisherCatalogScreenState();
}

class _ExtinguisherCatalogScreenState extends State<ExtinguisherCatalogScreen> {
  final _db = DatabaseService.instance;
  List<CustomExtinguisherModel> _custom = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final custom = await _db.getCustomExtinguisherModels();
    if (!mounted) return;
    setState(() {
      _custom = custom;
      _loading = false;
    });
  }

  bool _codeExists(String code, ExtinguisherType type) {
    final target = code.trim().toLowerCase();
    final inBase = ExtinguisherModelCatalog.all.any((m) => m.type == type && m.code.toLowerCase() == target);
    final inCustom = _custom.any((m) => m.type == type && m.code.toLowerCase() == target);
    return inBase || inCustom;
  }

  Future<void> _addModel() async {
    final codeController = TextEditingController();
    final capacityController = TextEditingController();
    var type = ExtinguisherType.vp;
    var category = ExtinguisherCategory.portable;
    final formKey = GlobalKey<FormState>();
    String? duplicateError;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Нова модель вогнегасника'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ExtinguisherType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Тип'),
                  items: ExtinguisherType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                      .toList(),
                  onChanged: (v) => setDialogState(() {
                    type = v ?? type;
                    duplicateError = null;
                  }),
                ),
                TextFormField(
                  controller: codeController,
                  decoration: InputDecoration(labelText: 'Код моделі (напр. "ВП-7")', errorText: duplicateError),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Обовʼязково' : null,
                ),
                TextFormField(
                  controller: capacityController,
                  decoration: const InputDecoration(labelText: 'Ємність'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (value == null || value <= 0) return 'Вкажіть коректну ємність';
                    return null;
                  },
                ),
                DropdownButtonFormField<ExtinguisherCategory>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Категорія'),
                  items: ExtinguisherCategory.values
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? category),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Скасувати')),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                if (_codeExists(codeController.text, type)) {
                  setDialogState(() => duplicateError = 'Такий код вже є серед базових або доданих моделей');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Додати'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    final capacity = double.parse(capacityController.text.replaceAll(',', '.'));
    await _db.insertCustomExtinguisherModel(CustomExtinguisherModel(
      code: codeController.text.trim(),
      type: type,
      capacity: capacity,
      category: category,
    ));
    _reload();
  }

  Future<void> _deleteModel(CustomExtinguisherModel model) async {
    if (!await confirmDelete(context, model.code)) return;
    await _db.deleteCustomExtinguisherModel(model.id!);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Номенклатура вогнегасників'),
        actions: [
          PageHelpAction(
            title: 'Номенклатура вогнегасників',
            points: [
              'Список моделей, які можна обрати при додаванні вогнегасника.',
              'Базові моделі (незмінні, вже включені): ВП-1, ВП-2, ВП-3, ВП-5, ВП-6, ВП-9, '
                  'ВП-12, ВП-20, ВП-50, ВП-100; ВВК-1.4, ВВК-2, ВВК-3.5, ВВК-5, ВВК-7, ВВК-10, '
                  'ВВК-20, ВВК-50, ВВК-55; ВВП-2, ВВП-4, ВВП-6, ВВП-9, ВВП-25, ВВП-50, ВВП-100; '
                  'ВВ-5, ВВ-6, ВВ-9, ВВ-10, ВВ-50, ВВ-100.',
              'Кнопка "+" — додати свою модель понад базові (потрібні тип, код, ємність, категорія).',
              'Код моделі не може повторювати вже наявний (базовий чи доданий) в межах того самого типу.',
              'Видалити можна лише додані моделі — кошик поруч з ними. Базові — незмінні.',
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Базові (незмінні)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                for (final model in ExtinguisherModelCatalog.all)
                  ListTile(
                    leading: const Icon(Icons.local_fire_department_outlined),
                    title: Text(model.code),
                    subtitle: Text('${model.type.label} · ${model.label}'),
                  ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text('Додані', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                if (_custom.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Ще немає жодної доданої моделі. Натисни "+" щоб додати.'),
                  ),
                for (final model in _custom)
                  ListTile(
                    leading: const Icon(Icons.local_fire_department_outlined),
                    title: Text(model.code),
                    subtitle: Text('${model.type.label} · ${model.asModel.label}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteModel(model),
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Модель'),
        onPressed: _addModel,
      ),
    );
  }
}
