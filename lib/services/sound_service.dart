import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SoundEffect {
  chime24k,
  chimeGold,
  beepNotGold,
  beepProbeAir,
  clickStep,
  successDensity,
  errorBeep,
}

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final _player = AudioPlayer();
  bool _soundEnabled = true;
  double _volume = 0.8;
  bool _initialized = false;

  bool get soundEnabled => _soundEnabled;
  double get volume => _volume;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled =
        prefs.getBool('soundEnabled') ?? prefs.getBool('sound_enabled') ?? true;
    _volume =
        prefs.getDouble('volume') ?? prefs.getDouble('sound_volume') ?? 0.8;
    _initialized = true;
  }

  Future<void> play(SoundEffect effect) async {
    if (!_initialized) {
      await init();
    }
    if (!_soundEnabled) return;
    final source = AssetSource(_mapEffectToPath(effect));
    await _player.play(source, volume: _volume);
  }

  void applySettings({
    required bool soundEnabled,
    required double volume,
  }) {
    _soundEnabled = soundEnabled;
    _volume = volume.clamp(0.0, 1.0);
  }

  String _mapEffectToPath(SoundEffect effect) {
    switch (effect) {
      case SoundEffect.chime24k:
        return 'sounds/chime_24k.mp3';
      case SoundEffect.chimeGold:
        return 'sounds/chime_gold.mp3';
      case SoundEffect.beepNotGold:
        return 'sounds/beep_notgold.mp3';
      case SoundEffect.beepProbeAir:
        return 'sounds/beep_probe_air.mp3';
      case SoundEffect.clickStep:
        return 'sounds/click_step.mp3';
      case SoundEffect.successDensity:
        return 'sounds/success_density.mp3';
      case SoundEffect.errorBeep:
        return 'sounds/error_beep.mp3';
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', enabled);
    await prefs.setBool('sound_enabled', enabled);
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('volume', _volume);
    await prefs.setDouble('sound_volume', _volume);
  }

  Future<void> testSound() async {
    await play(SoundEffect.chimeGold);
  }

  void dispose() {
    _player.dispose();
  }
}
