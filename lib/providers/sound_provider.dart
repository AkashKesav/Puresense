import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sound_service.dart';

final soundServiceProvider = Provider<SoundService>((ref) {
  final sound = SoundService();
  sound.init();
  ref.onDispose(() => sound.dispose());
  return sound;
});

final soundEnabledProvider = StateProvider<bool>((ref) => true);
final soundVolumeProvider = StateProvider<double>((ref) => 0.8);
