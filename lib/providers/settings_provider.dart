import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final bool soundEnabled;
  final double volume;
  final bool autoReconnect;
  final bool showLiveChart;
  final String themeMode;

  SettingsState({
    this.soundEnabled = true,
    this.volume = 0.8,
    this.autoReconnect = true,
    this.showLiveChart = true,
    this.themeMode = 'dark',
  });

  SettingsState copyWith({
    bool? soundEnabled,
    double? volume,
    bool? autoReconnect,
    bool? showLiveChart,
    String? themeMode,
  }) {
    return SettingsState(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      volume: volume ?? this.volume,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      showLiveChart: showLiveChart ?? this.showLiveChart,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      soundEnabled: prefs.getBool('sound_enabled') ?? true,
      volume: prefs.getDouble('sound_volume') ?? 0.8,
      autoReconnect: prefs.getBool('auto_reconnect') ?? true,
      showLiveChart: prefs.getBool('show_live_chart') ?? true,
      themeMode: prefs.getString('theme_mode') ?? 'dark',
    );
  }

  Future<void> setSoundEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', v);
    state = state.copyWith(soundEnabled: v);
  }

  Future<void> setVolume(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('sound_volume', v);
    state = state.copyWith(volume: v);
  }

  Future<void> setAutoReconnect(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_reconnect', v);
    state = state.copyWith(autoReconnect: v);
  }

  Future<void> setShowLiveChart(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_live_chart', v);
    state = state.copyWith(showLiveChart: v);
  }

  Future<void> setThemeMode(String v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', v);
    state = state.copyWith(themeMode: v);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
