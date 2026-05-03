import 'dart:math';
import 'package:flutter/material.dart';
import '../models/live_data.dart';
import 'statistical_classifier.dart';

class AdaptiveRangeProfile {
  final double driftAllowance;
  final double noiseAllowance;
  final double meanCorrection;
  final double stabilityMultiplier;
  final double additivePadding;

  const AdaptiveRangeProfile({
    required this.driftAllowance,
    required this.noiseAllowance,
    required this.meanCorrection,
    required this.stabilityMultiplier,
    required this.additivePadding,
  });
}

class RangeCalculator {
  /// Compute karat ranges based on anchor ADC.
  ///
  /// Uses offset-based scaling so that lower karats always read as LESS noble
  /// (more negative or less positive) than the anchor, regardless of anchor sign.
  ///
  /// Reference offsets from 22k at -1500 ADC:
  ///   24k: +125, 22k: 0, 18k: -300, 14k: -800, 10k: -1700, 9k: -2100
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

    // Reference values at 22k = -1500 baseline
    const refValues = {
      24: -1375.0,
      22: -1500.0,
      18: -1800.0,
      14: -2300.0,
      10: -3200.0,
      9: -3600.0,
    };
    const refAnchor = -1500.0; // 22k reference

    // Compute offset from the reference karat baseline, then scale
    final refForAnchorKarat = refValues[anchorKarat] ?? refAnchor;
    final scaleFactor = (anchorADC / refForAnchorKarat).abs();

    // Calculate base expected ADC values with scaling
    final baseExpected = <int, double>{};
    for (final tier in karatTiers) {
      final refADC = refValues[tier] ?? refAnchor;
      final offset = refADC - refForAnchorKarat;
      baseExpected[tier] = anchorADC + offset * scaleFactor;
    }

    // Define minimum linear spacing between karats to prevent collapse
    // Only apply when natural spacing is too small (collapse condition)
    const minSpacing = 100.0; // Minimum ADC units between adjacent karats
    const collapseThreshold = 50.0; // If spacing < 50, it's considered collapsed

    // Check if we need to apply spacing fixes (prevent collapse condition)
    bool needsSpacingFix = false;
    for (int i = 0; i < karatTiers.length - 1; i++) {
      final currentTier = karatTiers[i];
      final nextTier = karatTiers[i + 1];
      final spacing = (baseExpected[currentTier]! - baseExpected[nextTier]!).abs();
      if (spacing < collapseThreshold) {
        needsSpacingFix = true;
        break;
      }
    }

    // Only adjust expected values if we detect collapse
    final adjustedExpected = <int, double>{};
    if (needsSpacingFix) {
      // Apply minimum spacing to prevent collapse
      for (int i = 0; i < karatTiers.length; i++) {
        final tier = karatTiers[i];
        final baseValue = baseExpected[tier]!;

        if (i == 0) {
          // First tier (24k) - use base value
          adjustedExpected[tier] = baseValue;
        } else {
          final prevTier = karatTiers[i - 1];
          final prevValue = adjustedExpected[prevTier]!;

          // Ensure this tier is at least minSpacing below the previous one
          final requiredMax = prevValue - minSpacing;
          adjustedExpected[tier] = baseValue < requiredMax ? baseValue : requiredMax;
        }
      }
    } else {
      // No collapse detected, use original values
      adjustedExpected.addAll(baseExpected);
    }

    // Build final ranges with adjusted expected values and reasonable tolerances
    final ranges = <KaratRange>[];
    for (final tier in karatTiers) {
      final expected = adjustedExpected[tier]!;

      // Use scaled tolerance normally, but apply adaptive tolerance only when collapse detected
      final baseTol = tolerance * scaleFactor;
      final finalTol = needsSpacingFix ? baseTol.clamp(30.0, 300.0) : baseTol;

      final min = expected - finalTol;
      final max = expected + finalTol;

      ranges.add(KaratRange(
        karat: tier,
        label: tier == 24 ? 'Pure Gold' : 'Gold',
        expectedADC: expected,
        min: min,
        max: max,
        color: colors[tier]!,
      ));
    }

    // Extend 24k gold range in the noble direction
    if (ranges.isNotEmpty && ranges.first.karat == 24) {
      final g24 = ranges.first;
      final extension = max(2000.0 * scaleFactor, 500.0);
      final extendedMax = (g24.max + extension).clamp(-10000.0, 14000.0);
      ranges[0] = KaratRange(
        karat: g24.karat,
        label: g24.label,
        expectedADC: g24.expectedADC,
        min: g24.min,
        max: extendedMax,
        color: g24.color,
      );
    }

    return ranges;
  }

  /// Compute metal ranges scaled from the calibrated gold reference ADC.
  ///
  /// Uses offset-based scaling from the 22k baseline at -1500 ADC.
  /// Lower-nobility metals always end up below (less noble than) the anchor,
  /// regardless of whether the anchor is positive or negative.
  static List<MetalRange> computeMetalRanges(double goldReferenceADC) {
    // Reference table based on 22k Gold at -1500 ADC.
    final references = [
      {
        'name': 'Gold 24k',
        'refADC': -1375.0,
        'tol': 60.0,
        'color': 0xFFFFD700,
        'density': 19.32,
        'desc': 'Pure gold (99.9%)'
      },
      {
        'name': 'Gold 22k',
        'refADC': -1500.0,
        'tol': 60.0,
        'color': 0xFFFFB300,
        'density': 17.8,
        'desc': '91.7% gold content'
      },
      {
        'name': 'Gold 18k',
        'refADC': -1800.0,
        'tol': 100.0,
        'color': 0xFFFFA000,
        'density': 15.6,
        'desc': '75.0% gold content'
      },
      {
        'name': 'Gold 14k',
        'refADC': -2300.0,
        'tol': 150.0,
        'color': 0xFFFF8F00,
        'density': 13.0,
        'desc': '58.3% gold content'
      },
      {
        'name': 'Gold 10k',
        'refADC': -3200.0,
        'tol': 200.0,
        'color': 0xFFFFE082,
        'density': 11.6,
        'desc': '41.7% gold content'
      },
      {
        'name': 'Gold 9k',
        'refADC': -3600.0,
        'tol': 200.0,
        'color': 0xFFFFF9C4,
        'density': 11.1,
        'desc': '37.5% gold content'
      },
      {
        'name': 'Silver',
        'refADC': -5000.0,
        'tol': 400.0,
        'color': 0xFFC0C0C0,
        'density': 10.5,
        'desc': 'High conductivity metal'
      },
      {
        'name': 'Copper',
        'refADC': -6500.0,
        'tol': 400.0,
        'color': 0xFFB87333,
        'density': 8.96,
        'desc': 'Excellent conductor'
      },
      {
        'name': 'Brass',
        'refADC': -7500.0,
        'tol': 400.0,
        'color': 0xFFC9AE5D,
        'density': 8.5,
        'desc': 'Copper-zinc alloy'
      },
      {
        'name': 'Bronze',
        'refADC': -8000.0,
        'tol': 300.0,
        'color': 0xFFCD7F32,
        'density': 8.8,
        'desc': 'Copper-tin alloy'
      },
      {
        'name': 'Steel',
        'refADC': -8500.0,
        'tol': 500.0,
        'color': 0xFF8C8C8C,
        'density': 7.85,
        'desc': 'Iron-carbon alloy'
      },
      {
        'name': 'Iron',
        'refADC': -10000.0,
        'tol': 500.0,
        'color': 0xFF555555,
        'density': 7.87,
        'desc': 'Ferrous metal'
      },
      {
        'name': 'Aluminium',
        'refADC': -12000.0,
        'tol': 600.0,
        'color': 0xFFA8A9AD,
        'density': 2.7,
        'desc': 'Lightweight metal'
      },
    ];

    const refAnchor = -1500.0; // 22k Gold reference
    final rawScale = (goldReferenceADC / refAnchor).abs();
    // Prevent extreme calibration values from blowing up spacing.
    final scaleFactor = rawScale.clamp(0.6, 2.0).toDouble();

    // Offset-based scaling:
    //   offset = refADC - refAnchor  (offset from 22k baseline)
    //   expected = goldReferenceADC + offset * scaleFactor
    //
    // This ensures crude metals are always LESS noble than gold,
    // regardless of whether goldReferenceADC is positive or negative.
    //
    // Example with +1500 anchor:
    //   Silver offset: -5000 - (-1500) = -3500
    //   Silver expected: +1500 + (-3500 * 1.0) = -2000  ✓ (below 22k)
    //   24k offset: -1375 - (-1500) = +125
    //   24k expected: +1500 + (+125 * 1.0) = +1625  ✓ (above 22k)
    final baseMetals = references.map((ref) {
      final refADC = ref['refADC'] as double;
      final offset = refADC - refAnchor;
      final expected = goldReferenceADC + offset * scaleFactor;
      final tol = (ref['tol'] as double) * scaleFactor;
      return MetalRange(
        metalName: ref['name'] as String,
        expectedADC: expected,
        min: expected - tol,
        max: expected + tol,
        color: Color(ref['color'] as int),
        description: ref['desc'] as String,
        densityGcm3: ref['density'] as double,
      );
    }).toList();

    // Check for collapse condition and apply minimum spacing if needed
    const minSpacing = 100.0; // Minimum ADC units between adjacent metals
    const collapseThreshold = 50.0; // If spacing < 50, it's considered collapsed

    // Sort by expected ADC for processing
    baseMetals.sort((a, b) => b.expectedADC.compareTo(a.expectedADC));

    // Check if we need to apply spacing fixes
    bool needsSpacingFix = false;
    for (int i = 0; i < baseMetals.length - 1; i++) {
      final spacing = (baseMetals[i].expectedADC - baseMetals[i + 1].expectedADC).abs();
      if (spacing < collapseThreshold) {
        needsSpacingFix = true;
        break;
      }
    }

    // Only adjust if we detect collapse
    List<MetalRange> processedMetals = baseMetals;
    if (needsSpacingFix) {
      final adjustedMetals = <MetalRange>[];
      for (int i = 0; i < baseMetals.length; i++) {
        final current = baseMetals[i];
        final currentTol = (current.max - current.min) / 2; // Get original scaled tolerance
        double adjustedExpected = current.expectedADC;

        if (i > 0) {
          final prevExpected = adjustedMetals[i - 1].expectedADC;
          final requiredMax = prevExpected - minSpacing;
          adjustedExpected = current.expectedADC < requiredMax ? current.expectedADC : requiredMax;
        }

        // Use the original scaled tolerance (not adaptive)
        adjustedMetals.add(MetalRange(
          metalName: current.metalName,
          expectedADC: adjustedExpected,
          min: adjustedExpected - currentTol,
          max: adjustedExpected + currentTol,
          color: current.color,
          description: current.description,
          densityGcm3: current.densityGcm3,
          isCustom: current.isCustom,
        ));
      }
      processedMetals = adjustedMetals;
    }

    // Normalize into a continuous, non-overlapping ladder
    return _normalizeContinuousMetalRanges(processedMetals);
  }

  /// Convert arbitrary per-metal spans into a continuous, non-overlapping ladder.
  ///
  /// Adjacent metals share a midpoint boundary so that every ADC belongs to one
  /// nearest band without gaps.
  ///
  /// Custom metals (isCustom=true) are preserved as-is and not normalized.
  static List<MetalRange> _normalizeContinuousMetalRanges(
    List<MetalRange> ranges,
  ) {
    if (ranges.isEmpty) return const <MetalRange>[];

    // Separate custom and built-in metals
    final customMetals = ranges.where((r) => r.isCustom).toList();
    final builtInMetals = ranges.where((r) => !r.isCustom).toList();

    if (builtInMetals.isEmpty) {
      // If only custom metals, return as-is
      return ranges;
    }

    // Sort built-in metals by expected ADC (highest/most noble first)
    final sorted = List<MetalRange>.from(builtInMetals)
      ..sort((a, b) => b.expectedADC.compareTo(a.expectedADC));
    final normalized = <MetalRange>[];

    for (int i = 0; i < sorted.length; i++) {
      final current = sorted[i];
      final currentHalfSpan = ((current.max - current.min).abs() / 2)
          .clamp(20.0, 5000.0)
          .toDouble();

      final upper = i == 0
          ? (current.expectedADC +
                  max(
                    currentHalfSpan,
                    sorted.length > 1
                        ? (sorted[0].expectedADC - sorted[1].expectedADC).abs() /
                            2
                        : currentHalfSpan,
                  ))
              .clamp(-10000.0, 14000.0)
              .toDouble()
          : ((sorted[i - 1].expectedADC + current.expectedADC) / 2)
              .toDouble();

      final lower = i == sorted.length - 1
          ? (current.expectedADC -
                  max(
                    currentHalfSpan,
                    sorted.length > 1
                        ? (sorted[sorted.length - 2].expectedADC -
                                    sorted.last.expectedADC)
                                .abs() /
                            2
                        : currentHalfSpan,
                  ))
              .clamp(-20000.0, 14000.0)
              .toDouble()
          : ((current.expectedADC + sorted[i + 1].expectedADC) / 2)
              .toDouble();

      normalized.add(
        MetalRange(
          metalName: current.metalName,
          expectedADC: current.expectedADC,
          min: min(lower, upper).toDouble(),
          max: max(lower, upper).toDouble(),
          color: current.color,
          description: current.description,
          densityGcm3: current.densityGcm3,
          isCustom: current.isCustom,
        ),
      );
    }

    // Combine normalized built-in metals with unchanged custom metals
    final combined = [...normalized, ...customMetals];

    // Sort all metals by expected ADC for consistent ordering
    combined.sort((a, b) => b.expectedADC.compareTo(a.expectedADC));

    return combined;
  }

  static double computeConfidence(int adcValue, MetalRange range) {
    final diff = (adcValue - range.expectedADC).abs();
    final halfSpan = (range.max - range.min) / 2;
    if (halfSpan <= 0) return 0;

    // For very tight ranges (≤ 100 ADC units), use a larger effective halfSpan
    // to avoid penalizing precise custom calibrations
    final effectiveHalfSpan = halfSpan <= 100.0 ? 200.0 : halfSpan;

    // Primary confidence based on how close we are to expected value
    final positionConfidence = max(0, 1 - (diff / effectiveHalfSpan));

    // Strong bonus for tight ranges - they represent precise measurements
    // Very tight (≤ 50): 0.50 bonus, Tight (≤ 100): 0.30 bonus, Normal: 0.15 bonus
    final inRangeBonus = (adcValue >= range.min && adcValue <= range.max)
        ? (halfSpan <= 50.0 ? 0.50 : halfSpan <= 100.0 ? 0.30 : 0.15)
        : 0.0;

    // Penalty for being far from the range (smooth falloff)
    final distancePenalty = (diff > halfSpan * 2) ? 0.2 : 0.0;

    final confidence = (positionConfidence + inRangeBonus - distancePenalty).clamp(0.0, 1.0) * 100;
    return confidence.toDouble();
  }

  /// Compute a robust ADC from raw test samples.
  ///
  /// 1. Discards probe-in-air spikes when contact samples exist (`adc <= airThreshold`).
  /// 2. Applies a symmetric trimmed mean to suppress transient outliers.
  /// 3. Falls back to all samples when every sample is above `airThreshold`.
  static int computeRobustADC(
    List<int> samples, {
    int airThreshold = 15000,
    double trimFraction = 0.15,
  }) {
    if (samples.isEmpty) return 0;

    final contactSamples =
        samples.where((adc) => adc <= airThreshold).toList(growable: false);
    final working = (contactSamples.isNotEmpty ? contactSamples : samples)
        .toList(growable: true)
      ..sort();

    final maxTrim = (working.length - 1) ~/ 2;
    final trimCount = working.length >= 5
        ? min((working.length * trimFraction).floor(), maxTrim)
        : 0;
    final trimmed = working.sublist(trimCount, working.length - trimCount);

    final sum = trimmed.fold<int>(0, (acc, value) => acc + value);
    return (sum / trimmed.length).round();
  }

  /// Identify metal from ADC value.
  /// Returns ranked matches with improved confidence calculation and better
  /// fallback for out-of-band readings.
  static List<MetalMatch> identifyMetal(
    int adcValue,
    List<MetalRange> ranges, {
    double confidenceThreshold = 0,
  }) {
    if (ranges.isEmpty) return const <MetalMatch>[];

    final inRangeScored = <_ScoredMetal>[];
    final outOfRangeScored = <_ScoredMetal>[];

    // Calculate dynamic proximity threshold based on range distribution
    final avgRange = ranges.isEmpty ? 500.0 :
        ranges.map((r) => (r.max - r.min).abs()).reduce((a, b) => a + b) / ranges.length;
    final proximityThreshold = avgRange * 3.0; // 3x average range for proximity

    for (final range in ranges) {
      final baseConfidence = computeConfidence(adcValue, range);
      final distance = (adcValue - range.expectedADC).abs().toDouble();
      final isInRange = adcValue >= range.min && adcValue <= range.max;

      // Improved proximity confidence that scales with range size
      final proximityConfidence = distance < proximityThreshold
          ? ((1 - (distance / proximityThreshold)).clamp(0.0, 1.0) * 25).toDouble()
          : 0.0;

      // Use the higher of base confidence or proximity, with a small boost for exact matches
      final exactMatchBonus = (distance < 10.0) ? 5.0 : 0.0;
      final effectiveConfidence = (max(baseConfidence, proximityConfidence) + exactMatchBonus)
          .clamp(0.0, 100.0);

      if (effectiveConfidence >= confidenceThreshold) {
        final score = _ScoredMetal(
          range: range,
          confidence: effectiveConfidence,
          distance: distance,
        );
        if (isInRange) {
          inRangeScored.add(score);
        } else {
          outOfRangeScored.add(score);
        }
      }
    }

    // If one or more metals contain the ADC, only rank those.
    final scored = inRangeScored.isNotEmpty ? inRangeScored : outOfRangeScored;

    // If all scores have 0 confidence (or list is empty), use fallback logic with minimum confidence
    if (scored.isEmpty || scored.every((s) => s.confidence == 0)) {
      final nearest = ranges.reduce((a, b) {
        final da = (adcValue - a.expectedADC).abs();
        final db = (adcValue - b.expectedADC).abs();
        return da <= db ? a : b;
      });

      final nearestDistance = (adcValue - nearest.expectedADC).abs().toDouble();

      // Improved nearest confidence calculation
      final nearestConfidence = nearestDistance < proximityThreshold
          ? ((1 - (nearestDistance / proximityThreshold)).clamp(0.0, 1.0) * 30)
              .clamp(3.0, 30.0)
          : 3.0; // Minimum confidence for very distant matches

      return <MetalMatch>[
        MetalMatch(
          metal: nearest,
          confidence: nearestConfidence,
          verdict: 'Nearest reference',
        ),
      ];
    }

    // Sort with improved ranking logic
    scored.sort((a, b) {
      final confidenceCmp = b.confidence.compareTo(a.confidence);
      if (confidenceCmp != 0) return confidenceCmp;
      final distanceCmp = a.distance.compareTo(b.distance);
      if (distanceCmp != 0) return distanceCmp;
      return a.range.metalName.compareTo(b.range.metalName);
    });

    return scored
        .map(
          (item) => MetalMatch(
            metal: item.range,
            confidence: item.confidence,
            verdict: _confidenceVerdict(item.confidence),
          ),
        )
        .toList();
  }

  static String _confidenceVerdict(double confidence) {
    if (confidence >= 95) return 'Excellent match';
    if (confidence >= 85) return 'Very strong match';
    if (confidence >= 70) return 'Strong match';
    if (confidence >= 55) return 'Likely match';
    if (confidence >= 40) return 'Possible match';
    if (confidence >= 25) return 'Weak match';
    if (confidence >= 10) return 'Very weak match';
    return 'Nearest reference only';
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

  /// Classify an ADC value into a karat tier.
  /// Returns the matching KaratRange, or null if the value doesn't
  /// fall into any gold tier (i.e. Not Gold).
  static KaratRange? classifyADC(int adcValue, List<KaratRange> ranges) {
    for (final range in ranges) {
      if (range.contains(adcValue)) {
        return range;
      }
    }
    return null;
  }

  static AdaptiveRangeProfile buildAdaptiveRangeProfile(
    StatisticalResult result,
  ) {
    final driftAllowance =
        result.slope.abs() * max(result.durationSeconds, 0.5) * 0.35;
    final noiseAllowance = result.residualStdDev * 1.1;
    final meanCorrection = (result.rawMean - result.adc0).abs() * 0.4;
    final instability = (1 - (result.confidence / 100)).clamp(0.0, 1.0);
    final stabilityMultiplier = 0.85 + instability * 0.55;
    final additivePadding =
        (driftAllowance + noiseAllowance + meanCorrection).clamp(12.0, 260.0);

    return AdaptiveRangeProfile(
      driftAllowance: driftAllowance,
      noiseAllowance: noiseAllowance,
      meanCorrection: meanCorrection,
      stabilityMultiplier: stabilityMultiplier,
      additivePadding: additivePadding,
    );
  }

  static List<KaratRange> computeAdaptiveKaratRanges(
    List<KaratRange> baseRanges,
    StatisticalResult result,
  ) {
    final profile = buildAdaptiveRangeProfile(result);
    return baseRanges.map((range) {
      final lowerSpan = (range.expectedADC - range.min).abs();
      final upperSpan = (range.max - range.expectedADC).abs();
      final dynamicLower =
          (lowerSpan * profile.stabilityMultiplier + profile.additivePadding)
              .clamp(20.0, 800.0);
      final dynamicUpper = (upperSpan *
                  (range.karat == 24
                      ? min(profile.stabilityMultiplier, 1.1)
                      : profile.stabilityMultiplier) +
              profile.additivePadding)
          .clamp(20.0, 2600.0);

      return KaratRange(
        karat: range.karat,
        label: range.label,
        expectedADC: range.expectedADC,
        min: range.expectedADC - dynamicLower,
        max: range.expectedADC + dynamicUpper,
        color: range.color,
      );
    }).toList();
  }

  static List<MetalRange> computeAdaptiveMetalRanges(
    List<MetalRange> baseRanges,
    StatisticalResult result,
  ) {
    final profile = buildAdaptiveRangeProfile(result);
    final adaptiveRaw = baseRanges.map((range) {
      final lowerSpan = (range.expectedADC - range.min).abs();
      final upperSpan = (range.max - range.expectedADC).abs();
      final dynamicLower =
          (lowerSpan * profile.stabilityMultiplier + profile.additivePadding)
              .clamp(40.0, 1400.0);
      final dynamicUpper =
          (upperSpan * profile.stabilityMultiplier + profile.additivePadding)
              .clamp(40.0, 1800.0);

      return MetalRange(
        metalName: range.metalName,
        expectedADC: range.expectedADC,
        min: range.expectedADC - dynamicLower,
        max: range.expectedADC + dynamicUpper,
        color: range.color,
        description: range.description,
        densityGcm3: range.densityGcm3,
        isCustom: range.isCustom,
      );
    }).toList();

    // Keep adaptive bands continuous as well.
    return _normalizeContinuousMetalRanges(adaptiveRaw);
  }
}

class _ScoredMetal {
  final MetalRange range;
  final double confidence;
  final double distance;

  const _ScoredMetal({
    required this.range,
    required this.confidence,
    required this.distance,
  });
}
