import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_data.dart';

class FullAnalysisState {
  final bool isFullAnalysisMode;
  final DensityResult? density;
  final PurityResult? purity;

  const FullAnalysisState({
    this.isFullAnalysisMode = false,
    this.density,
    this.purity,
  });

  FullAnalysisState copyWith({
    bool? isFullAnalysisMode,
    DensityResult? density,
    PurityResult? purity,
  }) {
    return FullAnalysisState(
      isFullAnalysisMode: isFullAnalysisMode ?? this.isFullAnalysisMode,
      density: density ?? this.density,
      purity: purity ?? this.purity,
    );
  }
}

class FullAnalysisNotifier extends StateNotifier<FullAnalysisState> {
  FullAnalysisNotifier() : super(const FullAnalysisState());

  void startFullAnalysis() {
    state = const FullAnalysisState(isFullAnalysisMode: true);
  }

  void setDensityResult(DensityResult result) {
    state = state.copyWith(density: result);
  }

  void setPurityResult(PurityResult result) {
    state = state.copyWith(purity: result);
  }

  void reset() {
    state = const FullAnalysisState();
  }
}

final fullAnalysisProvider =
    StateNotifierProvider<FullAnalysisNotifier, FullAnalysisState>((ref) {
  return FullAnalysisNotifier();
});
