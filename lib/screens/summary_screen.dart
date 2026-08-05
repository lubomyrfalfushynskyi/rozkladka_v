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
///
/// Відображення — воронка "об'єкт — наявно/потреба": на кожному рівні
/// фільтра показується підсумок і розбивка по наступному рівню вниз (усі
/// управління → по управліннях → по будівлях/територіях → по поверхах →
/// по кабінетах). Усі три категорії (речовина/ВВК/щити) показуються завжди
/// — якщо на рівні для категорії нема об'єктів, замість таблиці показується
/// пояснення, а не порожнеча.
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

  final Set<FunnelCategory> _selectedCategories = {
    FunnelCategory.substance,
    FunnelCategory.vvk,
    FunnelCategory.shields,
  };

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
          floorEntries.add(
            FloorSummaryEntry(
              divisionId: division.id!,
              divisionName: division.name,
              buildingId: building.id!,
              buildingName: building.name,
              floor: floor,
              calc: calc,
            ),
          );
        }
      }

      final territories = await _db.getTerritoriesForDivision(division.id!);
      for (final Territory territory in territories) {
        territoryEntries.add(
          TerritorySummaryEntry(
            divisionId: division.id!,
            divisionName: division.name,
            calc: CalculationService.calculateTerritory(territory),
          ),
        );
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

  List<FunnelTable> get _allTables => FunnelBuilder.build(
        floorEntries: _filteredFloorEntries,
        territoryEntries: _filteredTerritoryEntries,
        filterDivisionId: _filterDivisionId,
        filterBuildingId: _filterBuildingId,
        filterFloorId: _filterFloorId,
      );

  List<FunnelTable> get _visibleTables =>
      _allTables.where((t) => _selectedCategories.contains(t.category)).toList();

  PdfReportMeta get _reportMeta {
    final entries = _filteredFloorEntries;
    final territories = _filteredTerritoryEntries;
    return PdfReportMeta(
      divisions: entries.map((e) => e.divisionId).toSet().union(territories.map((e) => e.divisionId).toSet()).length,
      buildings: entries.map((e) => e.buildingId).toSet().length,
      floors: entries.map((e) => e.floor.id).toSet().length,
      computerRooms: entries.fold<int>(0, (s, e) => s + e.calc.computerRooms.length),
      territories: territories.length,
    );
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

  /// Звіт-CSV — лише вогнегасники, для читання (напр. в Excel), без
  /// технічних колонок і не призначений для імпорту назад.
  Future<void> _exportExtinguisherReport() async {
    final defaultName = 'Звіт_вогнегасники_${_sanitize(_scopeTitle)}_${_formatTimestamp(DateTime.now())}';
    final controller = TextEditingController(text: defaultName);
    final fileName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Звіт CSV (лише вогнегасники)'),
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

    final csvText = await CsvService.buildExtinguisherReport(
      divisionId: _filterDivisionId,
      buildingId: _filterBuildingId,
      floorId: _filterFloorId,
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.csv');
    await file.writeAsString(csvText);

    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Звіт — $fileName'),
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
    final fileName = 'Звіт_${_sanitize(_scopeTitle)}_${_formatTimestamp(DateTime.now())}';

    final bytes = await PdfService.buildSummaryReport(
      scopeTitle: _scopeTitle,
      tables: _visibleTables,
      meta: _reportMeta,
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

    final visibleTables = _visibleTables;
    final hasShortage = visibleTables.any((t) => t.hasShortage);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика'),
        actions: [
          PageHelpAction(
            title: 'Статистика',
            points: [
              'Фільтри Управління/Будівля/Поверх звужують розрахунок і звіти до потрібного рівня — '
                  'нічого не обрано = по всіх управліннях разом.',
              'Кожна таблиця — об\'єкт і дріб наявно/потреба: перший рядок "Всього" — підсумок '
                  'поточного рівня, решта рядків — розбивка по наступному рівню вниз (управління → '
                  'будівлі → поверхи → кабінети). Червоний колір — недостача.',
              'Показуються завжди всі три категорії (речовина/ВВК/щити) — якщо для категорії на '
                  'цьому рівні нема об\'єктів, замість таблиці буде пояснення, чому саме.',
              'Території (щити) рахуються лише на рівні управління чи вище — вони не належать '
                  'конкретній будівлі/поверху. Наявна кількість щитів редагується на сторінці самої території.',
              'Чекбокси над таблицями керують тим, що показано на екрані і що потрапить у PDF-звіт — '
                  'зручно, якщо якоюсь категорією ділитись не треба. На CSV-експорт (повне дерево '
                  'даних, резервна копія) чекбокси не впливають.',
              'Експорт CSV — повне дерево даних (управління/будівлі/поверхи з площами/кабінети/'
                  'вогнегасники/території) для передачі чи резервної копії; Імпорт читає такий файл і '
                  'створює чи оновлює об\'єкти автоматично.',
              'Звіт CSV — лише вогнегасники, без технічних колонок і без порожніх заглушок, для '
                  'читання (напр. в Excel). Цей файл назад не імпортується — він для перегляду, не '
                  'для передачі даних.',
              'Експорт PDF — друкована версія обраних таблиць (з урахуванням чекбоксів) для офіційної '
                  'звітності.',
            ],
          ),
          IconButton(icon: const Icon(Icons.file_upload_outlined), tooltip: 'Імпорт CSV', onPressed: _importCsv),
          IconButton(icon: const Icon(Icons.ios_share), tooltip: 'Експорт CSV', onPressed: _exportCsv),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Звіт CSV (лише вогнегасники)',
            onPressed: _exportExtinguisherReport,
          ),
          IconButton(icon: const Icon(Icons.picture_as_pdf_outlined), tooltip: 'Експорт PDF', onPressed: _exportPdf),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final category in FunnelCategory.values)
                  FilterChip(
                    label: Text(_categoryLabel(category)),
                    selected: _selectedCategories.contains(category),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _selectedCategories.add(category);
                      } else {
                        _selectedCategories.remove(category);
                      }
                    }),
                  ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                'Чекбокси керують переглядом і PDF. CSV завжди містить повне дерево даних.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),
            if (hasShortage)
              Card(
                color: Colors.red.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Виявлено недостачу — деталі в таблицях нижче',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (hasShortage) const SizedBox(height: 12),
            if (visibleTables.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Усі категорії приховані чекбоксами вище.'),
              ),
            for (final table in visibleTables) _FunnelTableCard(table: table),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(FunnelCategory category) {
    switch (category) {
      case FunnelCategory.substance:
        return 'Вогнегасна речовина';
      case FunnelCategory.vvk:
        return 'Вогнегасники ВВК';
      case FunnelCategory.shields:
        return 'Пожежні щити';
    }
  }
}

/// Одна таблиця-воронка: заголовок + рядок "Всього" + розбивка по об'єктах,
/// або — якщо на цьому рівні для категорії нема об'єктів — пояснення чому.
class _FunnelTableCard extends StatelessWidget {
  final FunnelTable table;

  const _FunnelTableCard({required this.table});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${table.title}, ${table.unit}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (table.isEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Дані відсутні в системі: ${table.emptyMessage}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              )
            else ...[
              const _FunnelRowWidget(object: 'Об\'єкт', fraction: 'Наявно / Потреба', isHeader: true),
              const Divider(height: 12),
              _FunnelRowWidget(
                object: table.total.object,
                fraction: table.total.fractionLabel,
                isBold: true,
                fractionColor: table.total.shortage > 0 ? Colors.red : null,
              ),
              for (final row in table.rows) ...[
                const Divider(height: 12),
                _FunnelRowWidget(
                  object: row.object,
                  fraction: row.fractionLabel,
                  fractionColor: row.shortage > 0 ? Colors.red : null,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _FunnelRowWidget extends StatelessWidget {
  final String object;
  final String fraction;
  final bool isHeader;
  final bool isBold;
  final Color? fractionColor;

  const _FunnelRowWidget({
    required this.object,
    required this.fraction,
    this.isHeader = false,
    this.isBold = false,
    this.fractionColor,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontWeight: (isHeader || isBold) ? FontWeight.bold : FontWeight.normal,
      color: isHeader ? Theme.of(context).colorScheme.onSurfaceVariant : null,
      fontSize: isHeader ? 12 : 15,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 6, child: Text(object, style: baseStyle)),
        Expanded(
          flex: 5,
          child: Text(
            fraction,
            style: baseStyle.copyWith(color: fractionColor ?? baseStyle.color),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
