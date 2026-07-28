import 'package:flutter/material.dart';

import '../models/building.dart';
import '../models/division.dart';
import '../models/territory.dart';
import '../services/calculation_service.dart';
import '../services/database_service.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/page_help.dart';
import 'all_extinguishers_screen.dart';
import 'building_screen.dart';
import 'select_extinguisher_target_screen.dart';
import 'territory_form_screen.dart';

class HomeScreen extends StatefulWidget {
  final Division division;

  const HomeScreen({super.key, required this.division});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService.instance;
  List<Building> _buildings = [];
  List<Territory> _territories = [];
  int _extinguisherCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final buildings = await _db.getBuildingsForDivision(widget.division.id!);
    final territories = await _db.getTerritoriesForDivision(widget.division.id!);

    // Кількість вогнегасників саме цього управління — рахуємо через будівлі/поверхи.
    var count = 0;
    for (final building in buildings) {
      final floors = await _db.getFloorsForBuilding(building.id!);
      for (final floor in floors) {
        count += (await _db.getExtinguishersForFloor(floor.id!)).length;
        final rooms = await _db.getRoomsForFloor(floor.id!);
        for (final room in rooms.where((r) => r.hasComputer)) {
          count += (await _db.getExtinguishersForRoom(room.id!)).length;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _buildings = buildings;
      _territories = territories;
      _extinguisherCount = count;
      _loading = false;
    });
  }

  Future<void> _addOrEditBuilding({Building? building}) async {
    final controller = TextEditingController(text: building?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(building == null ? 'Нова будівля' : 'Перейменувати будівлю'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Назва будівлі'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(building == null ? 'Додати' : 'Зберегти'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (building == null) {
      await _db.insertBuilding(Building(divisionId: widget.division.id!, name: name));
    } else {
      await _db.updateBuilding(building.copyWith(name: name));
    }
    _reload();
  }

  Future<void> _deleteBuilding(Building building) async {
    if (!await confirmDelete(context, building.name)) return;
    await _db.deleteBuilding(building.id!);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.division.name),
        actions: [
          PageHelpAction(
            title: widget.division.name,
            points: [
              'Будівлі — рахують вогнегасники по поверхах/кабінетах. Натисни, щоб зайти; олівець — '
                  'перейменувати; кошик — видалити.',
              'Територія (ТВУЗ) — рахує потрібну кількість пожежних щитів за площею. Натисни, щоб '
                  'редагувати назву/площу.',
              'Вогнегасники внизу списку — перегляд/додавання/редагування усіх вогнегасників цього '
                  'управління, з фільтрами і CSV.',
              'Кнопки внизу праворуч — додати вогнегасник, територію або будівлю.',
            ],
          ),
        ],
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Будівлі', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          if (_buildings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Ще немає жодної будівлі'),
            ),
          for (final building in _buildings)
            ListTile(
              leading: const Icon(Icons.apartment),
              title: Text(building.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _addOrEditBuilding(building: building),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteBuilding(building),
                  ),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BuildingScreen(building: building)),
              ).then((_) => _reload()),
            ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Територія (ТВУЗ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          if (_territories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Ще немає жодної території'),
            ),
          for (final territory in _territories)
            Builder(builder: (context) {
              final calc = CalculationService.calculateTerritory(territory);
              return ListTile(
                leading: const Icon(Icons.terrain),
                title: Text(territory.name),
                subtitle: Text(
                  '${territory.area.toStringAsFixed(0)} м² · потрібно щитів: ${calc.requiredShields}',
                ),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TerritoryFormScreen(territory: territory)),
                  );
                  _reload();
                },
              );
            }),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Вогнегасники', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ListTile(
            leading: const Icon(Icons.local_fire_department_outlined),
            title: Text('Усього зареєстровано: $_extinguisherCount шт.'),
            subtitle: const Text('Перегляд, додавання, редагування'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AllExtinguishersScreen(initialDivisionId: widget.division.id),
                ),
              );
              _reload();
            },
          ),
          const SizedBox(height: 220),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'addExtinguisher',
            icon: const Icon(Icons.local_fire_department_outlined),
            label: const Text('Вогнегасник'),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SelectExtinguisherTargetScreen(initialDivisionId: widget.division.id),
                ),
              );
              _reload();
            },
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'addTerritory',
            icon: const Icon(Icons.terrain),
            label: const Text('Територія'),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TerritoryFormScreen(divisionId: widget.division.id),
                ),
              );
              _reload();
            },
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'addBuilding',
            icon: const Icon(Icons.apartment),
            label: const Text('Будівля'),
            onPressed: () => _addOrEditBuilding(),
          ),
        ],
      ),
    );
  }
}
