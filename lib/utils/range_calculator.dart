import 'dart:math';
import 'package:flutter/material.dart';
import '../models/live_data.dart';

class RangeCalculator {
  static List<KaratRange> computeKaratRanges(
    double anchorADC,
    int anchorKarat,
    double tolerance,
  ) {
    const karatTiers = [24, 22, 18, 14, 10, 9];
    final colors = {
      24: const Color(0xFFFFD700),
      22: const Color(0xFFFFB300),
      18: const Color(0xFFFFA000),
      14: const Color(0xFFFF8F00),
      10: const Color(0xFFFFE082),
      9: const Color(0xFFFFF9C4),
    };

    final ranges = <KaratRange>[];
    for (final tier in karatTiers) {
      final expected = anchorADC * (tier / anchorKarat);
      final min = expected - tolerance;
      final max = expected + tolerance;
      ranges.add(KaratRange(
        karat: tier,
        label: tier == 24 ? 'Pure Gold' : 'Gold',
        min: min,
        max: max,
        color: colors[tier]!,
      ));
    }
    return ranges;
  }

  static List<MetalRange> computeMetalRanges(double goldReferenceADC) {
    final references = [
      {'name': 'Platinum', 'expected': 26000.0, 'color': 0xFFE5E4E2, 'density': 21.45, 'desc': 'Noble metal, highly corrosion resistant'},
      {'name': 'Gold 24k', 'expected': 22000.0, 'color': 0xFFFFD700, 'density': 19.32, 'desc': 'Pure gold (99.9%)'},
      {'name': 'Gold 22k', 'expected': 20167.0, 'color': 0xFFFFB300, 'density': 17.8, 'desc': '91.7% gold content'},
      {'name': 'Gold 18k', 'expected': 16500.0, 'color': 0xFFFFA000, 'density': 15.6, 'desc': '75.0% gold content'},
      {'name': 'Gold 14k', 'expected': 12833.0, 'color': 0xFFFF8F00, 'density': 13.0, 'desc': '58.3% gold content'},
      {'name': 'Gold 10k', 'expected': 9167.0, 'color': 0xFFFFE082, 'density': 11.6, 'desc': '41.7% gold content'},
      {'name': 'Gold 9k', 'expected': 8250.0, 'color': 0xFFFFF9C4, 'density': 11.1, 'desc': '37.5% gold content'},
      {'name': 'Silver', 'expected': 8500.0, 'color': 0xFFC0C0C0, 'density': 10.5, 'desc': 'High conductivity metal'},
      {'name': 'Copper', 'expected': 5500.0, 'color': 0xFFB87333, 'density': 8.96, 'desc': 'Excellent conductor'},
      {'name': 'Brass', 'expected': 5000.0, 'color': 0xFFC9AE5D, 'density': 8.5, 'desc': 'Copper-zinc alloy'},
      {'name': 'Bronze', 'expected': 4500.0, 'color': 0xFFCD7F32, 'density': 8.8, 'desc': 'Copper-tin alloy'},
      {'name': 'Steel', 'expected': 3000.0, 'color': 0xFF8C8C8C, 'density': 7.85, 'desc': 'Iron-carbon alloy'},
      {'name': 'Iron', 'expected': 2500.0, 'color': 0xFF555555, 'density': 7.87, 'desc': 'Ferrous metal'},
      {'name': 'Aluminium', 'expected': 1500.0, 'color': 0xFFA8A9AD, 'density': 2.7, 'desc': 'Lightweight metal'},
    ];

    final tolerance = goldReferenceADC * 0.036; // ~800 at 22000 default
    return references.map((ref) {
      final expected = ref['expected'] as double;
      final scaled = expected * (goldReferenceADC / 22000.0);
      return MetalRange(
        metalName: ref['name'] as String,
        expectedADC: scaled,
        min: scaled - tolerance,
        max: scaled + tolerance,
        color: Color(ref['color'] as int),
        description: ref['desc'] as String,
        densityGcm3: ref['density'] as double,
      );
    }).toList();
  }

  static double computeConfidence(int adcValue, MetalRange range) {
    final diff = (adcValue - range.expectedADC).abs();
    final tol = range.max - range.min;
    final confidence = max(0, 1 - (diff / (tol / 2))) * 100;
    return min(100.0, confidence.toDouble());
  }

  static List<MetalMatch> identifyMetal(
    int adcValue,
    List<MetalRange> ranges, {
    double confidenceThreshold = 0,
  }) {
    final matches = <MetalMatch>[];
    for (final range in ranges) {
      final conf = computeConfidence(adcValue, range);
      if (conf >= confidenceThreshold) {
        String verdict;
        if (conf >= 80) {
          verdict = 'Excellent match';
        } else if (conf >= 60) {
          verdict = 'Likely match';
        } else if (conf >= 40) {
          verdict = 'Possible match';
        } else {
          verdict = 'Weak match';
        }
        matches.add(MetalMatch(metal: range, confidence: conf, verdict: verdict));
      }
    }
    matches.sort((a, b) => b.confidence.compareTo(a.confidence));
    return matches;
  }

  static double karatToPurityPercent(int karat) {
    return (karat / 24.0) * 100.0;
  }

  static int? findKaratFromADC(int adcValue, List<KaratRange> ranges) {
    for (final range in ranges) {
      if (range.contains(adcValue)) {
        return range.karat;
      }
    }
    return null;
  }
}
