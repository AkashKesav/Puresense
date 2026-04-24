import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_data.dart';
import '../services/bluetooth_service.dart';
import '../services/sound_service.dart';
import '../utils/range_calculator.dart';
import 'bt_provider.dart';
import 'calibration_provider.dart';
import 'sound_provider.dart';

enum MetalIdMode { allMetals, singleMetal }

class MetalIdentificationState {
  final bool isIdentifying;
  final int? progress;
  final MetalIdentificationResult? result;
  final MetalIdMode mode;
  final MetalRange? targetMetal;
  final String? errorMessage;

  MetalIdentificationState({
    this.isIdentifying = false,
    this.progress,
    this.result,
    this.mode = MetalIdMode.allMetals,
    this.targetMetal,
    this.errorMessage,
  });

  MetalIdentificationState copyWith({
    bool? isIdentifying,
    int? progress,
    MetalIdentificationResult? result,
    MetalIdMode? mode,
    MetalRange? targetMetal,
    String? errorMessage,
  }) {
    return MetalIdentificationState(
      isIdentifying: isIdentifying ?? this.isIdentifying,
      progress: progress ?? this.progress,
      result: result,
      mode: mode ?? this.mode,
      targetMetal: targetMetal ?? this.targetMetal,
      errorMessage: errorMessage,
    );
  }
}

class MetalIdentificationNotifier extends StateNotifier<MetalIdentificationState> {
  final Ref _ref;
  MetalIdentificationNotifier(this._ref) : super(MetalIdentificationState());

  void startIdentification({MetalIdMode mode = MetalIdMode.allMetals, MetalRange? target}) {
    state = MetalIdentificationState(
      isIdentifying: true,
      mode: mode,
      targetMetal: target,
    );
    final bt = _ref.read(btProvider);
    bt.startPurityTest();
  }

  void onProgress(int samples) {
    state = state.copyWith(progress: samples);
  }

  void onComplete(int meanADC) {
    final cal = _ref.read(calibrationProvider);
    final ranges = state.mode == MetalIdMode.singleMetal && state.targetMetal != null
        ? [state.targetMetal!]
        : cal.metalRanges;

    final matches = RangeCalculator.identifyMetal(meanADC, ranges);
    final allMatches = RangeCalculator.identifyMetal(meanADC, cal.metalRanges);

    final result = MetalIdentificationResult(
      meanADC: meanADC,
      matches: state.mode == MetalIdMode.allMetals ? allMatches : matches,
      timestamp: DateTime.now(),
    );

    final sound = _ref.read(soundServiceProvider);
    if (matches.isNotEmpty && matches.first.metal.metalName.contains('Gold')) {
      if (matches.first.metal.metalName.contains('24k')) {
        sound.play(SoundEffect.chime24k);
      } else {
        sound.play(SoundEffect.chimeGold);
      }
    } else {
      sound.play(SoundEffect.beepNotGold);
    }

    state = state.copyWith(isIdentifying: false, result: result);
  }

  void setError(String message) {
    _ref.read(soundServiceProvider).play(SoundEffect.errorBeep);
    state = state.copyWith(isIdentifying: false, errorMessage: message);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void clearResult() {
    state = state.copyWith(result: null);
  }
}

final metalIdentificationProvider = StateNotifierProvider<MetalIdentificationNotifier, MetalIdentificationState>((ref) {
  return MetalIdentificationNotifier(ref);
});
