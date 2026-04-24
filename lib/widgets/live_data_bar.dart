import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/live_data_provider.dart';
import '../services/bluetooth_service.dart';

class LiveDataBar extends ConsumerWidget {
  const LiveDataBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveAsync = ref.watch(liveDataProvider);

    final weight = liveAsync.when(
      data: (d) => d.weightGrams.toStringAsFixed(2),
      loading: () => '--',
      error: (_, __) => '--',
    );
    final adc = liveAsync.when(
      data: (d) => d.adcValue.toString(),
      loading: () => '--',
      error: (_, __) => '--',
    );
    final probeStatus = liveAsync.when(
      data: (d) => _probeStatusFromADC(d.adcValue),
      loading: () => ProbeStatus.unknown,
      error: (_, __) => ProbeStatus.unknown,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.scale, color: Color(0xFFFFB300), size: 18),
          const SizedBox(width: 6),
          Text(
            '$weight g',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 16, color: Colors.white.withOpacity(0.2)),
          const SizedBox(width: 16),
          const Icon(Icons.bolt, color: Color(0xFFFFB300), size: 18),
          const SizedBox(width: 6),
          Text(
            'ADC: $adc',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          _ProbeStatusDot(status: probeStatus),
          const SizedBox(width: 8),
          if (probeStatus == ProbeStatus.inAir)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Probe in air',
                style: TextStyle(color: Color(0xFFFFB300), fontSize: 11, fontWeight: FontWeight.w600),
              ),
            )
          else if (probeStatus == ProbeStatus.noSignal)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'No signal',
                style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  ProbeStatus _probeStatusFromADC(int adc) {
    if (adc > 18000) return ProbeStatus.inAir;
    if (adc < 500) return ProbeStatus.noSignal;
    return ProbeStatus.contact;
  }
}

class _ProbeStatusDot extends StatelessWidget {
  final ProbeStatus status;
  const _ProbeStatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    switch (status) {
      case ProbeStatus.inAir:
        color = Colors.red;
        break;
      case ProbeStatus.contact:
        color = const Color(0xFFFFB300);
        break;
      case ProbeStatus.noSignal:
        color = Colors.grey;
        break;
      case ProbeStatus.unknown:
        color = Colors.grey;
        break;
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
