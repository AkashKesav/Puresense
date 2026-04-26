import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/purity_calculation_method.dart';

class SettingsState {
  final bool soundEnabled;
  final double volume;
  final bool showLiveChart;
  final bool autoReconnect;
  final PurityCalculationMethod calculationMethod;

  const SettingsState({
    this.soundEnabled = true,
    this.volume = 0.8,
    this.showLiveChart = true,
    this.autoReconnect = true,
    this.calculationMethod = PurityCalculationMethod.standardMean,
  });

  bool get useStatisticalMethod =>
      calculationMethod != PurityCalculationMethod.standardMean;

  SettingsState copyWith({
    bool? soundEnabled,
    double? volume,
    bool? showLiveChart,
    bool? autoReconnect,
    PurityCalculationMethod? calculationMethod,
  }) {
    return SettingsState(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      volume: volume ?? this.volume,
      showLiveChart: showLiveChart ?? this.showLiveChart,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      calculationMethod: calculationMethod ?? this.calculationMethod,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedMethod = PurityCalculationMethodX.fromPrefsValue(
      prefs.getString('purityCalculationMethod'),
    );
    final legacyStatistical = prefs.getBool('useStatisticalMethod') ?? false;

    state = SettingsState(
      soundEnabled: prefs.getBool('soundEnabled') ?? true,
      volume: prefs.getDouble('volume') ?? 0.8,
      showLiveChart: prefs.getBool('showLiveChart') ?? true,
      autoReconnect: prefs.getBool('autoReconnect') ?? true,
      calculationMethod: storedMethod ??
          (legacyStatistical
              ? PurityCalculationMethod.detrendedSlope
              : PurityCalculationMethod.standardMean),
    );
  }

  Future<void> setSoundEnabled(bool v) async {
    state = state.copyWith(soundEnabled: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', v);
  }

  Future<void> setVolume(double v) async {
    state = state.copyWith(volume: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('volume', v);
  }

  Future<void> setShowLiveChart(bool v) async {
    state = state.copyWith(showLiveChart: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showLiveChart', v);
  }

  Future<void> setAutoReconnect(bool v) async {
    state = state.copyWith(autoReconnect: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoReconnect', v);
  }

  Future<void> setPurityCalculationMethod(
    PurityCalculationMethod method,
  ) async {
    state = state.copyWith(calculationMethod: method);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('purityCalculationMethod', method.prefsValue);
    await prefs.setBool(
      'useStatisticalMethod',
      method != PurityCalculationMethod.standardMean,
    );
  }

  Future<void> setUseStatisticalMethod(bool v) async {
    await setPurityCalculationMethod(
      v
          ? PurityCalculationMethod.detrendedSlope
          : PurityCalculationMethod.standardMean,
    );
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
