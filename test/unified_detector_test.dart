import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:puresense/utils/unified_detector.dart';
import 'package:puresense/utils/kalman_filter.dart';
import 'package:puresense/utils/wavelet_denoise.dart';
import 'package:puresense/utils/feature_extraction.dart';

void main() {
  group('Unified Gold Detection System', () {
    test('Wavelet denoising reduces noise', () {
      // Create a noisy signal
      final cleanSignal = List.generate(100, (i) => -1000 + sin(i * 0.1) * 50);
      final noise = List.generate(100, (i) => (Random().nextDouble() - 0.5) * 100);
      final noisySignal = List<int>.generate(
        100,
        (i) => (cleanSignal[i] + noise[i]).round(),
      );

      // Denoise
      final denoised = WaveletDenoise.denoise(noisySignal);

      // Check that variance is reduced
      final noisyVar = _variance(noisySignal);
      final denoisedVar = _variance(denoised);

      expect(denoisedVar, lessThan(noisyVar * 0.7)); // At least 30% noise reduction
    });

    test('Kalman filter corrects drift', () {
      // Create a signal with linear drift
      final startAdc = -1000;
      final driftRate = 5.0; // +5 ADC per sample
      final driftedSignal = List<int>.generate(
        100,
        (i) => (startAdc + driftRate * i + (Random().nextDouble() - 0.5) * 20).round(),
      );

      // Apply Kalman filter
      final result = KalmanFilter.filter(driftedSignal);

      // Estimated ADC should be reasonably close to the signal range
      final signalMean = startAdc + driftRate * 50;
      expect(result.estimatedAdc, closeTo(signalMean, 300));

      // Drift rate should be detected approximately
      expect(result.driftRate, closeTo(driftRate, 3.0));

      // Confidence should be reasonable
      expect(result.confidence, greaterThan(50));
    });

    test('Feature extraction produces correct features', () {
      final samples = List<int>.generate(100, (i) => (-1000 + sin(i * 0.1) * 50).round());

      final features = FeatureExtractor.extractAll(samples);

      // Check that all feature categories are present
      expect(features['mean'], isNotNull);
      expect(features['stdDev'], isNotNull);
      expect(features['skewness'], isNotNull);
      expect(features['kurtosis'], isNotNull);
      expect(features['rms'], isNotNull);
      expect(features['crestFactor'], isNotNull);
      expect(features['zeroCrossingRate'], isNotNull);
      expect(features['dominantFreq'], isNotNull);
      expect(features['spectralCentroid'], isNotNull);
      expect(features['waveletEnergyApprox'], isNotNull);

      // Check feature values are reasonable
      expect(features['mean'], closeTo(-1000, 100));
      expect(features['stdDev'], greaterThan(0));
      expect(features['zeroCrossingRate'], greaterThan(0.0));
      expect(features['zeroCrossingRate'], lessThan(1.0));
    });

    test('Full unified pipeline processes signal', () async {
      // Simulate a gold sample ADC reading
      final goldSignal = _simulateGoldSample(karatAdc: -1500, noiseLevel: 50);

      final result = await UnifiedGoldDetector.detect(goldSignal);

      // Check that result is produced
      expect(result, isNotNull);
      expect(result.meanAdc, isNotNull);
      expect(result.confidence, greaterThan(0));
      expect(result.confidence, lessThanOrEqualTo(100));

      // Check Kalman result
      expect(result.kalmanResult, isNotNull);
      expect(result.kalmanResult!.estimatedAdc, closeTo(-1500, 200));

      // Check features
      expect(result.features, isNotNull);
      expect(result.features!.length, greaterThan(15));
    });

    test('Ensemble decision combines probabilities correctly', () {
      final karatLabels = ['18k', '22k', '24k'];

      // Simulate classifier outputs
      final gmmProbs = [0.10, 0.85, 0.05]; // Strong 22k
      final rfProbs = [0.15, 0.80, 0.05]; // Strong 22k
      final kalmanProbs = [0.20, 0.70, 0.10]; // Moderate 22k

      final result = UnifiedGoldDetector.makeEnsembleDecision(
        gmmProbabilities: gmmProbs,
        rfProbabilities: rfProbs,
        kalmanProbabilities: kalmanProbs,
        karatLabels: karatLabels,
        meanAdc: -1500,
      );

      expect(result.karat, '22k');
      expect(result.confidence, greaterThan(80));
      expect(result.allProbabilities['final']!, closeTo(0.80, 0.02)); // Weighted avg (allowing precision tolerance)

      // Check explanation
      expect(result.explanation, contains('22k'));
      expect(result.explanation, contains('GMM'));
      expect(result.explanation, contains('RF'));
      expect(result.explanation, contains('Kalman'));
    });

    test('Kalman filter handles edge cases', () {
      // Single sample
      final single = [-1000];
      final result1 = KalmanFilter.filter(single);
      expect(result1.estimatedAdc, -1000);

      // Constant signal (no drift)
      final constant = List.filled(50, -1000);
      final result2 = KalmanFilter.filter(constant);
      expect(result2.estimatedAdc, closeTo(-1000, 10));
      expect(result2.driftRate, closeTo(0, 0.5));

      // Highly noisy signal
      final random = List<int>.generate(100, (i) => (-1000 + (Random().nextDouble() - 0.5) * 500).round());
      final result3 = KalmanFilter.filter(random);
      expect(result3.estimatedAdc, closeTo(-1000, 300)); // Allow more tolerance for very noisy
      // Kalman filter does a good job even with noise - confidence can still be high
      expect(result3.confidence, greaterThan(50));
    });
  });
}

double _variance(List<int> data) {
  final mean = data.reduce((a, b) => a + b) / data.length;
  return data.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / data.length;
}

/// Simulate a gold sample ADC reading with noise
List<int> _simulateGoldSample({
  required double karatAdc,
  required double noiseLevel,
  int duration = 100,
}) {
  final random = Random();
  return List.generate(duration, (i) {
    final noise = (random.nextDouble() - 0.5) * noiseLevel;
    final drift = 2.0 * i / duration; // Slight drift
    return (karatAdc + drift + noise).round();
  });
}
