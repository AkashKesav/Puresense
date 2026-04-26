import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_data.dart';
import '../providers/calibration_provider.dart';
import '../services/metal_reference_service.dart';
import '../utils/range_calculator.dart';

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

  MetalReferenceNotifier() : super(MetalReferenceState(metals: [])) {
    _loadDefaults();
  }

  void _loadDefaults() {
    final metals = RangeCalculator.computeMetalRanges(-1500.0);
    state = MetalReferenceState(metals: metals);
  }

  Future<void> refreshFromOnline(double anchorADC) async {
    state = state.copyWith(isLoading: true);
    try {
      final metals = await _service.fetchOnlineData(anchorADC);
      state = state.copyWith(metals: metals, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Using local reference data');
    }
  }

  void updateRanges(double anchorADC) {
    final metals = RangeCalculator.computeMetalRanges(anchorADC);
    // Preserve custom metals when recalculating
    state = state.copyWith(metals: metals);
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
  }

  void addCustomMetal(MetalRange metal) {
    final custom = List<MetalRange>.from(state.customMetals);
    custom.add(metal);
    state = state.copyWith(customMetals: custom);
  }

  void removeCustomMetal(String name) {
    final custom = state.customMetals.where((m) => m.metalName != name).toList();
    state = state.copyWith(customMetals: custom);
  }

  /// Reset all metals to factory defaults
  void resetToDefaults() {
    final metals = RangeCalculator.computeMetalRanges(-1500.0);
    state = MetalReferenceState(metals: metals, customMetals: []);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final metalReferenceProvider = StateNotifierProvider<MetalReferenceNotifier, MetalReferenceState>((ref) {
  final notifier = MetalReferenceNotifier();

  // Auto-sync: when ANY calibration state changes, update metal ranges
  ref.listen<CalibrationState>(calibrationProvider, (prev, next) {
    if (prev?.anchorADC != next.anchorADC ||
        prev?.anchorKarat != next.anchorKarat ||
        prev?.tolerance != next.tolerance) {
      notifier.updateRanges(next.anchorADC);
    }
  });

  // Also initialize with current calibration state (not just default -1500)
  final currentCal = ref.read(calibrationProvider);
  if (currentCal.anchorADC != -1500.0) {
    notifier.updateRanges(currentCal.anchorADC);
  }

  return notifier;
});
