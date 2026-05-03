import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/calibration_provider.dart';
import '../providers/live_data_provider.dart';
import '../utils/number_format.dart' as nf;

class LiveADCChart extends ConsumerStatefulWidget {
  const LiveADCChart({super.key});

  @override
  ConsumerState<LiveADCChart> createState() => _LiveADCChartState();
}

class _LiveADCChartState extends ConsumerState<LiveADCChart> {
  final List<FlSpot> _dataPoints = [];
  int _tick = 0;

  @override
  Widget build(BuildContext context) {
    final liveAsync = ref.watch(liveDataProvider);
    final cal = ref.watch(calibrationProvider);

    liveAsync.whenData((data) {
      _tick++;
      _dataPoints.add(FlSpot(_tick.toDouble(), data.adcValue.toDouble()));
      // Keep only 15 points for cleaner look (was 30)
      if (_dataPoints.length > 15) {
        _dataPoints.removeAt(0);
      }
    });

    if (_dataPoints.isEmpty) return const SizedBox.shrink();

    final minX = _dataPoints.first.x;
    final maxX = _dataPoints.last.x;
    final currentADC = _dataPoints.last.y;
    final isAir = currentADC > 18000;
    final noSignal = currentADC < 500;

    // Y axis range - tighter for better visualization
    final dataMin = _dataPoints.map((e) => e.y).reduce(min);
    final dataMax = _dataPoints.map((e) => e.y).reduce(max);
    final yMin = (dataMin - 500).clamp(0.0, 30000.0);
    final yMax = (dataMax + 500).clamp(1000.0, 32000.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      // Reduced height for cleaner UI
      height: 120, // Was unconstrained
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAir
            ? const Color(0xFFFFB300).withAlpha(8)
            : noSignal
                ? Colors.grey.withAlpha(8)
                : const Color(0xFF222222),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAir
              ? const Color(0xFFFFB300).withAlpha(40)
              : noSignal
                  ? Colors.grey.withAlpha(40)
                  : Colors.white.withAlpha(10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Live ADC',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12, // Smaller font
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAir
                      ? const Color(0xFFFFB300).withAlpha(25)
                      : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  nf.NumberFormat.formatADC(currentADC.toInt()),
                  style: GoogleFonts.inter(
                    color: isAir ? const Color(0xFFFFB300) : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          if (isAir)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Probe in air',
                style: GoogleFonts.inter(
                  color: const Color(0xFFFFB300),
                  fontSize: 12,
                ),
              ),
            ),
          if (noSignal)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'No signal',
                style: GoogleFonts.inter(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),

          const SizedBox(height: 8),
          // Reduced chart height for cleaner UI
          SizedBox(
            height: 80, // Was 150 - much more compact!
            child: LineChart(
              LineChartData(
                minX: minX,
                maxX: maxX,
                minY: yMin,
                maxY: yMax,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (yMax - yMin) / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withAlpha(10),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      interval: (yMax - yMin) / 4,
                      getTitlesWidget: (value, meta) => Text(
                        nf.NumberFormat.formatADC(value.toInt()),
                        style: GoogleFonts.inter(
                          color: Colors.white.withAlpha(60),
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    // Karat tier boundary lines
                    ...cal.karatRanges.expand((range) => [
                      HorizontalLine(
                        y: range.min,
                        color: range.color.withAlpha(30),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                      HorizontalLine(
                        y: range.max,
                        color: range.color.withAlpha(30),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ]),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _dataPoints,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    color: isAir
                        ? const Color(0xFFFFB300)
                        : const Color(0xFFFFB300),
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, xPercentage, bar, index) {
                        if (index == _dataPoints.length - 1) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: const Color(0xFFFFB300),
                            strokeColor: Colors.black,
                            strokeWidth: 2,
                          );
                        }
                        return FlDotCirclePainter(
                          radius: 0,
                          color: Colors.transparent,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFFFB300).withAlpha(40),
                          const Color(0xFFFFB300).withAlpha(5),
                        ],
                      ),
                    ),
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
