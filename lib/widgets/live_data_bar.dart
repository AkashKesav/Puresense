import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/live_data_provider.dart';
import '../utils/number_format.dart' as nf;

class LiveDataBar extends ConsumerWidget {
  const LiveDataBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveAsync = ref.watch(liveDataProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          top: BorderSide(color: Colors.white.withAlpha(15)),
        ),
      ),
      child: liveAsync.when(
        data: (data) {
          final isAir = data.adcValue > 18000;
          final noSignal = data.adcValue < 500;

          return Row(
            children: [
              // Weight
              Text(
                '⚖ ${nf.NumberFormat.formatWeight(data.weightGrams)} g',
                style: GoogleFonts.inter(
                  color: Colors.white.withAlpha(200),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 1,
                height: 16,
                color: Colors.white.withAlpha(25),
              ),
              // ADC
              Text(
                '⚡ ADC: ${nf.NumberFormat.formatADC(data.adcValue)}',
                style: GoogleFonts.inter(
                  color: Colors.white.withAlpha(200),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Probe status dot & badge
              if (isAir)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFB300),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Probe in air',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFFB300),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else if (noSignal)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'No signal',
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                _AnimatedStatusDot(),
            ],
          );
        },
        loading: () => Row(
          children: [
            Text(
              '⚖ -- g   |   ⚡ ADC: --',
              style: GoogleFonts.inter(
                color: Colors.white.withAlpha(80),
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(80),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        error: (_, __) => Text(
          'Sensor disconnected',
          style: GoogleFonts.inter(
            color: Colors.red.withAlpha(180),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _AnimatedStatusDot extends StatefulWidget {
  @override
  State<_AnimatedStatusDot> createState() => _AnimatedStatusDotState();
}

class _AnimatedStatusDotState extends State<_AnimatedStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Color.lerp(
              const Color(0xFFFFB300).withAlpha(120),
              const Color(0xFFFFB300),
              _controller.value,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFB300).withAlpha(
                  (60 * _controller.value).toInt(),
                ),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}
