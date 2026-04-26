import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import '../models/live_data.dart';
import '../models/purity_calculation_method.dart';

class HistoryNotifier extends StateNotifier<List<HistoryEntry>> {
  Database? _db;

  HistoryNotifier() : super([]) {
    _initDb();
  }

  Future<void> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'puresense_history.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE history (
          id TEXT PRIMARY KEY,
          type TEXT,
          label TEXT,
          result TEXT,
          timestamp TEXT
        )
      ''');
    });
    await _load();
  }

  Future<void> _load() async {
    if (_db == null) return;
    final rows = await _db!.query('history', orderBy: 'timestamp DESC');
    final entries = rows
        .map((row) => HistoryEntry(
              id: row['id'] as String,
              type: row['type'] as String,
              label: row['label'] as String,
              result: row['result'] as String,
              timestamp: DateTime.parse(row['timestamp'] as String),
            ))
        .toList();
    state = entries;
  }

  Future<void> addEntry(String type, String label, dynamic result) async {
    if (_db == null) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final resultStr = jsonEncode(_serializeResult(result));
    await _db!.insert('history', {
      'id': id,
      'type': type,
      'label': label,
      'result': resultStr,
      'timestamp': DateTime.now().toIso8601String(),
    });
    await _load();
  }

  Future<void> deleteEntry(String id) async {
    if (_db == null) return;
    await _db!.delete('history', where: 'id = ?', whereArgs: [id]);
    await _load();
  }

  Future<void> clearAll() async {
    if (_db == null) return;
    await _db!.delete('history');
    await _load();
  }

  /// Export all history entries to CSV and return the file path
  Future<String> exportToCsv() async {
    final headers = [
      'Timestamp',
      'Type',
      'Label',
      'Mean ADC',
      'Karat',
      'Purity %',
      'Density (g/cm³)',
      'Metal Label',
      'Air Weight (g)',
      'Water Weight (g)',
      'Submerged Weight (g)',
      'Buoyancy (g)',
      'Confidence %',
      'Verdict',
    ];

    final rows = <List<String>>[headers];

    for (final entry in state) {
      final data = entry.result is String
          ? jsonDecode(entry.result as String) as Map<String, dynamic>
          : <String, dynamic>{};

      final kind = data['kind'] ?? entry.type;

      rows.add([
        entry.timestamp.toIso8601String(),
        kind,
        entry.label,
        data['meanADC']?.toString() ?? '',
        data['karat']?.toString() ?? '',
        data['purityPercent']?.toString() ?? '',
        data['density']?.toString() ?? '',
        data['metalLabel']?.toString() ?? '',
        data['wAir']?.toString() ?? '',
        data['wWater']?.toString() ?? '',
        data['wSubmerged']?.toString() ?? '',
        data['buoyancy']?.toString() ?? '',
        data['confidence']?.toString() ?? '',
        data['verdict']?.toString() ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(join(dir.path, 'puresense_export.csv'));
    await file.writeAsString(csv);
    return file.path;
  }

  Map<String, dynamic> _serializeResult(dynamic result) {
    if (result is PurityResult) {
      return {
        'kind': 'purity',
        'outcome': result.outcome.toString(),
        'calculationMethod': result.calculationMethod.prefsValue,
        'meanADC': result.meanADC,
        'karat': result.karat,
        'purityPercent': result.purityPercent,
        'distributionGold': result.distributionGold,
        'distributionLeft': result.distributionLeft,
        'distributionRight': result.distributionRight,
        'detectedMetal': result.detectedMetal?.metal.metalName,
        'confidence': result.detectedMetal?.confidence,
        'statistical': result.statisticalResult == null
            ? null
            : {
                'adc0': result.statisticalResult!.adc0,
                'slope': result.statisticalResult!.slope,
                'rawMean': result.statisticalResult!.rawMean,
                'residualVariance': result.statisticalResult!.residualVariance,
                'residualStdDev': result.statisticalResult!.residualStdDev,
                'confidence': result.statisticalResult!.confidence,
                'sampleCount': result.statisticalResult!.sampleCount,
                'durationSeconds': result.statisticalResult!.durationSeconds,
                'rSquared': result.statisticalResult!.rSquared,
              },
      };
    }
    if (result is DensityResult) {
      return {
        'kind': 'density',
        'density': result.density,
        'metalLabel': result.metalLabel,
        'wAir': result.wAir,
        'wWater': result.wWater,
        'wSubmerged': result.wSubmerged,
        'buoyancy': result.buoyancy,
      };
    }
    if (result is FullAnalysisResult) {
      return {
        'kind': 'full',
        'density': _serializeResult(result.density),
        'purity': _serializeResult(result.purity),
        'verdict': result.verdict,
      };
    }
    if (result is MetalIdentificationResult) {
      return {
        'kind': 'metalId',
        'meanADC': result.meanADC,
        'bestMatch': result.matches.isNotEmpty
            ? result.matches.first.metal.metalName
            : null,
        'confidence':
            result.matches.isNotEmpty ? result.matches.first.confidence : null,
      };
    }
    return {};
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<HistoryEntry>>((ref) {
  return HistoryNotifier();
});
