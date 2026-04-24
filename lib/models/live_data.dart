import 'package:flutter/material.dart';

enum PurityOutcome { gold, notGold, probeInAir, unknown }

class LiveData {
  final double weightGrams;
  final int adcValue;
  final DateTime timestamp;

  LiveData({
    required this.weightGrams,
    required this.adcValue,
    required this.timestamp,
  });
}

class KaratRange {
  final int karat;
  final String label;
  final double min;
  final double max;
  final Color color;

  KaratRange({
    required this.karat,
    required this.label,
    required this.min,
    required this.max,
    required this.color,
  });

  bool contains(int adcValue) => adcValue >= min && adcValue <= max;
}

class MetalRange {
  final String metalName;
  final double expectedADC;
  final double min;
  final double max;
  final Color color;
  final String description;
  final double? densityGcm3;
  final bool isCustom;

  MetalRange({
    required this.metalName,
    required this.expectedADC,
    required this.min,
    required this.max,
    required this.color,
    required this.description,
    this.densityGcm3,
    this.isCustom = false,
  });
}

class MetalMatch {
  final MetalRange metal;
  final double confidence;
  final String verdict;

  MetalMatch({
    required this.metal,
    required this.confidence,
    required this.verdict,
  });
}

class PurityResult {
  final PurityOutcome outcome;
  final int meanADC;
  final int? karat;
  final double? purityPercent;
  final int distributionGold;
  final int distributionLeft;
  final int distributionRight;
  final MetalMatch? detectedMetal;
  final List<MetalMatch> otherMatches;
  final DateTime timestamp;

  PurityResult({
    required this.outcome,
    required this.meanADC,
    this.karat,
    this.purityPercent,
    required this.distributionGold,
    required this.distributionLeft,
    required this.distributionRight,
    this.detectedMetal,
    required this.otherMatches,
    required this.timestamp,
  });

  String get historyLabel {
    switch (outcome) {
      case PurityOutcome.gold:
        return 'Purity Test — ${karat}k Gold (${purityPercent?.toStringAsFixed(1)}%)';
      case PurityOutcome.notGold:
        if (detectedMetal != null) {
          return 'Purity Test — ${detectedMetal!.metal.metalName} (${detectedMetal!.confidence.toStringAsFixed(0)}%)';
        }
        return 'Purity Test — Not Gold';
      case PurityOutcome.probeInAir:
        return 'Purity Test — Probe in Air';
      case PurityOutcome.unknown:
        return 'Purity Test — Unknown Metal';
    }
  }
}

class DensityResult {
  final double density;
  final String metalLabel;
  final double wAir;
  final double wWater;
  final double wSubmerged;
  final double buoyancy;
  final DateTime timestamp;

  DensityResult({
    required this.density,
    required this.metalLabel,
    required this.wAir,
    required this.wWater,
    required this.wSubmerged,
    required this.buoyancy,
    required this.timestamp,
  });

  String get historyLabel => 'Density Test — $metalLabel ${density.toStringAsFixed(2)} g/cm³';
}

class FullAnalysisResult {
  final DensityResult density;
  final PurityResult purity;
  final String verdict;
  final DateTime timestamp;

  FullAnalysisResult({
    required this.density,
    required this.purity,
    required this.verdict,
    required this.timestamp,
  });

  String get historyLabel => 'Full Analysis — ${purity.karat}k Gold';
}

class MetalIdentificationResult {
  final int meanADC;
  final List<MetalMatch> matches;
  final DateTime timestamp;

  MetalIdentificationResult({
    required this.meanADC,
    required this.matches,
    required this.timestamp,
  });

  String get historyLabel {
    if (matches.isEmpty) return 'Metal ID — Unknown';
    final best = matches.first;
    return 'Metal ID — ${best.metal.metalName} (${best.confidence.toStringAsFixed(0)}%)';
  }
}

class HistoryEntry {
  final String id;
  final String type;
  final String label;
  final dynamic result;
  final DateTime timestamp;

  HistoryEntry({
    required this.id,
    required this.type,
    required this.label,
    required this.result,
    required this.timestamp,
  });
}
