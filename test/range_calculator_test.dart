import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puresense/models/live_data.dart';
import 'package:puresense/utils/range_calculator.dart';
import 'package:puresense/utils/statistical_classifier.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Tests for the OFFSET-BASED karat range system
//
// Why offset-based wins over proportional (referenceADC × karat/24):
//   Proportional breaks with negative ADC — lower karats appear more noble.
//   Offset-based preserves the correct ordering for BOTH positive AND negative.
//
// Formula:  expected = anchorADC + (refADC[tier] - refADC[anchorKarat]) × scale
// Where:    scale = |anchorADC / refADC[anchorKarat]|
// ═══════════════════════════════════════════════════════════════════════════

// ─── Helpers ────────────────────────────────────────────────────────────────

void printRangeTable(List<KaratRange> ranges, String label) {
  // ignore: avoid_print
  print('');
  // ignore: avoid_print
  print('═══════════════════════════════════════════════════════════════');
  // ignore: avoid_print
  print('  $label');
  // ignore: avoid_print
  print('═══════════════════════════════════════════════════════════════');
  // ignore: avoid_print
  print('  Tier  │  Center       │  Min          │  Max');
  // ignore: avoid_print
  print('  ──────┼───────────────┼───────────────┼─────────────');
  for (final r in ranges) {
    final center = (r.min + r.max) / 2;
    // ignore: avoid_print
    print('  ${r.karat}k'.padRight(8) +
        '│  ${center.toStringAsFixed(1).padLeft(11)}  '
            '│  ${r.min.toStringAsFixed(1).padLeft(11)}  '
            '│  ${r.max.toStringAsFixed(1).padLeft(11)}');
  }
  // ignore: avoid_print
  print('═══════════════════════════════════════════════════════════════');
  // ignore: avoid_print
  print('');
}

void assertTier(
  int adcValue,
  List<KaratRange> ranges,
  int? expectedKarat, {
  String? desc,
}) {
  final result = RangeCalculator.classifyADC(adcValue, ranges);
  final tag = desc != null ? ' ($desc)' : '';

  if (expectedKarat == null) {
    expect(result, isNull,
        reason: 'ADC $adcValue$tag: expected Not Gold, '
            'got ${result?.karat}k');
  } else {
    expect(result, isNotNull,
        reason: 'ADC $adcValue$tag: expected ${expectedKarat}k, got Not Gold');
    expect(result!.karat, equals(expectedKarat),
        reason: 'ADC $adcValue$tag: expected ${expectedKarat}k, '
            'got ${result.karat}k');
  }

  final label = result != null ? '${result.karat}k ✓' : 'Not Gold ✓';
  // ignore: avoid_print
  print('  ADC $adcValue → $label$tag');
}

// ═══════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // Scenario 1: NEGATIVE anchor — 22k at -1500, tolerance 50
  //
  // Reference table offsets from 22k:
  //   24k: +125  → expected = -1375
  //   22k:    0  → expected = -1500
  //   18k: -300  → expected = -1800
  //   14k: -800  → expected = -2300
  //   10k: -1700 → expected = -3200
  //    9k: -2100 → expected = -3600
  // ─────────────────────────────────────────────────────────────────────────
  group('Scenario 1: Negative anchor (22k @ -1500, tol=50)', () {
    late List<KaratRange> ranges;

    setUp(() {
      ranges = RangeCalculator.computeKaratRanges(-1500.0, 22, 50.0);
      printRangeTable(ranges, 'Anchor: 22k @ -1500 ADC, tolerance=±50');
    });

    test('Tier ordering: 24k > 22k > 18k > 14k > 10k > 9k on the number line',
        () {
      // Sort by (min+max)/2 descending — 24k should be highest (least negative)
      final sorted = List<KaratRange>.from(ranges);
      sorted.sort((KaratRange a, KaratRange b) =>
          ((b.min + b.max) / 2).compareTo((a.min + a.max) / 2));
      final karats = sorted.map((KaratRange r) => r.karat).toList();
      expect(karats, equals([24, 22, 18, 14, 10, 9]),
          reason: 'Noble order: 24k most positive, 9k most negative');
      // ignore: avoid_print
      print('  Order verified: ${karats.join(" > ")} ✓');
    });

    test('Centers match expected reference values', () {
      final byKarat = {for (final r in ranges) r.karat: r};

      // 22k should be at anchor = -1500 (offset=0)
      final c22 = (byKarat[22]!.min + byKarat[22]!.max) / 2;
      expect(c22, closeTo(-1500.0, 1.0));

      // 24k should be at -1375 (offset = +125)
      // Note: 24k has an extended max, so center shifts slightly
      // Check min instead: -1375 - 50 = -1425
      expect(byKarat[24]!.min, closeTo(-1425.0, 1.0));

      // 18k at -1800
      final c18 = (byKarat[18]!.min + byKarat[18]!.max) / 2;
      expect(c18, closeTo(-1800.0, 1.0));

      // 14k at -2300
      final c14 = (byKarat[14]!.min + byKarat[14]!.max) / 2;
      expect(c14, closeTo(-2300.0, 1.0));

      // 10k at -3200
      final c10 = (byKarat[10]!.min + byKarat[10]!.max) / 2;
      expect(c10, closeTo(-3200.0, 1.0));

      // 9k at -3600
      final c9 = (byKarat[9]!.min + byKarat[9]!.max) / 2;
      expect(c9, closeTo(-3600.0, 1.0));
    });

    test('ADC values classify into correct tiers', () {
      assertTier(-1500, ranges, 22, desc: '22k center');
      assertTier(-1800, ranges, 18, desc: '18k center');
      assertTier(-2300, ranges, 14, desc: '14k center');
      assertTier(-3200, ranges, 10, desc: '10k center');
      assertTier(-3600, ranges, 9, desc: '9k center');
      assertTier(-10000, ranges, null, desc: 'far below all gold tiers');
      assertTier(0, ranges, 24, desc: 'inside extended 24k range');
      assertTier(15000, ranges, null, desc: 'probe in air');
    });

    test('Boundary tests (tolerance=50)', () {
      // 22k range: [-1550, -1450]
      assertTier(-1550, ranges, 22, desc: '22k lower bound');
      assertTier(-1450, ranges, 22, desc: '22k upper bound');
      assertTier(-1551, ranges, null, desc: 'just below 22k');
      assertTier(-1449, ranges, null, desc: 'just above 22k');

      // 10k range: [-3250, -3150]
      assertTier(-3250, ranges, 10, desc: '10k lower bound');
      assertTier(-3150, ranges, 10, desc: '10k upper bound');
      assertTier(-3251, ranges, null, desc: 'just below 10k');
      assertTier(-3149, ranges, null, desc: 'just above 10k');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Scenario 2: POSITIVE anchor — 22k at +1500, tolerance 50
  //
  // This is the key test: the offset model must place lower karats
  // BELOW the anchor (less positive / more negative), not above.
  //
  // scale = |1500 / -1500| = 1.0
  //   24k: 1500 + 125 = +1625
  //   22k: 1500 +   0 = +1500
  //   18k: 1500 - 300 = +1200
  //   14k: 1500 - 800 = +700
  //   10k: 1500 - 1700 = -200
  //    9k: 1500 - 2100 = -600
  // ─────────────────────────────────────────────────────────────────────────
  group('Scenario 2: Positive anchor (22k @ +1500, tol=50)', () {
    late List<KaratRange> ranges;

    setUp(() {
      ranges = RangeCalculator.computeKaratRanges(1500.0, 22, 50.0);
      printRangeTable(ranges, 'Anchor: 22k @ +1500 ADC, tolerance=±50');
    });

    test('Tier ordering preserved: 24k > 22k > 18k > 14k > 10k > 9k', () {
      final sorted = List<KaratRange>.from(ranges)
        ..sort((a, b) => ((b.min + b.max) / 2).compareTo((a.min + a.max) / 2));
      final karats = sorted.map((r) => r.karat).toList();
      expect(karats, equals([24, 22, 18, 14, 10, 9]));
      // ignore: avoid_print
      print('  Order verified: ${karats.join(" > ")} ✓');
    });

    test('Lower karats are BELOW anchor (less positive / negative)', () {
      final byKarat = {for (final r in ranges) r.karat: r};

      // 22k at +1500
      final c22 = (byKarat[22]!.min + byKarat[22]!.max) / 2;
      expect(c22, closeTo(1500.0, 1.0));

      // 18k should be +1200 (LESS than 1500 ✓)
      final c18 = (byKarat[18]!.min + byKarat[18]!.max) / 2;
      expect(c18, closeTo(1200.0, 1.0));
      expect(c18, lessThan(c22), reason: '18k must be below 22k');

      // 14k should be +700
      final c14 = (byKarat[14]!.min + byKarat[14]!.max) / 2;
      expect(c14, closeTo(700.0, 1.0));
      expect(c14, lessThan(c18), reason: '14k must be below 18k');

      // 10k should be -200 (crosses into negative ✓)
      final c10 = (byKarat[10]!.min + byKarat[10]!.max) / 2;
      expect(c10, closeTo(-200.0, 1.0));
      expect(c10, lessThan(c14), reason: '10k must be below 14k');

      // 9k should be -600
      final c9 = (byKarat[9]!.min + byKarat[9]!.max) / 2;
      expect(c9, closeTo(-600.0, 1.0));
      expect(c9, lessThan(c10), reason: '9k must be below 10k');

      // ignore: avoid_print
      print('  All lower karats correctly placed below anchor ✓');
    });

    test('ADC classification works with positive anchor', () {
      assertTier(1500, ranges, 22, desc: '22k center at +1500');
      assertTier(1200, ranges, 18, desc: '18k center at +1200');
      assertTier(700, ranges, 14, desc: '14k center at +700');
      assertTier(-200, ranges, 10, desc: '10k center at -200');
      assertTier(-600, ranges, 9, desc: '9k center at -600');
      assertTier(5000, ranges, null, desc: 'way above all tiers');
      assertTier(-5000, ranges, null, desc: 'way below all tiers');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Scenario 3: Scaled anchor — 22k at -3000 (2× magnitude)
  //
  // scale = |-3000 / -1500| = 2.0
  // All offsets scaled by 2:
  //   24k: -3000 + 125×2 = -2750
  //   22k: -3000 +   0   = -3000
  //   18k: -3000 - 300×2 = -3600
  //   14k: -3000 - 800×2 = -4600
  //   10k: -3000 - 1700×2 = -6400
  //    9k: -3000 - 2100×2 = -7200
  // ─────────────────────────────────────────────────────────────────────────
  group('Scenario 3: Scaled anchor (22k @ -3000, tol=50)', () {
    late List<KaratRange> ranges;

    setUp(() {
      ranges = RangeCalculator.computeKaratRanges(-3000.0, 22, 50.0);
      printRangeTable(ranges, 'Anchor: 22k @ -3000 ADC (2× scale), tol=±50');
    });

    test('All tiers scale proportionally with anchor magnitude', () {
      final byKarat = {for (final r in ranges) r.karat: r};

      final c22 = (byKarat[22]!.min + byKarat[22]!.max) / 2;
      expect(c22, closeTo(-3000.0, 1.0));

      final c18 = (byKarat[18]!.min + byKarat[18]!.max) / 2;
      expect(c18, closeTo(-3600.0, 1.0));

      final c14 = (byKarat[14]!.min + byKarat[14]!.max) / 2;
      expect(c14, closeTo(-4600.0, 1.0));

      final c10 = (byKarat[10]!.min + byKarat[10]!.max) / 2;
      expect(c10, closeTo(-6400.0, 1.0));

      final c9 = (byKarat[9]!.min + byKarat[9]!.max) / 2;
      expect(c9, closeTo(-7200.0, 1.0));
    });

    test('Tolerance also scales with anchor magnitude', () {
      final byKarat = {for (final r in ranges) r.karat: r};

      // At scale=2, tol=50 becomes scaledTol = 50 × 2 = 100
      // So 22k range width = 200
      final width22 = byKarat[22]!.max - byKarat[22]!.min;
      expect(width22, closeTo(200.0, 1.0),
          reason: 'Tolerance scales with anchor magnitude');
    });

    test('Classification at scaled values', () {
      assertTier(-3000, ranges, 22, desc: '22k at -3000');
      assertTier(-3600, ranges, 18, desc: '18k at -3600');
      assertTier(-6400, ranges, 10, desc: '10k at -6400');
      // Note: -1000 falls inside the extended 24k range (24k max extends
      // 2000*scale above expected to catch noble readings)
      assertTier(-1000, ranges, 24,
          desc: 'inside extended 24k range (noble reading)');
      assertTier(-10000, ranges, null, desc: 'below all gold tiers');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Scenario 4: Tight vs wide tolerance
  // ─────────────────────────────────────────────────────────────────────────
  group('Scenario 4: Tolerance affects band width', () {
    test('Tighter tolerance (10) narrows all bands', () {
      final narrow = RangeCalculator.computeKaratRanges(-1500.0, 22, 10.0);
      printRangeTable(narrow, 'TIGHT: 22k @ -1500, tol=±10');

      final byKarat = {for (final r in narrow) r.karat: r};

      // 22k width should be 2 × 10 × 1.0 = 20
      final width22 = byKarat[22]!.max - byKarat[22]!.min;
      expect(width22, closeTo(20.0, 0.01));

      // Center values stay the same
      assertTier(-1500, narrow, 22, desc: '22k center still matches');
      assertTier(-1800, narrow, 18, desc: '18k center still matches');

      // Old edge (-1550) is now outside with tight tolerance
      assertTier(-1550, narrow, null,
          desc: 'was inside 22k at tol=50, now outside at tol=10');
    });

    test('Wider tolerance (300) expands all bands', () {
      final wide = RangeCalculator.computeKaratRanges(-1500.0, 22, 300.0);
      printRangeTable(wide, 'WIDE: 22k @ -1500, tol=±300');

      final byKarat = {for (final r in wide) r.karat: r};

      // 22k width should be 2 × 300 × 1.0 = 600
      final width22 = byKarat[22]!.max - byKarat[22]!.min;
      expect(width22, closeTo(600.0, 0.01));

      // Values far from center now classify correctly
      assertTier(-1750, wide, 22, desc: '-1750 now inside 22k with wide tol');
    });

    test('Centers unchanged when only tolerance changes', () {
      final narrow = RangeCalculator.computeKaratRanges(-1500.0, 22, 10.0);
      final wide = RangeCalculator.computeKaratRanges(-1500.0, 22, 300.0);

      // Skip 24k (has extension logic that shifts center)
      for (int i = 1; i < narrow.length; i++) {
        final cn = (narrow[i].min + narrow[i].max) / 2;
        final cw = (wide[i].min + wide[i].max) / 2;
        expect(cn, closeTo(cw, 0.01),
            reason:
                '${narrow[i].karat}k center must be same regardless of tol');
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Scenario 5: Edge cases
  // ─────────────────────────────────────────────────────────────────────────
  group('Scenario 5: Edge cases', () {
    late List<KaratRange> ranges;

    setUp(() {
      ranges = RangeCalculator.computeKaratRanges(-1500.0, 22, 50.0);
    });

    test('ADC = 0 → inside extended 24k range', () {
      // The 24k range is extended ~2000 units above its expected value
      // so ADC=0 (which is more noble than 24k expected at -1375) falls
      // inside the extended 24k range. This is correct behavior.
      assertTier(0, ranges, 24, desc: 'inside extended 24k range');
    });

    test('ADC = large positive → Not Gold (probe in air)', () {
      assertTier(15000, ranges, null, desc: 'probe in air');
      assertTier(32000, ranges, null, desc: 'extreme positive');
    });

    test('ADC on exact boundary classifies INTO that tier', () {
      // ignore: avoid_print
      print('  Boundary containment checks:');
      // Skip 24k (extended range) and check remaining tiers
      for (final r in ranges.where((KaratRange r) => r.karat != 24)) {
        final minInt = r.min.ceil();
        final maxInt = r.max.floor();

        assertTier(minInt, ranges, r.karat,
            desc: '${r.karat}k at min boundary ($minInt)');
        assertTier(maxInt, ranges, r.karat,
            desc: '${r.karat}k at max boundary ($maxInt)');
      }
    });

    test('No two tiers overlap', () {
      // ignore: avoid_print
      print('  Overlap check:');
      // Sort by center descending (24k highest to 9k lowest)
      final sorted = List<KaratRange>.from(ranges);
      sorted.sort((KaratRange a, KaratRange b) =>
          ((b.min + b.max) / 2).compareTo((a.min + a.max) / 2));

      for (int i = 0; i < sorted.length - 1; i++) {
        final upper = sorted[i];
        final lower = sorted[i + 1];

        // upper.min must be > lower.max for no overlap
        final gap = upper.min - lower.max;
        // ignore: avoid_print
        print('    ${upper.karat}k min (${upper.min.toStringAsFixed(1)}) — '
            '${lower.karat}k max (${lower.max.toStringAsFixed(1)}) = '
            'gap ${gap.toStringAsFixed(1)}');

        expect(gap, greaterThanOrEqualTo(0),
            reason: '${upper.karat}k and ${lower.karat}k overlap '
                'by ${gap.abs().toStringAsFixed(1)}');
      }
    });

    test('No ADC value matches more than one tier (sweep test)', () {
      // Sweep from -5000 to +5000
      for (int adc = -5000; adc <= 5000; adc++) {
        int matchCount = 0;
        final matchedTiers = <int>[];
        for (final range in ranges) {
          if (range.contains(adc)) {
            matchCount++;
            matchedTiers.add(range.karat);
          }
        }
        expect(matchCount, lessThanOrEqualTo(1),
            reason: 'ADC $adc matched $matchCount tiers: $matchedTiers');
      }
      // ignore: avoid_print
      print('  Sweep -5000..+5000: no double classification ✓');
    });

    test('Changing anchor shifts ALL boundaries proportionally', () {
      final r1 = RangeCalculator.computeKaratRanges(-1500.0, 22, 50.0);
      final r2 = RangeCalculator.computeKaratRanges(-3000.0, 22, 50.0);

      // ignore: avoid_print
      print('  Proportional shift (-1500 → -3000, ratio ≈ 2.0):');
      // Skip 24k (has extension). Check others.
      for (int i = 1; i < r1.length; i++) {
        final c1 = (r1[i].min + r1[i].max) / 2;
        final c2 = (r2[i].min + r2[i].max) / 2;

        // The offset from anchor scales by 2, but the anchor itself also changes.
        // At scale=1: offset from -1500. At scale=2: offset from -3000.
        // So absolute positions should change proportionally.
        // ignore: avoid_print
        print('    ${r1[i].karat}k: ${c1.toStringAsFixed(0)} → '
            '${c2.toStringAsFixed(0)}');
      }

      // Key check: 22k stays at anchor
      final c22_1 = (r1[1].min + r1[1].max) / 2;
      final c22_2 = (r2[1].min + r2[1].max) / 2;
      expect(c22_1, closeTo(-1500.0, 1.0));
      expect(c22_2, closeTo(-3000.0, 1.0));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Scenario 6: Proof that proportional model fails for negative ADC
  // (This documents WHY we use the offset model)
  // ─────────────────────────────────────────────────────────────────────────
  group('Scenario 6: Proportional model failure proof', () {
    test('Proportional formula inverts order for negative reference', () {
      // The WRONG formula: center = referenceADC × (karat/24)
      const ref = -1500.0;

      final wrongCenters = <int, double>{};
      for (final k in [24, 22, 18, 14, 10]) {
        wrongCenters[k] = ref * (k / 24.0);
      }

      // ignore: avoid_print
      print('  Proportional model with ref=-1500:');
      for (final e in wrongCenters.entries) {
        // ignore: avoid_print
        print('    ${e.key}k → ${e.value.toStringAsFixed(1)}');
      }

      // This shows the BROKEN order:
      // 24k = -1500, 22k = -1375, 18k = -1125, 10k = -625
      // 10k appears MOST noble (closest to 0) — WRONG!
      expect(wrongCenters[10]!, greaterThan(wrongCenters[22]!),
          reason: 'Proportional model: 10k appears more noble than 22k (BUG)');

      // Now show the offset model gets it RIGHT
      final correctRanges =
          RangeCalculator.computeKaratRanges(-1500.0, 22, 50.0);
      final correctCenters = <int, double>{};
      for (final r in correctRanges) {
        correctCenters[r.karat] = (r.min + r.max) / 2;
      }

      // ignore: avoid_print
      print('');
      // ignore: avoid_print
      print('  Offset model with anchor 22k @ -1500:');
      for (final e in correctCenters.entries) {
        // ignore: avoid_print
        print('    ${e.key}k → ${e.value.toStringAsFixed(1)}');
      }

      // 10k should be MORE negative than 22k (less noble)
      expect(correctCenters[10]!, lessThan(correctCenters[22]!),
          reason: 'Offset model: 10k correctly below 22k');
      expect(correctCenters[22]!, lessThan(correctCenters[24]!),
          reason: 'Offset model: 22k correctly below 24k');

      // ignore: avoid_print
      print('  Offset model preserves correct ordering ✓');
    });
  });

  group('Adaptive statistical ranges', () {
    test('Adaptive karat ranges preserve expected ADC centers', () {
      final base = RangeCalculator.computeKaratRanges(-1500.0, 22, 50.0);
      final stat = StatisticalResult(
        adc0: -1510,
        slope: -80,
        rawMean: -1570,
        residualVariance: 49,
        residualStdDev: 7,
        confidence: 92,
        sampleCount: 5,
        durationSeconds: 0.8,
        rSquared: 0.95,
      );

      final adaptive = RangeCalculator.computeAdaptiveKaratRanges(base, stat);
      expect(adaptive.length, base.length);

      for (int i = 0; i < base.length; i++) {
        expect(adaptive[i].expectedADC, closeTo(base[i].expectedADC, 0.001));
        expect(adaptive[i].expectedADC, greaterThanOrEqualTo(adaptive[i].min));
        expect(adaptive[i].expectedADC, lessThanOrEqualTo(adaptive[i].max));
      }
    });

    test('Noisier signal widens adaptive karat ranges', () {
      final base = RangeCalculator.computeKaratRanges(-1500.0, 22, 50.0);
      final stable = StatisticalResult(
        adc0: -1505,
        slope: -30,
        rawMean: -1520,
        residualVariance: 16,
        residualStdDev: 4,
        confidence: 95,
        sampleCount: 6,
        durationSeconds: 0.8,
        rSquared: 0.98,
      );
      final noisy = StatisticalResult(
        adc0: -1540,
        slope: -260,
        rawMean: -1700,
        residualVariance: 22500,
        residualStdDev: 150,
        confidence: 20,
        sampleCount: 6,
        durationSeconds: 0.8,
        rSquared: 0.35,
      );

      final stableAdaptive =
          RangeCalculator.computeAdaptiveKaratRanges(base, stable);
      final noisyAdaptive =
          RangeCalculator.computeAdaptiveKaratRanges(base, noisy);

      final stableSpan =
          stableAdaptive[2].max - stableAdaptive[2].min; // 18k band
      final noisySpan = noisyAdaptive[2].max - noisyAdaptive[2].min;
      expect(noisySpan, greaterThan(stableSpan));
    });

    test('Noisier signal widens adaptive metal ranges', () {
      final metals = RangeCalculator.computeMetalRanges(-1500.0);
      final stable = StatisticalResult(
        adc0: -1490,
        slope: -25,
        rawMean: -1500,
        residualVariance: 9,
        residualStdDev: 3,
        confidence: 94,
        sampleCount: 5,
        durationSeconds: 0.8,
        rSquared: 0.99,
      );
      final noisy = StatisticalResult(
        adc0: -1600,
        slope: -320,
        rawMean: -1860,
        residualVariance: 36100,
        residualStdDev: 190,
        confidence: 18,
        sampleCount: 5,
        durationSeconds: 0.8,
        rSquared: 0.2,
      );

      final stableAdaptive =
          RangeCalculator.computeAdaptiveMetalRanges(metals, stable);
      final noisyAdaptive =
          RangeCalculator.computeAdaptiveMetalRanges(metals, noisy);

      final stableSilver =
          stableAdaptive.firstWhere((m) => m.metalName == 'Silver');
      final noisySilver =
          noisyAdaptive.firstWhere((m) => m.metalName == 'Silver');
      final stableSpan = stableSilver.max - stableSilver.min;
      final noisySpan = noisySilver.max - noisySilver.min;
      expect(noisySpan, greaterThan(stableSpan));
    });
  });

  group('Metal identification ranking', () {
    test('In-range metal is prioritized over out-of-range nearest-center metal',
        () {
      final ranges = <MetalRange>[
        MetalRange(
          metalName: 'InRangeEdge',
          expectedADC: -5000,
          min: -5500,
          max: -4500,
          color: const Color(0xFF111111),
          description: 'In range',
        ),
        MetalRange(
          metalName: 'OutRangeNearCenter',
          expectedADC: -4490,
          min: -4390,
          max: -4290,
          color: const Color(0xFF222222),
          description: 'Out of range',
        ),
      ];

      final matches = RangeCalculator.identifyMetal(-4500, ranges);
      expect(matches, isNotEmpty);
      expect(matches.first.metal.metalName, equals('InRangeEdge'));
      expect(matches.first.confidence, greaterThan(0));
    });

    test('Out-of-range ADC still picks nearest metal first', () {
      final ranges = <MetalRange>[
        MetalRange(
          metalName: 'A',
          expectedADC: -1000,
          min: -1100,
          max: -900,
          color: const Color(0xFF111111),
          description: 'A',
        ),
        MetalRange(
          metalName: 'B',
          expectedADC: -5000,
          min: -5100,
          max: -4900,
          color: const Color(0xFF222222),
          description: 'B',
        ),
        MetalRange(
          metalName: 'C',
          expectedADC: -9000,
          min: -9100,
          max: -8900,
          color: const Color(0xFF333333),
          description: 'C',
        ),
      ];

      final matches = RangeCalculator.identifyMetal(-7400, ranges);
      expect(matches, isNotEmpty);
      expect(matches.first.metal.metalName, equals('C'));
      expect(matches.first.confidence, greaterThan(0));
    });

    test('Confidence sort breaks ties by smaller distance', () {
      final ranges = <MetalRange>[
        MetalRange(
          metalName: 'Near',
          expectedADC: -3200,
          min: -3300,
          max: -3100,
          color: const Color(0xFF101010),
          description: 'Near',
        ),
        MetalRange(
          metalName: 'Far',
          expectedADC: -4200,
          min: -4300,
          max: -4100,
          color: const Color(0xFF202020),
          description: 'Far',
        ),
      ];

      final matches = RangeCalculator.identifyMetal(-3600, ranges);
      expect(matches, isNotEmpty);
      expect(matches.first.metal.metalName, equals('Near'));
    });
  });

  group('Robust ADC aggregation', () {
    test('Drops probe-in-air spikes when contact samples exist', () {
      final adc = RangeCalculator.computeRobustADC(
        <int>[-1515, -1500, -1490, 17500, 18000, -1508],
      );
      expect(adc, closeTo(-1503, 8));
    });

    test('Falls back to air mean when all samples indicate air', () {
      final adc = RangeCalculator.computeRobustADC(
        <int>[18850, 19020, 19100],
      );
      expect(adc, greaterThan(15000));
      expect(adc, closeTo(18990, 120));
    });

    test('Trimmed mean suppresses both high and low outliers', () {
      final adc = RangeCalculator.computeRobustADC(
        <int>[-1500, -1495, -1510, -1502, -1498, -4300, 5200],
      );
      expect(adc, closeTo(-1501, 8));
    });
  });
}
