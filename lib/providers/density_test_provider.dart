import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_data.dart';
import '../services/bluetooth_service.dart';
import '../services/sound_service.dart';
import 'bt_provider.dart';
import 'sound_provider.dart';

class DensityTestState {
  final int currentStep;
  final Map<int, double> stepValues;
  final Map<int, bool> remeasureFlags;
  final DensityResult? result;
  final bool isRecording;
  final String? errorMessage;

  DensityTestState({
    this.currentStep = 0,
    this.stepValues = const {},
    this.remeasureFlags = const {},
    this.result,
    this.isRecording = false,
    this.errorMessage,
  });

  DensityTestState copyWith({
    int? currentStep,
    Map<int, double>? stepValues,
    Map<int, bool>? remeasureFlags,
    DensityResult? result,
    bool? isRecording,
    String? errorMessage,
  }) {
    return DensityTestState(
      currentStep: currentStep ?? this.currentStep,
      stepValues: stepValues ?? this.stepValues,
      remeasureFlags: remeasureFlags ?? this.remeasureFlags,
      result: result,
      isRecording: isRecording ?? this.isRecording,
      errorMessage: errorMessage,
    );
  }

  bool get canCalculate => stepValues.containsKey(1) && stepValues.containsKey(2) && stepValues.containsKey(3);
}

class DensityTestNotifier extends StateNotifier<DensityTestState> {
  final Ref _ref;
  DensityTestNotifier(this._ref) : super(DensityTestState());

  void zeroScale() {
    state = state.copyWith(isRecording: true);
    _ref.read(btProvider).zeroScale();
  }

  void onScaleZeroed() {
    _ref.read(soundServiceProvider).play(SoundEffect.clickStep);
    state = state.copyWith(currentStep: 1, isRecording: false);
  }

  void recordAirWeight() {
    state = state.copyWith(isRecording: true);
    _ref.read(btProvider).requestDensityAir();
  }

  void onAirWeight(double value) {
    _ref.read(soundServiceProvider).play(SoundEffect.clickStep);
    final values = Map<int, double>.from(state.stepValues);
    values[1] = value;
    state = state.copyWith(currentStep: 2, stepValues: values, isRecording: false);
  }

  void recordWaterBaseline() {
    state = state.copyWith(isRecording: true);
    _ref.read(btProvider).requestDensityWater();
  }

  void onWaterWeight(double value) {
    _ref.read(soundServiceProvider).play(SoundEffect.clickStep);
    final values = Map<int, double>.from(state.stepValues);
    values[2] = value;
    state = state.copyWith(currentStep: 3, stepValues: values, isRecording: false);
  }

  void recordSubmergedWeight() {
    state = state.copyWith(isRecording: true);
    _ref.read(btProvider).requestDensitySubmerged();
  }

  void onSubmergedWeight(double value) {
    _ref.read(soundServiceProvider).play(SoundEffect.clickStep);
    final values = Map<int, double>.from(state.stepValues);
    values[3] = value;
    state = state.copyWith(currentStep: 4, stepValues: values, isRecording: false);
  }

  void calculateDensity() {
    state = state.copyWith(isRecording: true);
    _ref.read(btProvider).requestDensityCalculate();
  }

  void onDensityResult(DensityResult result) {
    _ref.read(soundServiceProvider).play(SoundEffect.successDensity);
    state = state.copyWith(result: result, isRecording: false);
  }

  void setError(String message) {
    _ref.read(soundServiceProvider).play(SoundEffect.errorBeep);
    state = state.copyWith(isRecording: false, errorMessage: message);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void reMeasureStep(int step) {
    final flags = Map<int, bool>.from(state.remeasureFlags);
    flags[step] = true;
    state = state.copyWith(currentStep: step, remeasureFlags: flags);
  }

  void reset() {
    state = DensityTestState();
  }

  void clearResult() {
    state = state.copyWith(result: null);
  }
}

final densityTestProvider = StateNotifierProvider<DensityTestNotifier, DensityTestState>((ref) {
  return DensityTestNotifier(ref);
});
