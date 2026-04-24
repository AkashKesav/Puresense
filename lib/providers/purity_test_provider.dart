import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_data.dart';
import '../services/bluetooth_service.dart';
import '../services/sound_service.dart';
import '../utils/range_calculator.dart';
import '../utils/result_parser.dart';
import 'bt_provider.dart';
import 'calibration_provider.dart';
import 'live_data_provider.dart';
import 'sound_provider.dart';

class PurityTestState {
  final bool isCalibrating;
  final int? calibrationProgress;
  final bool isTesting;
  final int? testProgress;
  final PurityResult? result;
  final String? errorMessage;

  PurityTestState({
    this.isCalibrating = false,
    this.calibrationProgress,
    this.isTesting = false,
    this.testProgress,
    this.result,
    this.errorMessage,
  });

  PurityTestState copyWith({
    bool? isCalibrating,
    int? calibrationProgress,
    bool? isTesting,
    int? testProgress,
    PurityResult? result,
    String? errorMessage,
  }) {
    return PurityTestState(
      isCalibrating: isCalibrating ?? this.isCalibrating,
      calibrationProgress: calibrationProgress ?? this.calibrationProgress,
      isTesting: isTesting ?? this.isTesting,
      testProgress: testProgress ?? this.testProgress,
      result: result ?? this.result,
      errorMessage: errorMessage,
    );
  }
}

class PurityTestNotifier extends StateNotifier<PurityTestState> {
  final Ref _ref;
  PurityTestNotifier(this._ref) : super(PurityTestState());

  void startCalibration() {
    state = state.copyWith(isCalibrating: true, calibrationProgress: 0, result: null);
    final bt = _ref.read(btProvider);
    bt.startCalibration();
  }

  void cancelCalibration() {
    state = state.copyWith(isCalibrating: false, calibrationProgress: null);
  }

  void onCalibrationMean(int meanADC) {
    state = state.copyWith(isCalibrating: false, calibrationProgress: meanADC);
  }

  void startTest() {
    state = state.copyWith(isTesting: true, testProgress: 0, result: null);
    final bt = _ref.read(btProvider);
    bt.startPurityTest();
  }

  void cancelTest() {
    state = state.copyWith(isTesting: false, testProgress: null);
  }

  void onTestProgress(int samples) {
    state = state.copyWith(testProgress: samples);
  }

  void onTestComplete(PurityResult result) {
    final sound = _ref.read(soundServiceProvider);
    if (result.outcome == PurityOutcome.gold) {
      if (result.karat == 24) {
        sound.play(SoundEffect.chime24k);
      } else {
        sound.play(SoundEffect.chimeGold);
      }
    } else if (result.outcome == PurityOutcome.notGold) {
      sound.play(SoundEffect.beepNotGold);
    } else if (result.outcome == PurityOutcome.probeInAir) {
      sound.play(SoundEffect.beepProbeAir);
    }
    state = state.copyWith(isTesting: false, result: result, testProgress: null);
  }

  void setError(String message) {
    _ref.read(soundServiceProvider).play(SoundEffect.errorBeep);
    state = state.copyWith(isTesting: false, isCalibrating: false, errorMessage: message);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void clearResult() {
    state = state.copyWith(result: null);
  }

  void parseAndComplete(String line) {
    final outcome = ResultParser.parsePurityOutcome(line);
    if (outcome != null) {
      _finalizeOutcome(outcome);
      return;
    }
    final error = ResultParser.parseErrorMessage(line);
    if (error != null) {
      setError(error);
      return;
    }
    final samples = ResultParser.parseSamplesCollected(line);
    if (samples != null) {
      onTestProgress(samples);
    }
  }

  void _finalizeOutcome(PurityOutcome outcome) {
    final cal = _ref.read(calibrationProvider);
    final liveData = _ref.read(liveDataProvider).asData?.value;
    final meanADC = liveData?.adcValue ?? 0;

    if (outcome == PurityOutcome.probeInAir) {
      onTestComplete(PurityResult(
        outcome: PurityOutcome.probeInAir,
        meanADC: meanADC,
        distributionGold: 0,
        distributionLeft: 0,
        distributionRight: 0,
        otherMatches: [],
        timestamp: DateTime.now(),
      ));
      return;
    }

    if (outcome == PurityOutcome.gold) {
      final karat = RangeCalculator.findKaratFromADC(meanADC, cal.karatRanges);
      state = state.copyWith(isTesting: false);
      onTestComplete(PurityResult(
        outcome: PurityOutcome.gold,
        meanADC: meanADC,
        karat: karat,
        purityPercent: karat != null ? RangeCalculator.karatToPurityPercent(karat) : null,
        distributionGold: 87,
        distributionLeft: 8,
        distributionRight: 5,
        otherMatches: [],
        timestamp: DateTime.now(),
      ));
    } else {
      final matches = RangeCalculator.identifyMetal(meanADC, cal.metalRanges);
      final best = matches.isNotEmpty ? matches.first : null;
      final others = matches.length > 1 ? matches.sublist(1, min(4, matches.length)) : <MetalMatch>[];

      onTestComplete(PurityResult(
        outcome: PurityOutcome.notGold,
        meanADC: meanADC,
        detectedMetal: best,
        otherMatches: others,
        distributionGold: 0,
        distributionLeft: best != null ? (100 - best.confidence).toInt() : 100,
        distributionRight: 0,
        timestamp: DateTime.now(),
      ));
    }
  }
}

final purityTestProvider = StateNotifierProvider<PurityTestNotifier, PurityTestState>((ref) {
  return PurityTestNotifier(ref);
});
