import 'package:flutter/material.dart';

import '../models/extinguisher.dart';
import '../models/extinguisher_type.dart';
import '../services/database_service.dart';

class ExtinguisherFormScreen extends StatefulWidget {
  final int? roomId;
  final int? floorId;
  final List<ExtinguisherType> allowedTypes;
  final Extinguisher? extinguisher;

  const ExtinguisherFormScreen({
    super.key,
    this.roomId,
    this.floorId,
    required this.allowedTypes,
    this.extinguisher,
  }) : assert(
          (roomId == null) != (floorId == null),
          'Вогнегасник має належати або кабінету, або поверху',
        );

  @override
  State<ExtinguisherFormScreen> createState() => _ExtinguisherFormScreenState();
}

class _ExtinguisherFormScreenState extends State<ExtinguisherFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _serialController;
  late final TextEditingController _inventoryController;
  late final TextEditingController _capacityController;
  late ExtinguisherType _type;

  @override
  void initState() {
    super.initState();
    _serialController = TextEditingController(text: widget.extinguisher?.serialNumber ?? '');
    _inventoryController = TextEditingController(text: widget.extinguisher?.inventoryNumber ?? '');
    _capacityController = TextEditingController(
      text: widget.extinguisher != null ? widget.extinguisher!.capacityLiters.toStringAsFixed(1) : '',
    );
    _type = widget.extinguisher?.type ?? widget.allowedTypes.first;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final db = DatabaseService.instance;
    final extinguisher = Extinguisher(
      id: widget.extinguisher?.id,
      serialNumber: _serialController.text.trim(),
      inventoryNumber: _inventoryController.text.trim(),
      type: _type,
      capacityLiters: double.parse(_capacityController.text.replaceAll(',', '.')),
      roomId: widget.roomId,
      floorId: widget.floorId,
    );
    if (widget.extinguisher == null) {
      await db.insertExtinguisher(extinguisher);
    } else {
      await db.updateExtinguisher(extinguisher);
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (widget.extinguisher?.id == null) return;
    await DatabaseService.instance.deleteExtinguisher(widget.extinguisher!.id!);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.extinguisher == null ? 'Новий вогнегасник' : 'Редагувати вогнегасник'),
        actions: [
          if (widget.extinguisher != null)
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
              if (widget.extinguisher?.id != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Ідентифікатор (№): ${widget.extinguisher!.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              DropdownButtonFormField<ExtinguisherType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Тип вогнегасника'),
                items: widget.allowedTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: widget.allowedTypes.length <= 1
                    ? null
                    : (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serialController,
                decoration: const InputDecoration(labelText: 'Заводський номер'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Обовʼязково' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _inventoryController,
                decoration: const InputDecoration(labelText: 'Інвентарний номер'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Обовʼязково' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _capacityController,
                decoration: const InputDecoration(labelText: 'Ємність, л (напр. 2 – 100)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (value == null || value <= 0) return 'Вкажіть коректну ємність';
                  return null;
                },
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
