import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/calibration_provider.dart';
import '../providers/live_data_provider.dart';
import '../utils/number_format.dart' as nf;

class RangeLadder extends ConsumerStatefulWidget {
  final bool showGoldOnly;
  const RangeLadder({super.key, this.showGoldOnly = true});

  @override
  ConsumerState<RangeLadder> createState() => _RangeLadderState();
}

class _RangeLadderState extends ConsumerState<RangeLadder>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cal = ref.watch(calibrationProvider);
    final liveAsync = ref.watch(liveDataProvider);
    final adc = liveAsync.when(data: (d) => d.adcValue, loading: () => 0, error: (_, __) => 0);
    // Probe in air: ADC > 15000 means no metal contact
    final isAir = adc > 15000;

    final ranges = widget.showGoldOnly
        ? cal.karatRanges
        : null;
    final metals = widget.showGoldOnly
        ? null
        : cal.metalRanges;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              child: Text(
                'Signal Ranges',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),

            if (widget.showGoldOnly && ranges != null) ...[
              ...ranges.map((range) {
                final isMatch = adc >= range.min && adc <= range.max && !isAir;
                return _RangeRow(
                  color: range.color,
                  label: '${range.karat}k',
                  sublabel: range.label,
                  rangeText: nf.NumberFormat.formatADCRange(range.min, range.max),
                  isMatch: isMatch,
                  glowController: _glowController,
                );
              }),
              // Not gold row — ADC more negative than the lowest karat bucket
              _RangeRow(
                color: const Color(0xFF757575),
                label: '<9k',
                sublabel: 'Not Gold',
                rangeText: 'Below ${nf.NumberFormat.formatADC(cal.karatRanges.last.min.toInt())}',
                isMatch: adc < cal.karatRanges.last.min && !isAir,
                glowController: _glowController,
              ),
            ],

            if (!widget.showGoldOnly && metals != null) ...[
              ...metals.map((metal) {
                final isMatch = adc >= metal.min && adc <= metal.max && !isAir;
                return _RangeRow(
                  color: metal.color,
                  label: metal.metalName,
                  sublabel: '',
                  rangeText: nf.NumberFormat.formatADCRange(metal.min, metal.max),
                  isMatch: isMatch,
                  glowController: _glowController,
                );
              }),
            ],
          ],
        ),

        // Probe in air overlay
        if (isAir)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFB300).withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber, color: Color(0xFFFFB300), size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Probe is in air — place on sample',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFFB300),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RangeRow extends StatelessWidget {
  final Color color;
  final String label;
  final String sublabel;
  final String rangeText;
  final bool isMatch;
  final AnimationController glowController;

  const _RangeRow({
    required this.color,
    required this.label,
    required this.sublabel,
    required this.rangeText,
    required this.isMatch,
    required this.glowController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowController,
      builder: (context, _) {
        final borderAlpha = isMatch
            ? (120 + (80 * glowController.value)).toInt()
            : 0;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isMatch
                ? const Color(0xFFFFB300).withAlpha(40) // Increased alpha for visibility
                : const Color(0xFF222222),
            borderRadius: BorderRadius.circular(10),
            border: isMatch
                ? Border.all(color: const Color(0xFFFFB300).withAlpha(180), width: 1.5)
                : Border.all(color: Colors.white.withAlpha(8)),
          ),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 40,
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: isMatch ? const Color(0xFFFFB300) : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (sublabel.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  sublabel,
                  style: GoogleFonts.inter(
                    color: Colors.white.withAlpha(100),
                    fontSize: 13,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                rangeText,
                style: GoogleFonts.inter(
                  color: isMatch
                      ? const Color(0xFFFFB300).withAlpha(200)
                      : Colors.white.withAlpha(100),
                  fontSize: 13,
                  fontWeight: isMatch ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (isMatch) ...[
                const SizedBox(width: 8),
                Text(
                  '◄',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFFB300),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
