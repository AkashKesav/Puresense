import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_data.dart';
import '../providers/live_data_provider.dart';
import '../utils/range_calculator.dart';

class ProbeStatusBadge extends ConsumerWidget {
  const ProbeStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveAsync = ref.watch(liveDataProvider);
    final adc = liveAsync.when(data: (d) => d.adcValue, loading: () => 0, error: (_, __) => 0);

    if (adc > 18000) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFB300).withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber, color: Color(0xFFFFB300), size: 14),
            SizedBox(width: 6),
            Text(
              'Probe in air',
              style: TextStyle(color: Color(0xFFFFB300), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }
    if (adc < 500) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.grey, size: 14),
            SizedBox(width: 6),
            Text(
              'No signal',
              style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
