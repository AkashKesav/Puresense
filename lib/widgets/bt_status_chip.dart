import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/bluetooth_service.dart';
import '../providers/bt_provider.dart';

class BtStatusChip extends ConsumerWidget {
  const BtStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final btStatusAsync = ref.watch(btStatusProvider);

    return btStatusAsync.when(
      data: (status) {
        final color = switch (status) {
          BtStatus.connected => Colors.green,
          BtStatus.connecting => const Color(0xFFFFB300),
          BtStatus.disconnected => Colors.red,
        };
        final label = switch (status) {
          BtStatus.connected => 'Connected',
          BtStatus.connecting => 'Connecting',
          BtStatus.disconnected => 'Disconnected',
        };

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                  decorationColor: Colors.transparent,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
