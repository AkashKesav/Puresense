import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/live_data.dart';
import '../providers/calibration_provider.dart';
import '../providers/settings_provider.dart';
import '../services/metal_reference_service.dart';
import '../utils/range_calculator.dart';
import '../utils/electrochemical_range_predictor.dart';

class MetalReferenceState {
  final List<MetalRange> metals;
  final List<MetalRange> customMetals;
  final bool isLoading;
  final String? error;

  MetalReferenceState({
    required this.metals,
    this.customMetals = const [],
    this.isLoading = false,
    this.error,
  });

  List<MetalRange> get allMetals => [...metals, ...customMetals];

  MetalReferenceState copyWith({
    List<MetalRange>? metals,
    List<MetalRange>? customMetals,
    bool? isLoading,
    String? error,
  }) {
    return MetalReferenceState(
      metals: metals ?? this.metals,
      customMetals: customMetals ?? this.customMetals,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MetalReferenceNotifier extends StateNotifier<MetalReferenceState> {
  final MetalReferenceService _service = MetalReferenceService();
  static const String _customMetalsFilename = 'custom_metals.json';

  MetalReferenceNotifier() : super(MetalReferenceState(metals: [])) {
    _loadDefaults();
    _loadCustomMetals();
  }

  void _loadDefaults() {
    // Use electrochemical predictor for scientifically accurate ranges
    final metals = ElectrochemicalRangePredictor.getAllPredictedRanges();
    state = MetalReferenceState(metals: metals);
    print('🔬 Loaded metal ranges using electrochemical SEP prediction');
  }

  /// Load custom metals from JSON file
  Future<void> _loadCustomMetals() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_customMetalsFilename');

      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonString);

        final customMetals = jsonList.map((json) {
          return MetalRange(
            metalName: json['metalName'] as String,
            expectedADC: (json['expectedADC'] as num).toDouble(),
            min: (json['min'] as num).toDouble(),
            max: (json['max'] as num).toDouble(),
            color: Color(json['color'] as int),
            description: json['description'] as String? ?? 'Custom metal',
            densityGcm3: (json['densityGcm3'] as num?)?.toDouble(),
            isCustom: json['isCustom'] as bool? ?? true,
          );
        }).toList();

        state = state.copyWith(customMetals: customMetals);
        print('✅ Loaded ${customMetals.length} custom metals from file');
      }
    } catch (e) {
      print('⚠️ Could not load custom metals: $e');
    }
  }

  /// Save custom metals to JSON file
  Future<void> _saveCustomMetals() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_customMetalsFilename');

      final jsonList = state.customMetals.map((metal) => {
        'metalName': metal.metalName,
        'expectedADC': metal.expectedADC,
        'min': metal.min,
        'max': metal.max,
        'color': metal.color.value,
        'description': metal.description,
        'densityGcm3': metal.densityGcm3,
        'isCustom': metal.isCustom,
      }).toList();

      final jsonString = json.encode(jsonList);
      await file.writeAsString(jsonString);
      print('✅ Saved ${state.customMetals.length} custom metals to file');
    } catch (e) {
      print('⚠️ Could not save custom metals: $e');
    }
  }

  Future<void> refreshFromOnline(double anchorADC) async {
    state = state.copyWith(isLoading: true);
    try {
      final metals = await _service.fetchOnlineData(anchorADC);
      state = state.copyWith(metals: metals, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Using electrochemical predictions');
    }
  }

  void updateRanges(double anchorADC, {int? anchorKarat}) {
    print('🔄 MetalReferenceProvider.updateRanges called with anchorADC=$anchorADC');

    // Use provided karat or default to 22k
    final effectiveKarat = anchorKarat ?? 22;

    // Update electrochemical predictor with new anchor point
    ElectrochemicalRangePredictor.updateCalibrationAnchor(anchorADC, effectiveKarat);

    // Use electrochemical predictor for updated ranges based on new calibration
    final metals = ElectrochemicalRangePredictor.getAllPredictedRanges();

    // IMPORTANT: Preserve custom metals when recalculating
    state = state.copyWith(metals: metals);

    print('✅ Updated metal ranges using electrochemical SEP with new anchor. New state has:');
    print('   - Built-in metals: ${state.metals.length}');
    print('   - Custom metals: ${state.customMetals.length}');
    print('   - Total metals: ${state.allMetals.length}');

    // Force a complete state rebuild to trigger listeners
    final newState = MetalReferenceState(
      metals: metals,
      customMetals: state.customMetals,
    );

    state = newState;

    print('✅ Metal reference provider force-refreshed with SEP predictions');
  }

  /// Update a built-in metal's ADC value and tolerance in-place
  void updateMetalADC(String metalName, double newADC, double newTolerance) {
    final updated = state.metals.map((m) {
      if (m.metalName == metalName) {
        return MetalRange(
          metalName: m.metalName,
          expectedADC: newADC,
          min: newADC - newTolerance,
          max: newADC + newTolerance,
          color: m.color,
          description: m.description,
          densityGcm3: m.densityGcm3,
          isCustom: m.isCustom,
        );
      }
      return m;
    }).toList();

    // Also check custom metals
    final updatedCustom = state.customMetals.map((m) {
      if (m.metalName == metalName) {
        return MetalRange(
          metalName: m.metalName,
          expectedADC: newADC,
          min: newADC - newTolerance,
          max: newADC + newTolerance,
          color: m.color,
          description: m.description,
          densityGcm3: m.densityGcm3,
          isCustom: m.isCustom,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(metals: updated, customMetals: updatedCustom);
    _saveCustomMetals(); // Persist if custom metals were modified
  }

  /// Update a metal with explicit min/max range
  void updateMetalRange(String metalName, double newADC, double newMin, double newMax) {
    final updated = state.metals.map((m) {
      if (m.metalName == metalName) {
        return MetalRange(
          metalName: m.metalName,
          expectedADC: newADC,
          min: newMin,
          max: newMax,
          color: m.color,
          description: m.description,
          densityGcm3: m.densityGcm3,
          isCustom: m.isCustom,
        );
      }
      return m;
    }).toList();

    final updatedCustom = state.customMetals.map((m) {
      if (m.metalName == metalName) {
        return MetalRange(
          metalName: m.metalName,
          expectedADC: newADC,
          min: newMin,
          max: newMax,
          color: m.color,
          description: m.description,
          densityGcm3: m.densityGcm3,
          isCustom: m.isCustom,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(metals: updated, customMetals: updatedCustom);
    _saveCustomMetals(); // Persist if custom metals were modified
  }

  void addCustomMetal(MetalRange metal) {
    final custom = List<MetalRange>.from(state.customMetals);
    custom.add(metal);
    state = state.copyWith(customMetals: custom);
    _saveCustomMetals(); // Persist to file
  }

  void removeCustomMetal(String name) {
    final custom = state.customMetals.where((m) => m.metalName != name).toList();
    state = state.copyWith(customMetals: custom);
    _saveCustomMetals(); // Persist to file
  }

  /// Reset all metals to factory defaults
  void resetToDefaults() {
    // Use electrochemical predictor for accurate defaults
    final metals = ElectrochemicalRangePredictor.getAllPredictedRanges();
    state = MetalReferenceState(metals: metals, customMetals: []);
    _deleteCustomMetalsFile(); // Also delete the custom metals file
    print('🔄 Reset to electrochemical SEP defaults');
  }

  /// Delete the custom metals file
  Future<void> _deleteCustomMetalsFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_customMetalsFilename');
      if (await file.exists()) {
        await file.delete();
        print('✅ Deleted custom metals file');
      }
    } catch (e) {
      print('⚠️ Could not delete custom metals file: $e');
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final metalReferenceProvider = StateNotifierProvider<MetalReferenceNotifier, MetalReferenceState>((ref) {
  final notifier = MetalReferenceNotifier();

  // Auto-sync: when ANY calibration state changes, update metal ranges
  ref.listen<CalibrationState>(calibrationProvider, (prev, next) {
    print('🔍 [METAL REF] Calibration changed detected!');
    print('   OLD: ADC=${prev?.anchorADC}, Karat=${prev?.anchorKarat}');
    print('   NEW: ADC=${next.anchorADC}, Karat=${next.anchorKarat}');

    if (prev?.anchorADC != next.anchorADC ||
        prev?.anchorKarat != next.anchorKarat ||
        prev?.tolerance != next.tolerance) {
      print('⚡ [METAL REF] Triggering updateRanges!');
      notifier.updateRanges(next.anchorADC, anchorKarat: next.anchorKarat);
    } else {
      print('✅ [METAL REF] No significant change, skipping update');
    }
  });

  // Also initialize with current calibration state (not just default -1500)
  final currentCal = ref.read(calibrationProvider);
  print('🔍 [METAL REF] Initializing with current calibration: ADC=${currentCal.anchorADC}, Karat=${currentCal.anchorKarat}');
  if (currentCal.anchorADC != -1500.0) {
    notifier.updateRanges(currentCal.anchorADC, anchorKarat: currentCal.anchorKarat);
  }

  return notifier;
});
