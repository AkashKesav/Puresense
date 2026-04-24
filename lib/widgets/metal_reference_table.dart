import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_data.dart';
import '../providers/calibration_provider.dart';
import '../providers/live_data_provider.dart';
import '../utils/range_calculator.dart';

class MetalReferenceTable extends ConsumerWidget {
  final bool showGoldOnly;
  final void Function(MetalRange)? onTestSample;
  final void Function(MetalRange)? onUseAsAnchor;
  final void Function(MetalRange)? onEditADC;

  const MetalReferenceTable({
    super.key,
    this.showGoldOnly = true,
    this.onTestSample,
    this.onUseAsAnchor,
    this.onEditADC,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cal = ref.watch(calibrationProvider);
    final liveAsync = ref.watch(liveDataProvider);
    final adc = liveAsync.when(data: (d) => d.adcValue, loading: () => 0, error: (_, __) => 0);

    final metals = showGoldOnly
        ? cal.metalRanges.where((m) => m.metalName.contains('Gold')).toList()
        : cal.metalRanges;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final metal = metals[index];
        final isMatch = adc >= metal.min && adc <= metal.max;
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF222222),
            borderRadius: BorderRadius.circular(12),
            border: isMatch
                ? Border.all(color: const Color(0xFFFFB300), width: 2)
                : null,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: metal.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      metal.metalName,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (metal.isCustom)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Custom', style: TextStyle(color: Colors.blue, fontSize: 11)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'ADC Range: ${metal.min.toStringAsFixed(0)} – ${metal.max.toStringAsFixed(0)}  •  Computed from anchor',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
              ),
              if (metal.densityGcm3 != null)
                Text(
                  'Density: ${metal.densityGcm3} g/cm³',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onTestSample?.call(metal),
                      child: const Text('Test Sample', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onEditADC?.call(metal),
                      child: const Text('Edit ADC', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onUseAsAnchor?.call(metal),
                      child: const Text('Use as Anchor', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
