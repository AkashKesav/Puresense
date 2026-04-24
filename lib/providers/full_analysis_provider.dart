import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_data.dart';

class FullAnalysisState {
  final bool isFullAnalysisMode;
  final DensityResult? densityResult;
  final PurityResult? purityResult;
  final bool showHandoffSheet;

  FullAnalysisState({
    this.isFullAnalysisMode = false,
    this.densityResult,
    this.purityResult,
    this.showHandoffSheet = false,
  });

  FullAnalysisState copyWith({
    bool? isFullAnalysisMode,
    DensityResult? densityResult,
    PurityResult? purityResult,
    bool? showHandoffSheet,
    bool clearDensity = false,
    bool clearPurity = false,
  }) {
    return FullAnalysisState(
      isFullAnalysisMode: isFullAnalysisMode ?? this.isFullAnalysisMode,
      densityResult: clearDensity ? null : (densityResult ?? this.densityResult),
      purityResult: clearPurity ? null : (purityResult ?? this.purityResult),
      showHandoffSheet: showHandoffSheet ?? this.showHandoffSheet,
    );
  }
}

class FullAnalysisNotifier extends StateNotifier<FullAnalysisState> {
  FullAnalysisNotifier() : super(FullAnalysisState());

  void startFullAnalysis() {
    state = FullAnalysisState(isFullAnalysisMode: true);
  }

  void setDensityResult(DensityResult result) {
    state = state.copyWith(densityResult: result, showHandoffSheet: true);
  }

  void dismissHandoff() {
    state = state.copyWith(showHandoffSheet: false);
  }

  void setPurityResult(PurityResult result) {
    state = state.copyWith(purityResult: result);
  }

  void finish() {
    state = state.copyWith(isFullAnalysisMode: false, clearDensity: true, clearPurity: true);
  }

  void reset() {
    state = FullAnalysisState();
  }
}

final fullAnalysisProvider = StateNotifierProvider<FullAnalysisNotifier, FullAnalysisState>((ref) {
  return FullAnalysisNotifier();
});
