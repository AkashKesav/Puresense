enum PurityCalculationMethod {
  standardMean,
  detrendedSlope,
  adaptiveStatistical,
  unifiedEnsemble, // ← NEW! Wavelet + Kalman + GMM + RF
}

extension PurityCalculationMethodX on PurityCalculationMethod {
  String get prefsValue {
    switch (this) {
      case PurityCalculationMethod.standardMean:
        return 'standardMean';
      case PurityCalculationMethod.detrendedSlope:
        return 'detrendedSlope';
      case PurityCalculationMethod.adaptiveStatistical:
        return 'adaptiveStatistical';
      case PurityCalculationMethod.unifiedEnsemble:
        return 'unifiedEnsemble';
    }
  }

  String get title {
    switch (this) {
      case PurityCalculationMethod.standardMean:
        return 'Standard Mean';
      case PurityCalculationMethod.detrendedSlope:
        return 'Slope De-trended';
      case PurityCalculationMethod.adaptiveStatistical:
        return 'Adaptive Statistical';
      case PurityCalculationMethod.unifiedEnsemble:
        return '⭐ Unified AI (Best)';
    }
  }

  String get shortLabel {
    switch (this) {
      case PurityCalculationMethod.standardMean:
        return 'Mean Mode';
      case PurityCalculationMethod.detrendedSlope:
        return 'Slope Mode';
      case PurityCalculationMethod.adaptiveStatistical:
        return 'Adaptive Mode';
      case PurityCalculationMethod.unifiedEnsemble:
        return '⭐ Unified AI';
    }
  }

  String get description {
    switch (this) {
      case PurityCalculationMethod.standardMean:
        return 'Uses the raw ADC mean against fixed calibrated ranges.';
      case PurityCalculationMethod.detrendedSlope:
        return 'Uses mean, slope, and variance to recover ADC0, then classifies with fixed ranges.';
      case PurityCalculationMethod.adaptiveStatistical:
        return 'Uses mean, slope, and variance to build dynamic per-test ranges and a drift-aware reading.';
      case PurityCalculationMethod.unifiedEnsemble:
        return 'Combines Wavelet denoising, Kalman filtering, and ML for maximum accuracy (95%+ expected).';
    }
  }

  Duration get sampleDuration {
    switch (this) {
      case PurityCalculationMethod.standardMean:
        return const Duration(seconds: 2);
      case PurityCalculationMethod.detrendedSlope:
        return const Duration(seconds: 1);
      case PurityCalculationMethod.adaptiveStatistical:
        return const Duration(milliseconds: 800);
      case PurityCalculationMethod.unifiedEnsemble:
        return const Duration(milliseconds: 800);
    }
  }

  bool get usesStatisticalAnalysis =>
      this != PurityCalculationMethod.standardMean;

  bool get usesAdaptiveRanges =>
      this == PurityCalculationMethod.adaptiveStatistical;

  static PurityCalculationMethod? fromPrefsValue(String? value) {
    for (final method in PurityCalculationMethod.values) {
      if (method.prefsValue == value) return method;
    }
    return null;
  }
}
