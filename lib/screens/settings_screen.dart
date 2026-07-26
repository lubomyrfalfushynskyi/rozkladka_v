import 'package:flutter/material.dart';

import '../models/extinguisher_type.dart';
import '../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseService.instance;
  Set<ExtinguisherType> _allowed = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final types = await _db.getAllowedGeneralTypes();
    if (!mounted) return;
    setState(() {
      _allowed = types.toSet();
      _loading = false;
    });
  }

  Future<void> _toggle(ExtinguisherType type, bool value) async {
    setState(() {
      if (value) {
        _allowed.add(type);
      } else if (_allowed.length > 1) {
        _allowed.remove(type);
      }
    });
    await _db.setAllowedGeneralTypes(_allowed.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Налаштування')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Дозволені типи вогнегасників для загальних приміщень',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Стосується лише звичайних приміщень (без комп\'ютерної техніки) '
                    'та загальної площі поверхів. Має бути обраний хоча б один тип.',
                  ),
                ),
                for (final type in ExtinguisherType.values)
                  CheckboxListTile(
                    title: Text(type.label),
                    value: _allowed.contains(type),
                    onChanged: (v) => _toggle(type, v ?? false),
                  ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Кабінети з комп\'ютерною технікою',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Завжди обслуговуються вогнегасником ВВК (вуглекислотним) — '
                    'це фіксоване правило, не налаштовується тут.',
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}
