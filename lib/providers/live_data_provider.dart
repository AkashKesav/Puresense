import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/bt_provider.dart';

/// Provides the latest LiveData from the ESP32 continuous stream
final liveDataProvider = StreamProvider((ref) {
  final bt = ref.watch(btProvider);
  return bt.liveDataStream;
});
