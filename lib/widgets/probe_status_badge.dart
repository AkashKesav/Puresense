import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/live_data_provider.dart';

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
          color: const Color(0xFFFFB300).withAlpha(25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber, color: Color(0xFFFFB300), size: 14),
            const SizedBox(width: 6),
            Text(
              'Probe in air',
              style: GoogleFonts.inter(
                color: const Color(0xFFFFB300),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    if (adc < 500) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.grey, size: 14),
            const SizedBox(width: 6),
            Text(
              'No signal',
              style: GoogleFonts.inter(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
