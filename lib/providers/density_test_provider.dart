import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_data.dart';
import '../services/bluetooth_service.dart';
import 'bt_provider.dart';
import 'sound_provider.dart';
import '../services/sound_service.dart';

class DensityTestState {
  final int currentStep;
  final Map<int, double> stepValues;
  final DensityResult? result;
  final String? errorMessage;
  final bool isRecording;
  final double? currentLiveWeight;
  final List<double> weightHistory;
  final DateTime? recordingStartTime;

  const DensityTestState({
    this.currentStep = 0,
    this.stepValues = const {},
    this.result,
    this.errorMessage,
    this.isRecording = false,
    this.currentLiveWeight,
    this.weightHistory = const [],
    this.recordingStartTime,
  });

  DensityTestState copyWith({
    int? currentStep,
    Map<int, double>? stepValues,
    DensityResult? result,
    String? errorMessage,
    bool? isRecording,
    double? currentLiveWeight,
    List<double>? weightHistory,
    DateTime? recordingStartTime,
  }) {
    return DensityTestState(
      currentStep: currentStep ?? this.currentStep,
      stepValues: stepValues ?? this.stepValues,
      result: result ?? this.result,
      errorMessage: errorMessage,
      isRecording: isRecording ?? this.isRecording,
      currentLiveWeight: currentLiveWeight ?? this.currentLiveWeight,
      weightHistory: weightHistory ?? this.weightHistory,
      recordingStartTime: recordingStartTime ?? this.recordingStartTime,
    );
  }
}

class DensityTestNotifier extends StateNotifier<DensityTestState> {
  final BluetoothService _bt;
  final SoundService _sound;

  DensityTestNotifier(this._bt, this._sound) : super(const DensityTestState()) {
    // Listen to live data stream for real-time weight updates during recording
    _bt.liveDataStream.listen((liveData) {
      if (state.isRecording && liveData.weightGrams > 0) {
        updateLiveWeight(liveData.weightGrams);
      }
    });
  }

  void zeroScale() {
    state = state.copyWith(
      isRecording: true,
      recordingStartTime: DateTime.now(),
      weightHistory: [],
    );
    _bt.zeroScale(); // Sends 'T' to Arduino
  }

  void onScaleZeroed() {
    _sound.play(SoundEffect.clickStep);
    state = state.copyWith(
      currentStep: 1,
      isRecording: false,
      currentLiveWeight: null,
      weightHistory: [],
      recordingStartTime: null,
    );
  }

  void recordAirWeight() {
    state = state.copyWith(
      isRecording: true,
      recordingStartTime: DateTime.now(),
      weightHistory: [],
      currentLiveWeight: null,
    );
    _bt.requestDensityAir(); // Sends 'A' to Arduino
  }

  void onAirWeight(double weight) {
    _sound.play(SoundEffect.clickStep);
    final newValues = Map<int, double>.from(state.stepValues);
    newValues[1] = weight;
    state = state.copyWith(
      currentStep: 2,
      stepValues: newValues,
      isRecording: false,
      currentLiveWeight: null,
      weightHistory: [],
      recordingStartTime: null,
    );
  }

  void recordWaterBaseline() {
    state = state.copyWith(
      isRecording: true,
      recordingStartTime: DateTime.now(),
      weightHistory: [],
      currentLiveWeight: null,
    );
    _bt.requestDensityWater(); // Sends 'W' to Arduino
  }

  void onWaterWeight(double weight) {
    _sound.play(SoundEffect.clickStep);
    final newValues = Map<int, double>.from(state.stepValues);
    newValues[2] = weight;
    state = state.copyWith(
      currentStep: 3,
      stepValues: newValues,
      isRecording: false,
      currentLiveWeight: null,
      weightHistory: [],
      recordingStartTime: null,
    );
  }

  void recordSubmergedWeight() {
    state = state.copyWith(
      isRecording: true,
      recordingStartTime: DateTime.now(),
      weightHistory: [],
      currentLiveWeight: null,
    );
    _bt.requestDensitySubmerged(); // Sends 'S' to Arduino
  }

  void onSubmergedWeight(double weight) {
    _sound.play(SoundEffect.clickStep);
    final newValues = Map<int, double>.from(state.stepValues);
    newValues[3] = weight;
    state = state.copyWith(
      currentStep: 4,
      stepValues: newValues,
      isRecording: false,
      currentLiveWeight: null,
      weightHistory: [],
      recordingStartTime: null,
    );
  }

  void calculateDensity() {
    state = state.copyWith(
      isRecording: true,
      recordingStartTime: DateTime.now(),
      weightHistory: [],
    );
    _bt.requestDensityCalculate(); // Sends 'C' to Arduino
  }

  void onDensityResult(DensityResult result) {
    _sound.play(SoundEffect.successDensity);
    state = state.copyWith(
      result: result,
      isRecording: false,
      currentLiveWeight: null,
      weightHistory: [],
      recordingStartTime: null,
    );
  }

  void reMeasureStep(int step) {
    state = state.copyWith(
      currentStep: step,
      isRecording: false,
      currentLiveWeight: null,
      weightHistory: [],
      recordingStartTime: null,
    );
  }

  void setError(String error) {
    state = state.copyWith(
      errorMessage: error,
      isRecording: false,
      currentLiveWeight: null,
      weightHistory: [],
      recordingStartTime: null,
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void updateLiveWeight(double weight) {
    // Add to weight history for stability analysis
    final newHistory = List<double>.from(state.weightHistory);
    newHistory.add(weight);

    // Keep only last 50 readings to prevent memory issues
    if (newHistory.length > 50) {
      newHistory.removeAt(0);
    }

    state = state.copyWith(
      currentLiveWeight: weight,
      weightHistory: newHistory,
    );
  }

  // Get stability percentage (0-100%) for UI feedback
  double getStabilityPercentage() {
    if (state.weightHistory.length < 5) return 0.0;

    // Get last 10 weights (or fewer if not enough data)
    final startIndex = state.weightHistory.length > 10
        ? state.weightHistory.length - 10
        : 0;
    final recentWeights = state.weightHistory.sublist(startIndex);

    final mean = recentWeights.reduce((a, b) => a + b) / recentWeights.length;
    final variance = recentWeights.map((w) => pow(w - mean, 2)).reduce((a, b) => a + b) / recentWeights.length;
    final stdDev = sqrt(variance);

    // Consider stable if standard deviation is less than 1% of mean
    final stabilityPercent = ((1 - (stdDev / mean)).clamp(0.0, 1.0) * 100).toDouble();
    return stabilityPercent;
  }

  void reset() {
    state = const DensityTestState();
  }
}

final densityTestProvider =
    StateNotifierProvider<DensityTestNotifier, DensityTestState>((ref) {
  return DensityTestNotifier(
    ref.read(btProvider),
    ref.read(soundServiceProvider),
  );
});
