import 'package:flutter/material.dart';

import '../models/division.dart';
import '../services/database_service.dart';
import '../widgets/confirm_delete.dart';
import '../widgets/page_help.dart';
import 'all_extinguishers_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'summary_screen.dart';

class DivisionListScreen extends StatefulWidget {
  const DivisionListScreen({super.key});

  @override
  State<DivisionListScreen> createState() => _DivisionListScreenState();
}

class _DivisionListScreenState extends State<DivisionListScreen> {
  final _db = DatabaseService.instance;
  List<Division> _divisions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final divisions = await _db.getDivisions();
    if (!mounted) return;
    setState(() {
      _divisions = divisions;
      _loading = false;
    });
  }

  Future<void> _addOrEditDivision({Division? division}) async {
    final controller = TextEditingController(text: division?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(division == null ? 'Нове управління' : 'Перейменувати управління'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Назва управління'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(division == null ? 'Додати' : 'Зберегти'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    if (division == null) {
      await _db.insertDivision(Division(name: name));
    } else {
      await _db.updateDivision(division.copyWith(name: name));
    }
    _reload();
  }

  Future<void> _deleteDivision(Division division) async {
    if (!await confirmDelete(context, division.name)) return;
    await _db.deleteDivision(division.id!);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('РозкладкаВ'),
        actions: [
          PageHelpAction(
            title: 'РозкладкаВ',
            points: [
              'Головна сторінка — список Управлінь. Кожне Управління містить свої будівлі й території.',
              'Натисни на Управління, щоб перейти в нього; олівець — перейменувати; кошик — видалити '
                  '(з підтвердженням, разом з усім вмістом).',
              '"+ Управління" внизу — додати нове.',
              'Іконка вогнегасника вгорі — звіт по вогнегасниках одразу по всіх управліннях, з CSV '
                  'експортом/імпортом.',
              'Іконка звіту — зведений розрахунок недостачі по всіх управліннях.',
              'Іконка шестерні — налаштування (дозволені типи, номенклатура моделей).',
            ],
          ),
          IconButton(
            icon: const Icon(Icons.local_fire_department_outlined),
            tooltip: 'Вогнегасники (усі управління) — CSV',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AllExtinguishersScreen()),
              );
              _reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.summarize),
            tooltip: 'Зведений звіт',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SummaryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Налаштування',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              _reload();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('Управління', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                if (_divisions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Ще немає жодного управління. Натисни "+" щоб додати перше.'),
                  ),
                for (final division in _divisions)
                  ListTile(
                    leading: const Icon(Icons.account_balance_outlined),
                    title: Text(division.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _addOrEditDivision(division: division),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteDivision(division),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => HomeScreen(division: division)),
                    ).then((_) => _reload()),
                  ),
                const SizedBox(height: 80),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Управління'),
        onPressed: () => _addOrEditDivision(),
      ),
    );
  }
}
