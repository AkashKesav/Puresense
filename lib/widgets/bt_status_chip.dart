import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/bt_provider.dart';
import '../services/bluetooth_service.dart';

class BtStatusChip extends ConsumerWidget {
  const BtStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bt = ref.watch(btStatusProvider);

    return bt.when(
      data: (status) {
        late Color dotColor;
        late String label;
        switch (status) {
          case BtStatus.connected:
            dotColor = Colors.green;
            label = 'Connected';
            break;
          case BtStatus.connecting:
            dotColor = const Color(0xFFFFB300);
            label = 'Connecting';
            break;
          case BtStatus.disconnected:
            dotColor = Colors.red;
            label = 'Disconnected';
            break;
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: dotColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: dotColor.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == BtStatus.connecting)
                SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(dotColor),
                  ),
                )
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: dotColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
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
