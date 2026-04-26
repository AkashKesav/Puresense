import 'package:flutter_test/flutter_test.dart';
import 'package:puresense/utils/statistical_classifier.dart';

// Helper: create samples with linear drift + optional noise
List<TimedSample> makeSamples({
  required double startADC,
  required double slope, // ADC per second
  int count = 5,
  Duration interval = const Duration(milliseconds: 500),
  List<double> noise = const [],
}) {
  final t0 = DateTime(2026, 1, 1);
  return List.generate(count, (i) {
    final t = t0.add(interval * i);
    final n = i < noise.length ? noise[i] : 0.0;
    return TimedSample(
        timestamp: t,
        adc: (startADC + slope * (i * interval.inMilliseconds / 1000.0) + n)
            .round());
  });
}

void main() {
  // ═══════════════════════════════════════════════════════════════════
  // 1. BASIC REGRESSION — perfect linear signal, zero noise
  // ═══════════════════════════════════════════════════════════════════
  group('Perfect linear signal (zero noise)', () {
    test('Flat signal → slope ≈ 0, ADC₀ = constant', () {
      final samples = makeSamples(startADC: -1500, slope: 0, count: 5);
      final r = StatisticalClassifier.analyze(samples);

      print(
          '  Flat: ADC₀=${r.adc0.toStringAsFixed(1)}, slope=${r.slope.toStringAsFixed(2)}, σ=${r.residualStdDev.toStringAsFixed(2)}');

      expect(r.adc0, closeTo(-1500, 1));
      expect(r.slope, closeTo(0, 1));
      expect(r.residualVariance, closeTo(0, 1));
      expect(r.rSquared, closeTo(1.0, 0.01));
      expect(r.sampleCount, 5);
    });

    test('Positive drift → ADC₀ extrapolates back to start', () {
      // Start at -1500, drift +200 ADC/sec for 2 seconds
      final samples = makeSamples(startADC: -1500, slope: 200, count: 5);
      final r = StatisticalClassifier.analyze(samples);

      print(
          '  Drift +200/s: ADC₀=${r.adc0.toStringAsFixed(1)}, slope=${r.slope.toStringAsFixed(1)}, mean=${r.rawMean.toStringAsFixed(1)}');

      expect(r.adc0, closeTo(-1500, 2),
          reason: 'ADC₀ should match initial value');
      expect(r.slope, closeTo(200, 2), reason: 'Slope should be ~200 ADC/sec');
      expect(r.rawMean, greaterThan(-1500), reason: 'Raw mean biased by drift');
      expect(r.residualVariance, closeTo(0, 1));
    });

    test('Negative drift → ADC₀ extrapolates back to start', () {
      final samples = makeSamples(startADC: -1500, slope: -300, count: 5);
      final r = StatisticalClassifier.analyze(samples);

      print(
          '  Drift -300/s: ADC₀=${r.adc0.toStringAsFixed(1)}, slope=${r.slope.toStringAsFixed(1)}');

      expect(r.adc0, closeTo(-1500, 2));
      expect(r.slope, closeTo(-300, 2));
    });

    test('ADC₀ is more accurate than raw mean under drift', () {
      // Heavy drift: -1500 start, +400/sec, 2 seconds → mean ≈ -1100
      final samples = makeSamples(startADC: -1500, slope: 400, count: 5);
      final r = StatisticalClassifier.analyze(samples);

      final meanError = (r.rawMean - (-1500)).abs();
      final adc0Error = (r.adc0 - (-1500)).abs();

      print(
          '  Mean error: ${meanError.toStringAsFixed(0)}, ADC₀ error: ${adc0Error.toStringAsFixed(0)}');

      expect(adc0Error, lessThan(meanError),
          reason:
              'De-trended ADC₀ should be closer to true value than drift-biased mean');
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 2. NOISY SIGNAL — regression with noise
  // ═══════════════════════════════════════════════════════════════════
  group('Noisy signal', () {
    test('Noise increases residual variance, R² decreases', () {
      final clean = makeSamples(startADC: -1500, slope: 100, count: 5);
      final noisy = makeSamples(
        startADC: -1500,
        slope: 100,
        count: 5,
        noise: [0, 50, -80, 30, -60],
      );

      final rClean = StatisticalClassifier.analyze(clean);
      final rNoisy = StatisticalClassifier.analyze(noisy);

      print(
          '  Clean: σ=${rClean.residualStdDev.toStringAsFixed(1)}, R²=${rClean.rSquared.toStringAsFixed(3)}');
      print(
          '  Noisy: σ=${rNoisy.residualStdDev.toStringAsFixed(1)}, R²=${rNoisy.rSquared.toStringAsFixed(3)}');

      expect(rNoisy.residualVariance, greaterThan(rClean.residualVariance));
      expect(rNoisy.confidence, lessThan(rClean.confidence));
    });

    test('ADC₀ still reasonable despite moderate noise', () {
      final samples = makeSamples(
        startADC: -1500,
        slope: 0,
        count: 5,
        noise: [10, -20, 15, -10, 5],
      );
      final r = StatisticalClassifier.analyze(samples);

      print('  Noisy flat: ADC₀=${r.adc0.toStringAsFixed(1)}');

      expect(r.adc0, closeTo(-1500, 30),
          reason: 'ADC₀ should be close to true value');
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 3. EDGE CASES
  // ═══════════════════════════════════════════════════════════════════
  group('Edge cases', () {
    test('Empty samples → zeroed result', () {
      final r = StatisticalClassifier.analyze([]);
      expect(r.sampleCount, 0);
      expect(r.adc0, 0);
      expect(r.confidence, 0);
    });

    test('Single sample → uses raw value, moderate confidence', () {
      final r = StatisticalClassifier.analyze([
        TimedSample(timestamp: DateTime.now(), adc: -1500),
      ]);
      expect(r.adc0, -1500);
      expect(r.slope, 0);
      expect(r.confidence, 50);
      expect(r.sampleCount, 1);
    });

    test('Two samples → computes exact line', () {
      final t0 = DateTime(2026, 1, 1);
      final samples = [
        TimedSample(timestamp: t0, adc: -1500),
        TimedSample(timestamp: t0.add(const Duration(seconds: 1)), adc: -1400),
      ];
      final r = StatisticalClassifier.analyze(samples);

      print(
          '  2 samples: ADC₀=${r.adc0.toStringAsFixed(1)}, slope=${r.slope.toStringAsFixed(1)}');

      expect(r.adc0, closeTo(-1500, 1));
      expect(r.slope, closeTo(100, 1));
    });

    test('Large ADC values (probe in air ~20000)', () {
      final samples = makeSamples(startADC: 20000, slope: 10, count: 4);
      final r = StatisticalClassifier.analyze(samples);
      expect(r.adcInt, greaterThan(15000));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 4. CLASSIFICATION IMPROVEMENT — drift scenario
  // ═══════════════════════════════════════════════════════════════════
  group('Classification improvement under drift', () {
    test('Drifting 22k signal: mean misclassifies, ADC₀ correct', () {
      // 22k gold at -1500, but drifting heavily to -1800 over 2s
      // Mean ≈ -1650 → might classify as 18k (center -1800, range ±50)
      // ADC₀ ≈ -1500 → correctly classifies as 22k
      final samples = makeSamples(startADC: -1500, slope: -150, count: 5);
      final r = StatisticalClassifier.analyze(samples);

      print(
          '  22k drifting: raw mean=${r.rawMean.toStringAsFixed(0)}, ADC₀=${r.adc0.toStringAsFixed(0)}');

      // ADC₀ should be in 22k range [-1550, -1450]
      expect(r.adcInt, greaterThanOrEqualTo(-1550));
      expect(r.adcInt, lessThanOrEqualTo(-1450));

      // Raw mean drifted away from 22k range
      expect(r.rawMean, lessThan(-1550),
          reason: 'Raw mean should have drifted below 22k range');
    });

    test('Faster sampling → better regression with same duration', () {
      final slow = makeSamples(
        startADC: -1500,
        slope: -200,
        count: 3,
        interval: const Duration(milliseconds: 500),
        noise: [10, -15, 20],
      );
      final fast = makeSamples(
        startADC: -1500,
        slope: -200,
        count: 6,
        interval: const Duration(milliseconds: 250),
        noise: [10, -15, 20, -5, 8, -12],
      );

      final rSlow = StatisticalClassifier.analyze(slow);
      final rFast = StatisticalClassifier.analyze(fast);

      print(
          '  Slow (3 samples): ADC₀=${rSlow.adc0.toStringAsFixed(0)}, conf=${rSlow.confidence.toStringAsFixed(0)}%');
      print(
          '  Fast (6 samples): ADC₀=${rFast.adc0.toStringAsFixed(0)}, conf=${rFast.confidence.toStringAsFixed(0)}%');

      // Both should get close to -1500
      expect(rSlow.adc0, closeTo(-1500, 40));
      expect(rFast.adc0, closeTo(-1500, 40));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 5. CONFIDENCE SCORING
  // ═══════════════════════════════════════════════════════════════════
  group('Confidence scoring', () {
    test('Clean signal → high confidence', () {
      final r = StatisticalClassifier.analyze(
        makeSamples(startADC: -1500, slope: -100, count: 5),
      );
      expect(r.confidence, greaterThan(90));
    });

    test('Very noisy signal → lower confidence', () {
      final r = StatisticalClassifier.analyze(
        makeSamples(
            startADC: -1500,
            slope: -100,
            count: 5,
            noise: [200, -300, 250, -400, 350]),
      );
      print('  Noisy confidence: ${r.confidence.toStringAsFixed(0)}%');
      expect(r.confidence, lessThan(80));
    });

    test('Fewer samples → lower confidence (sample factor)', () {
      final few = StatisticalClassifier.analyze(
        makeSamples(startADC: -1500, slope: 0, count: 2),
      );
      final many = StatisticalClassifier.analyze(
        makeSamples(startADC: -1500, slope: 0, count: 6),
      );
      print('  2 samples: conf=${few.confidence.toStringAsFixed(0)}%');
      print('  6 samples: conf=${many.confidence.toStringAsFixed(0)}%');
      expect(many.confidence, greaterThanOrEqualTo(few.confidence));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 6. adcInt GETTER
  // ═══════════════════════════════════════════════════════════════════
  group('adcInt rounding', () {
    test('Rounds to nearest integer', () {
      final samples = makeSamples(startADC: -1500, slope: 1, count: 5);
      final r = StatisticalClassifier.analyze(samples);
      expect(r.adcInt, isA<int>());
      expect((r.adcInt - r.adc0).abs(), lessThanOrEqualTo(1));
    });
  });

  group('Adaptive ADC blending', () {
    test('High confidence leans toward ADC0', () {
      final result = StatisticalResult(
        adc0: -1500,
        slope: -90,
        rawMean: -1620,
        residualVariance: 4,
        residualStdDev: 2,
        confidence: 95,
        sampleCount: 6,
        durationSeconds: 0.8,
        rSquared: 0.98,
      );

      final adaptive = StatisticalClassifier.computeAdaptiveADC(result);
      final errToAdc0 = (adaptive - result.adc0).abs();
      final errToMean = (adaptive - result.rawMean).abs();
      expect(errToAdc0, lessThan(errToMean));
    });

    test('Lower confidence keeps more raw mean influence', () {
      final lowConfidence = StatisticalResult(
        adc0: -1500,
        slope: -60,
        rawMean: -1660,
        residualVariance: 10000,
        residualStdDev: 100,
        confidence: 20,
        sampleCount: 4,
        durationSeconds: 0.8,
        rSquared: 0.45,
      );
      final highConfidence = StatisticalResult(
        adc0: -1500,
        slope: -60,
        rawMean: -1660,
        residualVariance: 20,
        residualStdDev: 4.5,
        confidence: 90,
        sampleCount: 4,
        durationSeconds: 0.8,
        rSquared: 0.95,
      );

      final lowAdaptive =
          StatisticalClassifier.computeAdaptiveADC(lowConfidence);
      final highAdaptive =
          StatisticalClassifier.computeAdaptiveADC(highConfidence);

      final lowDistanceToMean = (lowAdaptive - lowConfidence.rawMean).abs();
      final highDistanceToMean = (highAdaptive - highConfidence.rawMean).abs();
      expect(lowDistanceToMean, lessThan(highDistanceToMean));
    });
  });
}
