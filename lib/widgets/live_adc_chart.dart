import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/live_data_provider.dart';
import '../providers/calibration_provider.dart';

class LiveADCChart extends ConsumerStatefulWidget {
  const LiveADCChart({super.key});

  @override
  ConsumerState<LiveADCChart> createState() => _LiveADCChartState();
}

class _LiveADCChartState extends ConsumerState<LiveADCChart> {
  final List<FlSpot> _spots = [];

  @override
  Widget build(BuildContext context) {
    final liveAsync = ref.watch(liveDataProvider);
    final cal = ref.watch(calibrationProvider);

    liveAsync.whenData((data) {
      setState(() {
        _spots.add(FlSpot(_spots.length.toDouble(), data.adcValue.toDouble()));
        if (_spots.length > 60) {
          _spots.removeAt(0);
          for (int i = 0; i < _spots.length; i++) {
            _spots[i] = FlSpot(i.toDouble(), _spots[i].y);
          }
        }
      });
    });

    if (_spots.isEmpty) {
      return Container(
        height: 200,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'Waiting for data...',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final adc = liveAsync.when(data: (d) => d.adcValue, loading: () => 0, error: (_, __) => 0);
    final isInAir = adc > 18000;
    final isNoSignal = adc < 500;

    return Container(
      height: 220,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isInAir ? const Color(0xFF332200) : isNoSignal ? const Color(0xFF1A1A1A) : const Color(0xFF222222),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInAir ? const Color(0xFFFFB300) : Colors.transparent,
          width: isInAir ? 2 : 0,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Live ADC',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              if (isInAir)
                const Text(
                  'Probe in air',
                  style: TextStyle(color: Color(0xFFFFB300), fontSize: 12, fontWeight: FontWeight.w600),
                )
              else if (isNoSignal)
                const Text(
                  'No signal',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                )
              else
                Text(
                  adc.toString(),
                  style: const TextStyle(color: Color(0xFFFFB300), fontSize: 14, fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5000,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.1),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 5000,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 30000,
                lineBarsData: [
                  LineChartBarData(
                    spots: _spots,
                    isCurved: false,
                    color: const Color(0xFFFFB300),
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        if (index == _spots.length - 1) {
                          return FlDotCirclePainter(
                            radius: 5,
                            color: const Color(0xFFFFB300),
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        }
                        return FlDotCirclePainter(radius: 0, color: Colors.transparent);
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFFFB300).withOpacity(0.1),
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
