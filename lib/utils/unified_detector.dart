import 'dart:math';
import 'package:flutter/material.dart';
import 'kalman_filter.dart';
import 'wavelet_denoise.dart';
import 'feature_extraction.dart';
import '../models/live_data.dart';
import 'electrochemical_range_predictor.dart';

/// Unified Gold Detection System - Ensemble Pipeline
///
/// Combines Wavelet Denoising + Kalman Filter + GMM + Random Forest
/// for state-of-the-art gold purity classification
class UnifiedGoldDetector {
  /// Main detection pipeline - processes raw ADC samples and returns classification
  static Future<UnifiedResult> detect(
    List<int> rawSamples, {
    int samplingRateHz = 100,
  }) async {
    // Stage 1: Wavelet Denoising
    final denoisedSamples = WaveletDenoise.denoise(rawSamples);

    // Stage 2: Kalman Filter (drift correction)
    final kalmanResult = KalmanFilter.filter(denoisedSamples);

    // Stage 3: Feature Extraction
    final features = FeatureExtractor.extractAll(
      denoisedSamples,
      kalmanResult: kalmanResult,
    );

    // Stage 4: Ensemble Classification
    // For now, use Kalman direct (we'll add GMM and RF after training)
    final result = _classifyWithKalmanDirect(kalmanResult, features);

    return result;
  }

  /// Rule-based classification using electrochemically predicted ranges
  /// (No ML training required - uses standard reduction potentials)
  static UnifiedResult _classifyWithKalmanDirect(
    KalmanResult kalmanResult,
    Map<String, double> features,
  ) {
    final adc = kalmanResult.estimatedAdc;

    // Get predicted ranges for all common metals
    final predictedRanges = ElectrochemicalRangePredictor.getAllPredictedRanges();

    // Find matching material
    String detectedMaterial = 'Unknown';
    double confidence = 0.0;
    String? explanation;
    MetalRange? matchedRange;

    for (final range in predictedRanges) {
      if (adc >= range.min && adc <= range.max) {
        detectedMaterial = range.metalName;
        matchedRange = range;

        // Calculate confidence based on distance from boundaries
        // Center of range = highest confidence, edges = lower confidence
        final center = range.expectedADC;
        final halfWidth = (range.max - range.min) / 2;
        final distanceFromCenter = (adc - center).abs();
        final normalizedDistance = distanceFromCenter / halfWidth;

        // Confidence: 100% at center, 60% at edges
        confidence = 100.0 - (normalizedDistance * 40.0);
        confidence = confidence.clamp(60.0, 100.0);

        explanation = '${range.metalName}: $adc ADC (predicted range: ${range.min.toInt()} to ${range.max.toInt()})';
        break;
      }
    }

    // If no match, find closest material
    if (detectedMaterial == 'Unknown') {
      double minDistance = double.infinity;
      String closestMaterial = 'Unknown';

      for (final range in predictedRanges) {
        final center = range.expectedADC;
        final distance = (adc - center).abs();

        if (distance < minDistance) {
          minDistance = distance;
          closestMaterial = range.metalName;
          matchedRange = range;
        }
      }

      // Low confidence for out-of-range readings
      confidence = 50.0;
      explanation = 'Closest to $closestMaterial: $adc ADC (out of predicted range)';
      detectedMaterial = closestMaterial;
    }

    return UnifiedResult(
      karat: detectedMaterial,
      confidence: confidence,
      meanAdc: adc,
      allProbabilities: {
        'electrochemical_match': confidence / 100,
      },
      explanation: explanation ?? 'No match found',
      kalmanResult: kalmanResult,
      features: features,
    );
  }

  /// Compute weighted ensemble decision (to be used with trained models)
  static UnifiedResult makeEnsembleDecision({
    required List<double> gmmProbabilities,
    required List<double> rfProbabilities,
    required List<double> kalmanProbabilities,
    required List<String> karatLabels,
    required int meanAdc,
  }) {
    // Weighted voting: GMM 40%, RF 40%, Kalman 20%
    final finalScores = List.generate(karatLabels.length, (i) {
      return 0.40 * gmmProbabilities[i] +
             0.40 * rfProbabilities[i] +
             0.20 * kalmanProbabilities[i];
    });

    // Find winner
    final maxScore = finalScores.reduce((a, b) => a > b ? a : b);
    final winnerIndex = finalScores.indexOf(maxScore);
    final winnerKarat = karatLabels[winnerIndex];

    // Calculate confidence
    final confidence = _calculateConfidence(maxScore);

    // Generate explanation
    final explanation = _generateExplanation(
      karatLabels,
      gmmProbabilities,
      rfProbabilities,
      kalmanProbabilities,
      finalScores,
      winnerIndex,
    );

    return UnifiedResult(
      karat: winnerKarat,
      confidence: confidence,
      meanAdc: meanAdc,
      allProbabilities: {
        'gmm': gmmProbabilities[winnerIndex],
        'rf': rfProbabilities[winnerIndex],
        'kalman': kalmanProbabilities[winnerIndex],
        'final': maxScore,
      },
      explanation: explanation,
    );
  }

  static double _calculateConfidence(double maxScore) {
    if (maxScore > 0.70) {
      return 95 + (maxScore - 0.70) * 100; // 95-100%
    } else if (maxScore > 0.50) {
      return 80 + (maxScore - 0.50) * 75; // 80-95%
    } else {
      return 50 + maxScore * 60; // 50-80%
    }
  }

  static String _generateExplanation(
    List<String> labels,
    List<double> gmm,
    List<double> rf,
    List<double> kalman,
    List<double> finalScores,
    int winnerIndex,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('Ensemble Decision:');
    buffer.writeln('  GMM: ${labels[winnerIndex]} (${(gmm[winnerIndex] * 100).toStringAsFixed(1)}%)');
    buffer.writeln('  RF: ${labels[winnerIndex]} (${(rf[winnerIndex] * 100).toStringAsFixed(1)}%)');
    buffer.writeln('  Kalman: ${labels[winnerIndex]} (${(kalman[winnerIndex] * 100).toStringAsFixed(1)}%)');
    buffer.writeln('  Final: ${(finalScores[winnerIndex] * 100).toStringAsFixed(1)}%');
    return buffer.toString().trim();
  }
}

/// Result from the unified detection system
class UnifiedResult {
  final String karat; // e.g., "22k" or "Not Gold"
  final double confidence; // 0-100
  final int meanAdc; // Final ADC value used for classification
  final Map<String, double> allProbabilities; // Debug info
  final String explanation; // Human-readable reasoning
  final KalmanResult? kalmanResult; // Kalman filter output (optional)
  final Map<String, double>? features; // Extracted features (optional)

  UnifiedResult({
    required this.karat,
    required this.confidence,
    required this.meanAdc,
    required this.allProbabilities,
    required this.explanation,
    this.kalmanResult,
    this.features,
  });

  @override
  String toString() {
    return 'UnifiedResult(karat: $karat, confidence: ${confidence.toStringAsFixed(1)}%, adc: $meanAdc)';
  }
}
