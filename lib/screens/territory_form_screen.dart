import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  late final TextEditingController _shieldsController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.territory?.name ?? '');
    _areaController = TextEditingController(
      text: widget.territory != null ? widget.territory!.area.toStringAsFixed(0) : '',
    );
    _shieldsController = TextEditingController(
      text: widget.territory != null ? widget.territory!.assignedShields.toString() : '0',
    );
  }

  double? get _parsedArea => double.tryParse(_areaController.text.replaceAll(',', '.'));
  int get _parsedShields => int.tryParse(_shieldsController.text) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final db = DatabaseService.instance;
    final territory = Territory(
      id: widget.territory?.id,
      divisionId: widget.territory?.divisionId ?? widget.divisionId!,
      name: _nameController.text.trim(),
      area: _parsedArea!,
      assignedShields: _parsedShields,
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
    final calc = (area != null && area > 0)
        ? CalculationService.calculateTerritory(
            Territory(
              divisionId: widget.divisionId ?? widget.territory?.divisionId ?? 0,
              name: '',
              area: area,
              assignedShields: _parsedShields,
            ),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.territory == null ? 'Нова територія' : 'Редагувати територію'),
        actions: [
          PageHelpAction(
            title: 'Територія (ТВУЗ)',
            points: [
              'Площа території визначає, скільки пожежних щитів для неї потрібно (розрахунок нижче форми).',
              '"Наявно щитів" — скільки фактично встановлено; недостача = потрібно мінус наявно.',
              'Назва, площа й наявна кількість редагуються прямо тут у будь-який момент.',
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _shieldsController,
                decoration: const InputDecoration(labelText: 'Наявно щитів (фактично встановлено)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
              ),
              if (calc != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Потрібно пожежних щитів: ${calc.requiredShields}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                      ),
                      if (calc.shortageShields > 0)
                        Text(
                          'Недостача: ${calc.shortageShields}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                        )
                      else
                        const Text('Забезпечено достатньо', style: TextStyle(color: Colors.green)),
                    ],
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
