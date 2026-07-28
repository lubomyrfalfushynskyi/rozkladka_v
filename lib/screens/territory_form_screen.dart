import 'package:flutter/material.dart';

import '../models/territory.dart';
import '../services/calculation_service.dart';
import '../services/database_service.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/page_help.dart';

class TerritoryFormScreen extends StatefulWidget {
  final int? divisionId;
  final Territory? territory;

  const TerritoryFormScreen({super.key, this.divisionId, this.territory})
      : assert(divisionId != null || territory != null, 'Потрібен divisionId для нової території');

  @override
  State<TerritoryFormScreen> createState() => _TerritoryFormScreenState();
}

class _TerritoryFormScreenState extends State<TerritoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _areaController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.territory?.name ?? '');
    _areaController = TextEditingController(
      text: widget.territory != null ? widget.territory!.area.toStringAsFixed(0) : '',
    );
  }

  double? get _parsedArea => double.tryParse(_areaController.text.replaceAll(',', '.'));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final db = DatabaseService.instance;
    final territory = Territory(
      id: widget.territory?.id,
      divisionId: widget.territory?.divisionId ?? widget.divisionId!,
      name: _nameController.text.trim(),
      area: _parsedArea!,
    );
    if (widget.territory == null) {
      await db.insertTerritory(territory);
    } else {
      await db.updateTerritory(territory);
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (widget.territory?.id == null) return;
    if (!await confirmDelete(context, widget.territory!.name)) return;
    await DatabaseService.instance.deleteTerritory(widget.territory!.id!);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final area = _parsedArea;
    final preview = (area != null && area > 0)
        ? CalculationService.calculateTerritory(
            Territory(divisionId: widget.divisionId ?? widget.territory?.divisionId ?? 0, name: '', area: area),
          ).requiredShields
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.territory == null ? 'Нова територія' : 'Редагувати територію'),
        actions: [
          PageHelpAction(
            title: 'Територія (ТВУЗ)',
            points: [
              'Площа території визначає, скільки пожежних щитів для неї потрібно (розрахунок нижче форми).',
              'Назва і площа редагуються прямо тут у будь-який момент.',
            ],
          ),
          if (widget.territory != null)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Назва території (напр. "Двір")'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Обовʼязково' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(labelText: 'Площа, м²'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (value == null || value <= 0) return 'Вкажіть коректну площу';
                  return null;
                },
              ),
              if (preview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Потрібно пожежних щитів: $preview',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('Зберегти')),
            ],
          ),
        ),
      ),
    );
  }
}
