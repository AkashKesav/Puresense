import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bluetooth_service.dart';

final btProvider = Provider<BluetoothService>((ref) {
  final bt = BluetoothService();
  ref.onDispose(() => bt.dispose());
  return bt;
});

final btStatusProvider = StreamProvider<BtStatus>((ref) async* {
  final bt = ref.watch(btProvider);
  yield bt.status.value;
  await for (final _ in Stream.periodic(const Duration(milliseconds: 500))) {
    yield bt.status.value;
  }
});
