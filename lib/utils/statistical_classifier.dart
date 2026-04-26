import 'dart:math';

/// Result of a statistical (slope-based) ADC analysis.
class StatisticalResult {
  /// De-trended ADC value at t=0 (probe contact moment).
  /// This is the y-intercept of the linear regression — the "true"
  /// electrochemical reading before drift corrupts it.
  final double adc0;

  /// Drift rate in ADC units per second. Positive = drifting up, negative = down.
  final double slope;

  /// Mean of raw ADC samples (for comparison with standard method).
  final double rawMean;

  /// Residual variance: spread of samples around the regression line.
  /// Low variance = stable, clean signal. High = noisy.
  final double residualVariance;

  /// Standard deviation of residuals (sqrt of variance).
  final double residualStdDev;

  /// Statistical confidence (0–100), derived from residual variance.
  /// Tighter fit to the regression = higher confidence.
  final double confidence;

  /// Number of samples used in the analysis.
  final int sampleCount;

  /// Duration of the sampling window in seconds.
  final double durationSeconds;

  /// R² (coefficient of determination) of the linear fit.
  final double rSquared;

  const StatisticalResult({
    required this.adc0,
    required this.slope,
    required this.rawMean,
    required this.residualVariance,
    required this.residualStdDev,
    required this.confidence,
    required this.sampleCount,
    required this.durationSeconds,
    required this.rSquared,
  });

  /// The de-trended ADC as an integer for range classification.
  int get adcInt => adc0.round();
}

/// Statistical engine for slope-based ADC classification.
///
/// Uses linear regression on timestamped ADC samples to:
/// 1. Compute ADC₀ (y-intercept) — the de-trended "true" reading
/// 2. Compute slope — drift rate, usable as a secondary discriminator
/// 3. Compute residual variance — signal quality / confidence
class StatisticalClassifier {
  /// Analyze a list of timestamped ADC samples.
  ///
  /// [samples] — list of (timestamp, adcValue) pairs, in chronological order.
  /// [varianceThreshold] — the residual variance that maps to 0% confidence.
  ///   Default 50000 works well for ADS1115 16-bit readings.
  ///
  /// Returns a [StatisticalResult] with de-trended ADC₀, slope, variance,
  /// and a confidence score.
  static StatisticalResult analyze(
    List<TimedSample> samples, {
    double varianceThreshold = 50000.0,
  }) {
    if (samples.isEmpty) {
      return const StatisticalResult(
        adc0: 0,
        slope: 0,
        rawMean: 0,
        residualVariance: 0,
        residualStdDev: 0,
        confidence: 0,
        sampleCount: 0,
        durationSeconds: 0,
        rSquared: 0,
      );
    }

    if (samples.length == 1) {
      return StatisticalResult(
        adc0: samples.first.adc.toDouble(),
        slope: 0,
        rawMean: samples.first.adc.toDouble(),
        residualVariance: 0,
        residualStdDev: 0,
        confidence: 50, // Single sample — moderate confidence
        sampleCount: 1,
        durationSeconds: 0,
        rSquared: 1,
      );
    }

    // Convert timestamps to seconds relative to first sample
    final t0 = samples.first.timestamp;
    final tValues = samples
        .map((s) => s.timestamp.difference(t0).inMicroseconds / 1e6)
        .toList();
    final adcValues = samples.map((s) => s.adc.toDouble()).toList();

    final n = samples.length;
    final duration = tValues.last;

    // ─── Linear regression: adc(t) = adc0 + slope × t ───
    // Using least squares:
    //   slope = (n·Σ(t·adc) − Σt·Σadc) / (n·Σ(t²) − (Σt)²)
    //   adc0  = (Σadc − slope·Σt) / n

    double sumT = 0, sumADC = 0, sumTT = 0, sumTADC = 0;
    for (int i = 0; i < n; i++) {
      sumT += tValues[i];
      sumADC += adcValues[i];
      sumTT += tValues[i] * tValues[i];
      sumTADC += tValues[i] * adcValues[i];
    }

    final denominator = n * sumTT - sumT * sumT;
    double slopeVal, adc0Val;

    if (denominator.abs() < 1e-10) {
      // All timestamps are identical — degenerate case (shouldn't happen)
      slopeVal = 0;
      adc0Val = sumADC / n;
    } else {
      slopeVal = (n * sumTADC - sumT * sumADC) / denominator;
      adc0Val = (sumADC - slopeVal * sumT) / n;
    }

    final rawMean = sumADC / n;

    // ─── Residual variance (from regression line, not from mean) ───
    double ssResidual = 0; // Sum of squared residuals
    double ssTotal = 0; // Total sum of squares (from mean)
    for (int i = 0; i < n; i++) {
      final predicted = adc0Val + slopeVal * tValues[i];
      final residual = adcValues[i] - predicted;
      ssResidual += residual * residual;
      final devFromMean = adcValues[i] - rawMean;
      ssTotal += devFromMean * devFromMean;
    }

    // Degrees of freedom: n - 2 for linear regression
    final dof = max(1, n - 2);
    final residualVar = ssResidual / dof;
    final residualStd = sqrt(residualVar);

    // R² (coefficient of determination)
    final rSquared = ssTotal > 0 ? 1 - (ssResidual / ssTotal) : 1.0;

    // ─── Confidence score ───
    // Based on residual standard deviation relative to threshold.
    // Low residual std → high confidence (tight fit to regression).
    // Also factor in sample count — more samples = more reliable.
    final sampleFactor = min(1.0, n / 4.0); // Full credit at ≥4 samples
    final variancePenalty =
        (residualStd / sqrt(varianceThreshold)).clamp(0.0, 1.0);
    final conf =
        ((1.0 - variancePenalty) * 100.0 * sampleFactor).clamp(0.0, 100.0);

    return StatisticalResult(
      adc0: adc0Val,
      slope: slopeVal,
      rawMean: rawMean,
      residualVariance: residualVar,
      residualStdDev: residualStd,
      confidence: conf,
      sampleCount: n,
      durationSeconds: duration,
      rSquared: rSquared.clamp(0.0, 1.0),
    );
  }

  /// Builds a drift-aware classification ADC from both the de-trended ADC0
  /// and the raw mean. Stable signals trust ADC0 more; noisier signals keep
  /// more of the mean to avoid overcorrecting a weak fit.
  static int computeAdaptiveADC(StatisticalResult result) {
    final adc0Weight =
        (0.55 + (result.confidence / 100) * 0.35).clamp(0.55, 0.9);
    final meanWeight = 1.0 - adc0Weight;
    final blended = result.adc0 * adc0Weight + result.rawMean * meanWeight;
    return blended.round();
  }
}

/// A single ADC sample with its collection timestamp.
class TimedSample {
  final DateTime timestamp;
  final int adc;

  const TimedSample({required this.timestamp, required this.adc});
}
