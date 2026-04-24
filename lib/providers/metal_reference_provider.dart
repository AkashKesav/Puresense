import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_data.dart';
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
    final metals = RangeCalculator.computeMetalRanges(22000.0);
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
    state = state.copyWith(metals: metals);
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

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final metalReferenceProvider = StateNotifierProvider<MetalReferenceNotifier, MetalReferenceState>((ref) {
  return MetalReferenceNotifier();
});
