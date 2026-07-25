import 'package:flutter/material.dart';

import '../models/building.dart';
import '../models/territory.dart';
import '../services/calculation_service.dart';
import '../services/database_service.dart';
import 'building_screen.dart';
import 'summary_screen.dart';
import 'territory_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService.instance;
  List<Building> _buildings = [];
  List<Territory> _territories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final buildings = await _db.getBuildings();
    final territories = await _db.getTerritories();
    if (!mounted) return;
    setState(() {
      _buildings = buildings;
      _territories = territories;
      _loading = false;
    });
  }

  Future<void> _addBuilding() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Нова будівля'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Назва будівлі'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Додати'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _db.insertBuilding(Building(name: name));
    _reload();
  }

  Future<void> _deleteBuilding(Building building) async {
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
        title: const Text('Облік вогнегасників'),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize),
            tooltip: 'Зведений звіт',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SummaryScreen()),
            ),
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
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteBuilding(building),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => BuildingScreen(building: building)),
              ).then((_) => _reload()),
            ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('Територія (ТУЗ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FloatingActionButton.extended(
              heroTag: 'addTerritory',
              icon: const Icon(Icons.terrain),
              label: const Text('Територія'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TerritoryFormScreen()),
                );
                _reload();
              },
            ),
          ),
          FloatingActionButton.extended(
            heroTag: 'addBuilding',
            icon: const Icon(Icons.apartment),
            label: const Text('Будівля'),
            onPressed: _addBuilding,
          ),
        ],
      ),
    );
  }
}
