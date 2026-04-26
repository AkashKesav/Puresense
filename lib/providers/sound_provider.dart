import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sound_service.dart';
import 'settings_provider.dart';

final soundServiceProvider = Provider<SoundService>((ref) {
  final sound = SoundService();
  sound.init();
  final settings = ref.read(settingsProvider);
  sound.applySettings(
    soundEnabled: settings.soundEnabled,
    volume: settings.volume,
  );
  ref.listen<SettingsState>(settingsProvider, (_, next) {
    sound.applySettings(
      soundEnabled: next.soundEnabled,
      volume: next.volume,
    );
  });
  ref.onDispose(() => sound.dispose());
  return sound;
});
