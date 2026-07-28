import 'package:flutter/material.dart';

import '../models/floor.dart';
import '../models/room.dart';
import '../services/calculation_service.dart';
import '../services/database_service.dart';
import '../widgets/page_help.dart';

class RoomFormScreen extends StatefulWidget {
  final Floor floor;
  final Room? room;

  const RoomFormScreen({super.key, required this.floor, this.room});

  @override
  State<RoomFormScreen> createState() => _RoomFormScreenState();
}

class _RoomFormScreenState extends State<RoomFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _areaController;
  bool _hasComputer = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room?.name ?? '');
    _areaController = TextEditingController(
      text: widget.room != null ? widget.room!.area.toStringAsFixed(0) : '',
    );
    _hasComputer = widget.room?.hasComputer ?? false;
  }

  double? get _parsedArea => double.tryParse(_areaController.text.replaceAll(',', '.'));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final db = DatabaseService.instance;
    final room = Room(
      id: widget.room?.id,
      floorId: widget.floor.id!,
      name: _nameController.text.trim(),
      area: _parsedArea!,
      hasComputer: _hasComputer,
    );
    if (widget.room == null) {
      await db.insertRoom(room);
    } else {
      await db.updateRoom(room);
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final area = _parsedArea;
    final preview = (_hasComputer && area != null && area > 0)
        ? CalculationService.extinguisherClassFor(area)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room == null ? 'Новий кабінет' : 'Редагувати кабінет'),
        actions: [
          PageHelpAction(
            title: 'Кабінет',
            points: [
              'Площа використовується для розрахунку норми вогнегасника.',
              'Якщо є комп\'ютерна техніка — кабінет обслуговується окремим вогнегасником ВВК за класом, '
                  'що визначається площею (показується нижче форми).',
              'Видалити кабінет можна зі списку на сторінці поверху (кошик поруч із записом).',
            ],
          ),
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
                decoration: const InputDecoration(labelText: 'Назва / номер кабінету'),
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Є комп\'ютерна техніка'),
                value: _hasComputer,
                onChanged: (v) => setState(() => _hasComputer = v),
              ),
              if (preview != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Норма для цього кабінету: $preview',
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
