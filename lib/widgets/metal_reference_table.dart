import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/live_data.dart';
import '../providers/calibration_provider.dart';
import '../providers/live_data_provider.dart';
import '../utils/number_format.dart' as nf;

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
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: const Color(0xFF222222),
            borderRadius: BorderRadius.circular(12),
            border: isMatch
                ? Border(
                    left: BorderSide(color: const Color(0xFFFFB300), width: 3),
                    top: BorderSide(color: const Color(0xFFFFB300).withAlpha(60)),
                    right: BorderSide(color: const Color(0xFFFFB300).withAlpha(60)),
                    bottom: BorderSide(color: const Color(0xFFFFB300).withAlpha(60)),
                  )
                : Border.all(color: Colors.white.withAlpha(8)),
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
                      style: GoogleFonts.inter(
                        color: isMatch ? const Color(0xFFFFB300) : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (metal.isCustom)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Custom',
                        style: GoogleFonts.inter(
                          color: Colors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (isMatch)
                    Text(
                      ' ◄',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFFB300),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'ADC Range: ${nf.NumberFormat.formatADCRange(metal.min, metal.max)}  •  Computed from anchor',
                style: GoogleFonts.inter(
                  color: Colors.white.withAlpha(100),
                  fontSize: 12,
                ),
              ),
              if (metal.densityGcm3 != null)
                Text(
                  'Density: ${metal.densityGcm3} g/cm³',
                  style: GoogleFonts.inter(
                    color: Colors.white.withAlpha(100),
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onTestSample?.call(metal),
                      child: Text(
                        'Test Sample',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onEditADC?.call(metal),
                      child: Text(
                        'Edit ADC',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onUseAsAnchor?.call(metal),
                      child: Text(
                        'Use as Anchor',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
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
