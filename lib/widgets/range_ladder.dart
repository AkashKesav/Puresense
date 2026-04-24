import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_data.dart';
import '../providers/calibration_provider.dart';
import '../providers/live_data_provider.dart';

class RangeLadder extends ConsumerWidget {
  final bool showGoldOnly;
  const RangeLadder({super.key, this.showGoldOnly = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cal = ref.watch(calibrationProvider);
    final liveAsync = ref.watch(liveDataProvider);
    final adc = liveAsync.when(data: (d) => d.adcValue, loading: () => 0, error: (_, __) => 0);

    final ranges = showGoldOnly ? cal.karatRanges : cal.metalRanges;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showGoldOnly) ...[
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Gold Tiers',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          ...cal.karatRanges.map((range) => _buildRow(range, adc)),
          _buildNotGoldRow(adc, cal.karatRanges),
        ] else ...[
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'All Metals',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          ...cal.metalRanges.map((range) => _buildMetalRow(range, adc)),
        ],
      ],
    );
  }

  Widget _buildRow(KaratRange range, int liveADC) {
    final isMatch = range.contains(liveADC);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(8),
        border: isMatch
            ? Border.all(color: const Color(0xFFFFB300), width: 2)
            : Border.all(color: Colors.transparent, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: range.color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${range.karat}k',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Text(
            range.label,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
          ),
          const Spacer(),
          Text(
            '${range.min.toStringAsFixed(0)} – ${range.max.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
          ),
          if (isMatch)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.arrow_left, color: Color(0xFFFFB300), size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildNotGoldRow(int liveADC, List<KaratRange> karatRanges) {
    final isBelow = karatRanges.isNotEmpty && liveADC < karatRanges.last.min;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(8),
        border: isBelow
            ? Border.all(color: const Color(0xFF757575), width: 2)
            : Border.all(color: Colors.transparent, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF757575),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Below 9k / Not Gold',
            style: TextStyle(color: Color(0xFF757575), fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (isBelow)
            const Icon(Icons.arrow_left, color: Color(0xFF757575), size: 20),
        ],
      ),
    );
  }

  Widget _buildMetalRow(MetalRange range, int liveADC) {
    final isMatch = liveADC >= range.min && liveADC <= range.max;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(8),
        border: isMatch
            ? Border.all(color: const Color(0xFFFFB300), width: 2)
            : Border.all(color: Colors.transparent, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: range.color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            range.metalName,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text(
            '${range.min.toStringAsFixed(0)} – ${range.max.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'monospace'),
          ),
          if (isMatch)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.arrow_left, color: Color(0xFFFFB300), size: 20),
            ),
        ],
      ),
    );
  }
}
