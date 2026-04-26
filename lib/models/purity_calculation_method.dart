enum PurityCalculationMethod {
  standardMean,
  detrendedSlope,
  adaptiveStatistical,
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
