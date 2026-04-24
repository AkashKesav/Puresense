import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bluetooth_service.dart';
import '../models/live_data.dart';
import 'bt_provider.dart';

final liveDataProvider = StreamProvider<LiveData>((ref) {
  final bt = ref.watch(btProvider);
  return bt.liveDataStream;
});

final probeStatusProvider = StreamProvider<ProbeStatus>((ref) {
  final bt = ref.watch(btProvider);
  return bt.probeStatusStream;
});
