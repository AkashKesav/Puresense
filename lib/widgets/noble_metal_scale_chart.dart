import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_data.dart';
import '../providers/calibration_provider.dart';
import '../providers/live_data_provider.dart';

class NobleMetalScaleChart extends ConsumerWidget {
  final void Function(MetalRange)? onTapSegment;
  const NobleMetalScaleChart({super.key, this.onTapSegment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cal = ref.watch(calibrationProvider);
    final liveAsync = ref.watch(liveDataProvider);
    final adc = liveAsync.when(data: (d) => d.adcValue.toDouble(), loading: () => 0.0, error: (_, __) => 0.0);

    final metals = cal.metalRanges;
    if (metals.isEmpty) return const SizedBox.shrink();

    final totalScale = 30000.0;

    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          // Stacked segments
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: metals.map((metal) {
                final width = (metal.max - metal.min) / totalScale;
                return Expanded(
                  flex: ((metal.max - metal.min) * 1000).toInt(),
                  child: GestureDetector(
                    onTap: () => onTapSegment?.call(metal),
                    child: Container(
                      color: metal.color.withOpacity(0.7),
                      child: Center(
                        child: Text(
                          metal.metalName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: metal.color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Live indicator line
          Positioned(
            left: (adc / totalScale).clamp(0.0, 1.0) * MediaQuery.of(context).size.width - 32,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
