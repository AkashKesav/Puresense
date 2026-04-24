import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/live_data.dart';
import '../services/sound_service.dart';
import '../utils/range_calculator.dart';

class CalibrationState {
  final double anchorADC;
  final int anchorKarat;
  final double tolerance;
  final List<KaratRange> karatRanges;
  final List<MetalRange> metalRanges;

  CalibrationState({
    required this.anchorADC,
    required this.anchorKarat,
    required this.tolerance,
    required this.karatRanges,
    required this.metalRanges,
  });

  CalibrationState copyWith({
    double? anchorADC,
    int? anchorKarat,
    double? tolerance,
    List<KaratRange>? karatRanges,
    List<MetalRange>? metalRanges,
  }) {
    return CalibrationState(
      anchorADC: anchorADC ?? this.anchorADC,
      anchorKarat: anchorKarat ?? this.anchorKarat,
      tolerance: tolerance ?? this.tolerance,
      karatRanges: karatRanges ?? this.karatRanges,
      metalRanges: metalRanges ?? this.metalRanges,
    );
  }
}

class CalibrationNotifier extends StateNotifier<CalibrationState> {
  CalibrationNotifier() : super(_defaultState()) {
    _load();
  }

  static CalibrationState _defaultState() {
    const anchorADC = 22000.0;
    const anchorKarat = 24;
    const tolerance = 800.0;
    return CalibrationState(
      anchorADC: anchorADC,
      anchorKarat: anchorKarat,
      tolerance: tolerance,
      karatRanges: RangeCalculator.computeKaratRanges(anchorADC, anchorKarat, tolerance),
      metalRanges: RangeCalculator.computeMetalRanges(anchorADC),
    );
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final adc = prefs.getDouble('anchor_adc') ?? 22000.0;
    final karat = prefs.getInt('anchor_karat') ?? 24;
    final tol = prefs.getDouble('tolerance') ?? 800.0;
    updateCalibration(adc, karat, tol);
  }

  Future<void> updateCalibration(double adc, int karat, double tolerance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('anchor_adc', adc);
    await prefs.setInt('anchor_karat', karat);
    await prefs.setDouble('tolerance', tolerance);

    state = state.copyWith(
      anchorADC: adc,
      anchorKarat: karat,
      tolerance: tolerance,
      karatRanges: RangeCalculator.computeKaratRanges(adc, karat, tolerance),
      metalRanges: RangeCalculator.computeMetalRanges(adc),
    );
  }

  void recompute() {
    state = state.copyWith(
      karatRanges: RangeCalculator.computeKaratRanges(state.anchorADC, state.anchorKarat, state.tolerance),
      metalRanges: RangeCalculator.computeMetalRanges(state.anchorADC),
    );
  }

  Future<void> resetToDefaults() async {
    await updateCalibration(22000.0, 24, 800.0);
  }
}

final calibrationProvider = StateNotifierProvider<CalibrationNotifier, CalibrationState>((ref) {
  return CalibrationNotifier();
});
