import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/live_data.dart';
import '../models/purity_calculation_method.dart';
import '../utils/statistical_classifier.dart';

class HistoryNotifier extends StateNotifier<List<HistoryEntry>> {
  HistoryNotifier() : super([]) {
    _load();
  }

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File(join(dir.path, 'puresense_history.json'));
  }

  Future<void> _load() async {
    try {
      final file = await _file;
      if (!await file.exists()) return;
      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);
      
      final entries = jsonList.map((data) => HistoryEntry(
        id: data['id'] as String,
        type: data['type'] as String,
        label: data['label'] as String,
        result: _deserializeResult(data['result'] as String),
        timestamp: DateTime.parse(data['timestamp'] as String),
      )).toList();
      
      // Sort descending (newest first)
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      state = entries;
    } catch (e) {
      print('Error loading history: $e');
    }
  }

  Future<void> _save(List<HistoryEntry> entries) async {
    try {
      final file = await _file;
      final jsonList = entries.map((entry) => {
        'id': entry.id,
        'type': entry.type,
        'label': entry.label,
        'result': jsonEncode(_serializeResult(entry.result)),
        'timestamp': entry.timestamp.toIso8601String(),
      }).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('Error saving history: $e');
    }
  }

  Future<void> addEntry(String type, String label, dynamic result) async {
    final newEntry = HistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      label: label,
      result: result,
      timestamp: DateTime.now(),
    );
    final newState = [newEntry, ...state];
    state = newState;
    await _save(newState);
  }

  Future<void> deleteEntry(String id) async {
    final newState = state.where((e) => e.id != id).toList();
    state = newState;
    await _save(newState);
  }

  Future<void> clearAll() async {
    state = [];
    await _save([]);
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

  dynamic _deserializeResult(String resultJson) {
    try {
      final data = jsonDecode(resultJson) as Map<String, dynamic>;
      final kind = data['kind'] as String?;

      switch (kind) {
        case 'purity':
          final statistical = data['statistical'] as Map<String, dynamic>?;
          return PurityResult(
            outcome: _parseOutcome(data['outcome'] as String?),
            calculationMethod: _parseCalculationMethod(data['calculationMethod'] as String?),
            meanADC: data['meanADC'] as int? ?? 0,
            karat: data['karat'] as int? ?? 0,
            purityPercent: data['purityPercent'] as double? ?? 0.0,
            distributionGold: (data['distributionGold'] as num?)?.toInt() ?? 0,
            distributionLeft: (data['distributionLeft'] as num?)?.toInt() ?? 0,
            distributionRight: (data['distributionRight'] as num?)?.toInt() ?? 0,
            detectedMetal: null, // Would need metal reference to reconstruct
            otherMatches: [], // Would need metal reference to reconstruct
            timestamp: DateTime.now(),
            statisticalResult: statistical == null ? null : StatisticalResult(
              adc0: (statistical['adc0'] as num?)?.toDouble() ?? 0.0,
              slope: statistical['slope'] as double? ?? 0.0,
              rawMean: statistical['rawMean'] as double? ?? 0.0,
              residualVariance: statistical['residualVariance'] as double? ?? 0.0,
              residualStdDev: statistical['residualStdDev'] as double? ?? 0.0,
              confidence: statistical['confidence'] as double? ?? 0.0,
              sampleCount: statistical['sampleCount'] as int? ?? 0,
              durationSeconds: statistical['durationSeconds'] as double? ?? 0.0,
              rSquared: statistical['rSquared'] as double? ?? 0.0,
            ),
          );

        case 'density':
          return DensityResult(
            density: data['density'] as double? ?? 0.0,
            metalLabel: data['metalLabel'] as String? ?? '',
            wAir: data['wAir'] as double? ?? 0.0,
            wWater: data['wWater'] as double? ?? 0.0,
            wSubmerged: data['wSubmerged'] as double? ?? 0.0,
            buoyancy: data['buoyancy'] as double? ?? 0.0,
            timestamp: DateTime.now(),
          );

        case 'full':
          final densityData = data['density'] as Map<String, dynamic>?;
          final purityData = data['purity'] as Map<String, dynamic>?;
          return FullAnalysisResult(
            density: DensityResult(
              density: densityData?['density'] as double? ?? 0.0,
              metalLabel: densityData?['metalLabel'] as String? ?? '',
              wAir: densityData?['wAir'] as double? ?? 0.0,
              wWater: densityData?['wWater'] as double? ?? 0.0,
              wSubmerged: densityData?['wSubmerged'] as double? ?? 0.0,
              buoyancy: densityData?['buoyancy'] as double? ?? 0.0,
              timestamp: DateTime.now(),
            ),
            purity: PurityResult(
              outcome: _parseOutcome(purityData?['outcome'] as String?),
              calculationMethod: _parseCalculationMethod(purityData?['calculationMethod'] as String?),
              meanADC: purityData?['meanADC'] as int? ?? 0,
              karat: purityData?['karat'] as int? ?? 0,
              purityPercent: purityData?['purityPercent'] as double? ?? 0.0,
              distributionGold: (purityData?['distributionGold'] as num?)?.toInt() ?? 0,
              distributionLeft: (purityData?['distributionLeft'] as num?)?.toInt() ?? 0,
              distributionRight: (purityData?['distributionRight'] as num?)?.toInt() ?? 0,
              detectedMetal: null,
              otherMatches: [],
              timestamp: DateTime.now(),
              statisticalResult: null,
            ),
            verdict: data['verdict'] as String? ?? '',
            timestamp: DateTime.now(),
          );

        case 'metalId':
          return MetalIdentificationResult(
            meanADC: data['meanADC'] as int? ?? 0,
            matches: [], // Would need metal reference to reconstruct matches
            timestamp: DateTime.now(),
          );

        default:
          return resultJson; // Return raw JSON if kind is unknown
      }
    } catch (e) {
      // If deserialization fails, return raw JSON string
      return resultJson;
    }
  }

  PurityOutcome _parseOutcome(String? outcomeStr) {
    if (outcomeStr == 'PurityOutcome.gold') return PurityOutcome.gold;
    if (outcomeStr == 'PurityOutcome.notGold') return PurityOutcome.notGold;
    return PurityOutcome.unknown;
  }

  PurityCalculationMethod _parseCalculationMethod(String? methodStr) {
    if (methodStr == null) return PurityCalculationMethod.standardMean;
    return PurityCalculationMethod.values.firstWhere(
      (m) => m.prefsValue == methodStr,
      orElse: () => PurityCalculationMethod.standardMean,
    );
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<HistoryEntry>>((ref) {
  return HistoryNotifier();
});
