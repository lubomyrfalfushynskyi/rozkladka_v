import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/building.dart';
import '../models/division.dart';
import '../models/extinguisher.dart';
import '../models/floor.dart';
import '../models/room.dart';
import '../models/summary_data.dart';
import '../models/territory.dart';
import '../services/calculation_service.dart';
import '../services/csv_service.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';
import '../widgets/page_help.dart';

/// Статистика й звітність — доступна на кожному рівні ієрархії (глобально,
/// управління, будівля, поверх). Тут же живуть CSV-експорт/імпорт і
/// PDF-звіт, бо не всі об'єкти мають вогнегасники (територія/щити), а
/// статистика потрібна на будь-якому рівні.
class SummaryScreen extends StatefulWidget {
  final int? initialDivisionId;
  final int? initialBuildingId;
  final int? initialFloorId;

  const SummaryScreen({
    super.key,
    this.initialDivisionId,
    this.initialBuildingId,
    this.initialFloorId,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final _db = DatabaseService.instance;
  bool _loading = true;
  List<Division> _divisions = [];
  Map<int, List<Building>> _buildingsByDivision = {};
  Map<int, List<Floor>> _floorsByBuilding = {};
  List<FloorSummaryEntry> _allFloorEntries = [];
  List<TerritorySummaryEntry> _allTerritoryEntries = [];

  int? _filterDivisionId;
  int? _filterBuildingId;
  int? _filterFloorId;
  int? _territoryFilterId;

  @override
  void initState() {
    super.initState();
    _filterDivisionId = widget.initialDivisionId;
    _filterBuildingId = widget.initialBuildingId;
    _filterFloorId = widget.initialFloorId;
    _reload();
  }

  Future<void> _reload() async {
    final divisions = await _db.getDivisions();
    final buildingsByDivision = <int, List<Building>>{};
    final floorsByBuilding = <int, List<Floor>>{};
    final floorEntries = <FloorSummaryEntry>[];
    final territoryEntries = <TerritorySummaryEntry>[];

    for (final Division division in divisions) {
      final buildings = await _db.getBuildingsForDivision(division.id!);
      buildingsByDivision[division.id!] = buildings;
      for (final Building building in buildings) {
        final floors = await _db.getFloorsForBuilding(building.id!);
        floorsByBuilding[building.id!] = floors;
        for (final Floor floor in floors) {
          final List<Room> rooms = await _db.getRoomsForFloor(floor.id!);
          final List<Extinguisher> floorExtinguishers = await _db.getExtinguishersForFloor(floor.id!);
          final byRoom = <int, List<Extinguisher>>{};
          for (final room in rooms) {
            if (room.hasComputer && room.id != null) {
              byRoom[room.id!] = await _db.getExtinguishersForRoom(room.id!);
            }
          }
          final calc = CalculationService.calculateFloor(
            floor,
            rooms,
            floorExtinguishers: floorExtinguishers,
            extinguishersByRoomId: byRoom,
          );
          floorEntries.add(FloorSummaryEntry(
            divisionId: division.id!,
            divisionName: division.name,
            buildingId: building.id!,
            buildingName: building.name,
            floor: floor,
            calc: calc,
          ));
        }
      }

      final territories = await _db.getTerritoriesForDivision(division.id!);
      for (final Territory territory in territories) {
        territoryEntries.add(TerritorySummaryEntry(
          divisionId: division.id!,
          divisionName: division.name,
          calc: CalculationService.calculateTerritory(territory),
        ));
      }
    }

    if (_filterDivisionId == null && _filterBuildingId != null) {
      for (final entry in buildingsByDivision.entries) {
        if (entry.value.any((b) => b.id == _filterBuildingId)) {
          _filterDivisionId = entry.key;
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _divisions = divisions;
      _buildingsByDivision = buildingsByDivision;
      _floorsByBuilding = floorsByBuilding;
      _allFloorEntries = floorEntries;
      _allTerritoryEntries = territoryEntries;
      _loading = false;
    });
  }

  List<FloorSummaryEntry> get _filteredFloorEntries => _allFloorEntries.where((e) {
        if (_filterDivisionId != null && e.divisionId != _filterDivisionId) return false;
        if (_filterBuildingId != null && e.buildingId != _filterBuildingId) return false;
        if (_filterFloorId != null && e.floor.id != _filterFloorId) return false;
        return true;
      }).toList();

  /// Території належать управлінню, а не будівлі/поверху — тож видимі лише
  /// коли не звужено до конкретної будівлі/поверху.
  List<TerritorySummaryEntry> get _filteredTerritoryEntries {
    if (_filterBuildingId != null || _filterFloorId != null) return [];
    return _allTerritoryEntries.where((e) => _filterDivisionId == null || e.divisionId == _filterDivisionId).toList();
  }

  String get _scopeTitle {
    if (_filterFloorId != null) {
      final floor = _floorsByBuilding[_filterBuildingId]?.firstWhere((f) => f.id == _filterFloorId);
      return floor?.name ?? 'поверх';
    }
    if (_filterBuildingId != null) {
      final building = _buildingsByDivision[_filterDivisionId]?.firstWhere((b) => b.id == _filterBuildingId);
      return building?.name ?? 'будівля';
    }
    if (_filterDivisionId != null) {
      final division = _divisions.firstWhere((d) => d.id == _filterDivisionId);
      return division.name;
    }
    return 'усі управління';
  }

  String _sanitize(String name) => name.trim().replaceAll(RegExp(r'\s+'), '_');

  String _formatTimestamp(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}_${two(dt.hour)}${two(dt.minute)}';
  }

  Future<void> _exportCsv() async {
    final defaultName = 'Вогнегасники_${_sanitize(_scopeTitle)}_${_formatTimestamp(DateTime.now())}';
    final controller = TextEditingController(text: defaultName);
    final fileName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Експорт у CSV'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Назва файлу'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати')),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              controller.text.trim().isEmpty ? defaultName : controller.text.trim(),
            ),
            child: const Text('Експортувати'),
          ),
        ],
      ),
    );
    if (fileName == null) return;
    if (!mounted) return;

    final csvText = await CsvService.buildCsv(
      divisionId: _filterDivisionId,
      buildingId: _filterBuildingId,
      floorId: _filterFloorId,
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.csv');
    await file.writeAsString(csvText);

    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Дані — $fileName'),
    );
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final csvText = await file.readAsString();
    final importResult = await CsvService.importCsv(csvText);
    await _reload();

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Імпорт завершено'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Імпортовано/оновлено: ${importResult.imported} шт.'),
              if (importResult.skipped.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Пропущено (${importResult.skipped.length}):', style: const TextStyle(fontWeight: FontWeight.bold)),
                for (final s in importResult.skipped)
                  Padding(padding: const EdgeInsets.only(top: 2), child: Text('• $s')),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Гаразд')),
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    final floorEntries = _filteredFloorEntries;
    final territoryEntries = _filteredTerritoryEntries;
    final totals = SummaryTotals.fromFloorEntries(floorEntries);
    final fileName = 'Звіт_${_sanitize(_scopeTitle)}_${_formatTimestamp(DateTime.now())}';

    final bytes = await PdfService.buildSummaryReport(
      scopeTitle: _scopeTitle,
      totals: totals,
      floorEntries: floorEntries,
      territoryEntries: territoryEntries,
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.pdf');
    await file.writeAsBytes(bytes);

    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Звіт — $fileName'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final buildings = _filterDivisionId != null ? (_buildingsByDivision[_filterDivisionId!] ?? []) : <Building>[];
    final floors = _filterBuildingId != null ? (_floorsByBuilding[_filterBuildingId!] ?? []) : <Floor>[];
    final floorEntries = _filteredFloorEntries;
    final territoryEntries = _filteredTerritoryEntries;
    final totals = SummaryTotals.fromFloorEntries(floorEntries);

    final filteredTerritoryEntries = _territoryFilterId == null
        ? territoryEntries
        : territoryEntries.where((t) => t.calc.territory.id == _territoryFilterId).toList();
    final shownShields = filteredTerritoryEntries.fold<int>(0, (sum, t) => sum + t.calc.requiredShields);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика'),
        actions: [
          PageHelpAction(
            title: 'Статистика',
            points: [
              'Фільтри Управління/Будівля/Поверх звужують розрахунок і звіти до потрібного рівня — '
                  'нічого не обрано = по всіх управліннях разом.',
              'Території (щити) показуються лише на рівні управління чи вище — вони не належать '
                  'конкретній будівлі/поверху.',
              'Експорт CSV — повне дерево даних (управління/будівлі/поверхи з площами/кабінети/'
                  'вогнегасники/території) для передачі чи резервної копії; Імпорт читає такий файл і '
                  'створює чи оновлює об\'єкти автоматично.',
              'Експорт PDF — друкована версія цього звіту для офіційної звітності.',
            ],
          ),
          IconButton(icon: const Icon(Icons.file_upload_outlined), tooltip: 'Імпорт CSV', onPressed: _importCsv),
          IconButton(icon: const Icon(Icons.ios_share), tooltip: 'Експорт CSV', onPressed: _exportCsv),
          IconButton(icon: const Icon(Icons.picture_as_pdf_outlined), tooltip: 'Експорт PDF', onPressed: _exportPdf),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int?>(
                    initialValue: _filterDivisionId,
                    decoration: const InputDecoration(labelText: 'Управління'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Усі управління')),
                      for (final d in _divisions) DropdownMenuItem<int?>(value: d.id, child: Text(d.name)),
                    ],
                    onChanged: (v) => setState(() {
                      _filterDivisionId = v;
                      _filterBuildingId = null;
                      _filterFloorId = null;
                      _territoryFilterId = null;
                    }),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    initialValue: _filterBuildingId,
                    decoration: const InputDecoration(labelText: 'Будівля'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Усі будівлі')),
                      for (final b in buildings) DropdownMenuItem<int?>(value: b.id, child: Text(b.name)),
                    ],
                    onChanged: _filterDivisionId == null
                        ? null
                        : (v) => setState(() {
                              _filterBuildingId = v;
                              _filterFloorId = null;
                            }),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    initialValue: _filterFloorId,
                    decoration: const InputDecoration(labelText: 'Поверх'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Усі поверхи')),
                      for (final f in floors) DropdownMenuItem<int?>(value: f.id, child: Text(f.name)),
                    ],
                    onChanged: _filterBuildingId == null ? null : (v) => setState(() => _filterFloorId = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (totals.hasShortage)
            Card(
              color: Colors.red.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          'Виявлено недостачу',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (totals.totalShortageLiters > 0)
                      Text('Бракує вогнегасної речовини (загальні приміщення): '
                          '${totals.totalShortageLiters.toStringAsFixed(1)} од.'),
                    if (totals.totalMissingRoomExtinguishers > 0)
                      Text('Бракує вогнегасників ВВК у кабінетах з ПК: '
                          '${totals.totalMissingRoomExtinguishers} шт.'),
                  ],
                ),
              ),
            ),
          if (totals.hasShortage) const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Загалом по будівлях', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Вогнегасна речовина (звичайні приміщення): ${totals.totalLiters.toStringAsFixed(0)} л'),
                  const SizedBox(height: 4),
                  const Text('Вогнегасники для кабінетів з ПК (за нормою):'),
                  if (totals.extinguisherCounts.isEmpty) const Text('  — немає кабінетів з ПК'),
                  for (final entry in totals.extinguisherCounts.entries)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Text('• ${entry.value} шт. — ${entry.key}'),
                    ),
                ],
              ),
            ),
          ),
          if (territoryEntries.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Територія (ТВУЗ)', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (territoryEntries.length > 1)
                      DropdownButtonFormField<int?>(
                        initialValue: _territoryFilterId,
                        decoration: const InputDecoration(labelText: 'Фільтр за площею (територією)'),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Усі території (сума)')),
                          for (final t in territoryEntries)
                            DropdownMenuItem<int?>(value: t.calc.territory.id, child: Text(t.calc.territory.name)),
                        ],
                        onChanged: (v) => setState(() => _territoryFilterId = v),
                      ),
                    const SizedBox(height: 8),
                    Text('Потрібно пожежних щитів: $shownShields'),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('Деталізація по поверхах', style: Theme.of(context).textTheme.titleMedium),
          if (floorEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Немає поверхів за обраним фільтром.'),
            ),
          for (final entry in floorEntries)
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: ListTile(
                title: Text('${entry.divisionName} / ${entry.buildingName} — ${entry.floor.name}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Залишкова площа: ${entry.calc.remainingArea.toStringAsFixed(0)} м²'),
                    Text('Потрібно: ${entry.calc.requiredLiters.toStringAsFixed(0)} л'),
                    Text('Наявно: ${entry.calc.assignedCapacityLiters.toStringAsFixed(1)} од.'),
                    if (entry.calc.shortageLiters > 0)
                      Text(
                        'Недостача: ${entry.calc.shortageLiters.toStringAsFixed(1)} од.',
                        style: const TextStyle(color: Colors.red),
                      ),
                    Text(
                      'Кабінетів з ПК: ${entry.calc.computerRooms.length}'
                      '${entry.calc.computerRooms.any((r) => r.shortageCount > 0) ? " (бракує вогнегасників у ${entry.calc.computerRooms.where((r) => r.shortageCount > 0).length})" : ""}',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
