import 'package:flutter/material.dart';

import '../models/extinguisher.dart';
import '../models/extinguisher_type.dart';
import '../services/database_service.dart';
import 'extinguisher_form_screen.dart';

class ExtinguisherListScreen extends StatefulWidget {
  final String title;
  final int? roomId;
  final int? floorId;
  final List<ExtinguisherType> allowedTypes;

  const ExtinguisherListScreen({
    super.key,
    required this.title,
    this.roomId,
    this.floorId,
    required this.allowedTypes,
  }) : assert(
          (roomId == null) != (floorId == null),
          'Список вогнегасників має бути прив\'язаний або до кабінету, або до поверху',
        );

  @override
  State<ExtinguisherListScreen> createState() => _ExtinguisherListScreenState();
}

class _ExtinguisherListScreenState extends State<ExtinguisherListScreen> {
  final _db = DatabaseService.instance;
  List<Extinguisher> _extinguishers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = widget.roomId != null
        ? await _db.getExtinguishersForRoom(widget.roomId!)
        : await _db.getExtinguishersForFloor(widget.floorId!);
    if (!mounted) return;
    setState(() {
      _extinguishers = list;
      _loading = false;
    });
  }

  Future<void> _deleteExtinguisher(Extinguisher e) async {
    await _db.deleteExtinguisher(e.id!);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (_extinguishers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Ще немає жодного вогнегасника'),
                  ),
                for (final e in _extinguishers)
                  ListTile(
                    leading: const Icon(Icons.local_fire_department_outlined),
                    title: Text('№${e.id} · ${e.type.code} · ${e.capacityLiters.toStringAsFixed(1)} л'),
                    subtitle: Text('Заводський: ${e.serialNumber} · Інвентарний: ${e.inventoryNumber}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ExtinguisherFormScreen(
                                  roomId: widget.roomId,
                                  floorId: widget.floorId,
                                  allowedTypes: widget.allowedTypes,
                                  extinguisher: e,
                                ),
                              ),
                            );
                            _reload();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteExtinguisher(e),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Вогнегасник'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExtinguisherFormScreen(
                roomId: widget.roomId,
                floorId: widget.floorId,
                allowedTypes: widget.allowedTypes,
              ),
            ),
          );
          _reload();
        },
      ),
    );
  }
}
