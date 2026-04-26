import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bluetooth_service.dart';
import 'settings_provider.dart';

/// Provides the BluetoothService singleton
final btProvider = Provider<BluetoothService>((ref) {
  final bt = BluetoothService();
  bt.setAutoReconnectEnabled(ref.read(settingsProvider).autoReconnect);
  ref.listen<SettingsState>(settingsProvider, (_, next) {
    bt.setAutoReconnectEnabled(next.autoReconnect);
  });
  return bt;
});

/// Reactive stream provider for BtStatus changes (no polling)
final btStatusProvider = StreamProvider<BtStatus>((ref) {
  final bt = ref.watch(btProvider);
  // Convert ValueNotifier to a proper Stream
  return Stream.multi((controller) {
    void listener() {
      controller.add(bt.status.value);
    }

    bt.status.addListener(listener);
    // Emit current value immediately
    controller.add(bt.status.value);
    controller.onCancel = () {
      bt.status.removeListener(listener);
    };
  });
});

/// Reactive stream provider for ProbeStatus
final probeStatusProvider = StreamProvider<ProbeStatus>((ref) {
  final bt = ref.watch(btProvider);
  return bt.probeStatusStream;
});
