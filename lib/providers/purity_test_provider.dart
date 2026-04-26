import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_data.dart';

class PurityTestState {
  final PurityResult? result;
  final String? errorMessage;
  final bool isCollecting;
  final List<int> currentAdcSamples;
  final int currentMeanAdc;
  final Duration collectionDuration;
  final DateTime? collectionStartTime;

  const PurityTestState({
    this.result,
    this.errorMessage,
    this.isCollecting = false,
    this.currentAdcSamples = const [],
    this.currentMeanAdc = 0,
    this.collectionDuration = Duration.zero,
    this.collectionStartTime,
  });

  PurityTestState copyWith({
    PurityResult? result,
    String? errorMessage,
    bool? isCollecting,
    List<int>? currentAdcSamples,
    int? currentMeanAdc,
    Duration? collectionDuration,
    DateTime? collectionStartTime,
  }) {
    return PurityTestState(
      result: result ?? this.result,
      errorMessage: errorMessage,
      isCollecting: isCollecting ?? this.isCollecting,
      currentAdcSamples: currentAdcSamples ?? this.currentAdcSamples,
      currentMeanAdc: currentMeanAdc ?? this.currentMeanAdc,
      collectionDuration: collectionDuration ?? this.collectionDuration,
      collectionStartTime: collectionStartTime ?? this.collectionStartTime,
    );
  }

  double get collectionProgress {
    if (collectionDuration.inMilliseconds == 0) return 0.0;
    if (collectionStartTime == null) return 0.0;

    final elapsed = DateTime.now().difference(collectionStartTime!);
    return (elapsed.inMilliseconds / collectionDuration.inMilliseconds).clamp(0.0, 1.0);
  }
}

class PurityTestNotifier extends StateNotifier<PurityTestState> {
  PurityTestNotifier() : super(const PurityTestState());

  void startCollection(Duration duration) {
    state = state.copyWith(
      isCollecting: true,
      currentAdcSamples: [],
      currentMeanAdc: 0,
      collectionDuration: duration,
      collectionStartTime: DateTime.now(),
    );
  }

  void onAdcSample(int adcValue) {
    if (!state.isCollecting) return;

    final newSamples = List<int>.from(state.currentAdcSamples);
    newSamples.add(adcValue);

    // Calculate running mean
    final newMean = newSamples.reduce((a, b) => a + b) ~/ newSamples.length;

    state = state.copyWith(
      currentAdcSamples: newSamples,
      currentMeanAdc: newMean,
    );
  }

  void onTestComplete(PurityResult result) {
    state = PurityTestState(result: result);
  }

  void onTestError(String error) {
    state = state.copyWith(
      errorMessage: error,
      isCollecting: false,
      currentAdcSamples: [],
      currentMeanAdc: 0,
      collectionStartTime: null,
    );
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void reset() {
    state = const PurityTestState();
  }
}

final purityTestProvider =
    StateNotifierProvider<PurityTestNotifier, PurityTestState>((ref) {
  return PurityTestNotifier();
});
