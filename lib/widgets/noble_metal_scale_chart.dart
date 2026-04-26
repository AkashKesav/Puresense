import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/metal_reference_provider.dart';
import '../providers/live_data_provider.dart';

class NobleMetalScaleChart extends ConsumerWidget {
  const NobleMetalScaleChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metalState = ref.watch(metalReferenceProvider);
    final liveAsync = ref.watch(liveDataProvider);
    final adc = liveAsync.when(data: (d) => d.adcValue, loading: () => 0, error: (_, __) => 0);

    final metals = metalState.allMetals;
    if (metals.isEmpty) return const SizedBox.shrink();

    // Scale: -14000 (crude) to 0 (noble)
    const scaleMin = -14000.0;
    const scaleMax = 0.0;
    const scaleRange = scaleMax - scaleMin; // 14000

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Noble Metal Scale',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '← Crude   Noble →',
                style: GoogleFonts.inter(
                  color: Colors.white.withAlpha(60),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;

              // Map ADC to position (more negative = left, less negative = right)
              double adcToPos(double val) {
                return ((val - scaleMin) / scaleRange * barWidth).clamp(0.0, barWidth);
              }

              final indicatorPos = adcToPos(adc.toDouble());
              final showIndicator = adc <= 15000;

              return Column(
                children: [
                  // ADC scale bar with metal segments
                  SizedBox(
                    height: 32,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Background
                        Container(
                          height: 32,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF333333),
                                Color(0xFF555555),
                                Color(0xFFFFB300),
                              ],
                            ),
                          ),
                        ),

                        // Metal markers
                        ...metals.map((metal) {
                          final pos = adcToPos(metal.expectedADC);
                          return Positioned(
                            left: pos.clamp(0.0, barWidth - 3),
                            top: 0,
                            child: Tooltip(
                              message: metal.metalName,
                              child: Container(
                                width: 3,
                                height: 32,
                                color: metal.color,
                              ),
                            ),
                          );
                        }),

                        // Live indicator
                        if (showIndicator)
                          Positioned(
                            left: (indicatorPos - 1).clamp(0.0, barWidth - 2),
                            top: -6,
                            child: Container(
                              width: 3,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withAlpha(100),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Scale labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '-14k',
                        style: GoogleFonts.inter(
                          color: Colors.white.withAlpha(60),
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        '-10k',
                        style: GoogleFonts.inter(
                          color: Colors.white.withAlpha(60),
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        '-5k',
                        style: GoogleFonts.inter(
                          color: Colors.white.withAlpha(60),
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        '0',
                        style: GoogleFonts.inter(
                          color: Colors.white.withAlpha(60),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
