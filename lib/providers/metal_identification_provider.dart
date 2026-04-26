import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_data.dart';

class MetalIdentificationState {
  final MetalIdentificationResult? result;

  const MetalIdentificationState({this.result});
}

class MetalIdentificationNotifier extends StateNotifier<MetalIdentificationState> {
  MetalIdentificationNotifier() : super(const MetalIdentificationState());

  void setResult(MetalIdentificationResult result) {
    state = MetalIdentificationState(result: result);
  }

  void clear() {
    state = const MetalIdentificationState();
  }
}

final metalIdentificationProvider =
    StateNotifierProvider<MetalIdentificationNotifier, MetalIdentificationState>((ref) {
  return MetalIdentificationNotifier();
});
