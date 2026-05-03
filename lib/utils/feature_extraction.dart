import 'dart:math';
import 'kalman_filter.dart';

/// Feature Extraction for Gold Classification
///
/// Extracts 20+ time-domain, frequency-domain, and statistical features
/// from processed ADC signals for machine learning classification
class FeatureExtractor {
  /// Extract all features from processed signal
  ///
  /// Returns: Map of feature name → value
  static Map<String, double> extractAll(
    List<int> samples, {
    KalmanResult? kalmanResult,
    int samplingRateHz = 100,
  }) {
    final features = <String, double>{};

    // ===== TIME DOMAIN FEATURES =====
    final timeFeatures = _extractTimeDomainFeatures(samples, kalmanResult);
    features.addAll(timeFeatures);

    // ===== FREQUENCY DOMAIN FEATURES =====
    final freqFeatures = _extractFrequencyDomainFeatures(samples, samplingRateHz);
    features.addAll(freqFeatures);

    // ===== STATISTICAL FEATURES =====
    final statFeatures = _extractStatisticalFeatures(samples);
    features.addAll(statFeatures);

    // ===== WAVELET FEATURES =====
    final waveletFeatures = _extractWaveletFeatures(samples);
    features.addAll(waveletFeatures);

    return features;
  }

  /// Extract time-domain features
  static Map<String, double> _extractTimeDomainFeatures(
    List<int> samples,
    KalmanResult? kalmanResult,
  ) {
    final features = <String, double>{};
    final n = samples.length.toDouble();

    // Basic statistics
    final mean = samples.reduce((a, b) => a + b) / n;
    features['mean'] = mean;

    final sorted = List.from(samples)..sort();
    final median = n % 2 == 0
        ? (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2
        : sorted[n ~/ 2].toDouble();
    features['median'] = median;

    features['min'] = samples.reduce(min).toDouble();
    features['max'] = samples.reduce(max).toDouble();
    features['range'] = features['max']! - features['min']!;

    // Variance and Std Dev
    final variance = samples.map((s) => pow(s - mean, 2)).reduce((a, b) => a + b) / n;
    features['variance'] = variance;
    features['stdDev'] = sqrt(variance);

    // Skewness (3rd moment)
    final stdDev = features['stdDev']!;
    final skewness = stdDev > 0
        ? samples.map((s) => pow((s - mean) / stdDev, 3)).reduce((a, b) => a + b) / n
        : 0.0;
    features['skewness'] = skewness;

    // Kurtosis (4th moment)
    final kurtosis = stdDev > 0
        ? samples.map((s) => pow((s - mean) / stdDev, 4)).reduce((a, b) => a + b) / n - 3.0
        : 0.0;
    features['kurtosis'] = kurtosis;

    // RMS (Root Mean Square)
    final rms = sqrt(samples.map((s) => s * s).reduce((a, b) => a + b) / n);
    features['rms'] = rms;

    // Crest Factor (peak / RMS)
    features['crestFactor'] = rms > 0 ? features['range']! / rms : 0.0;

    // Zero-crossing rate
    int zeroCrossings = 0;
    for (int i = 1; i < samples.length; i++) {
      if ((samples[i - 1] - mean) * (samples[i] - mean) < 0) {
        zeroCrossings++;
      }
    }
    features['zeroCrossingRate'] = zeroCrossings / samples.length;

    // Drift rate (from Kalman if available)
    if (kalmanResult != null) {
      features['driftRate'] = kalmanResult.driftRate;
      features['slope'] = kalmanResult.slope;
      features['kalmanUncertainty'] = kalmanResult.uncertainty;
    } else {
      // Linear regression for drift
      final drift = _calculateLinearDrift(samples);
      features['driftRate'] = drift['slope']!;
      features['slope'] = drift['slope']!;
    }

    return features;
  }

  /// Extract frequency-domain features using FFT
  static Map<String, double> _extractFrequencyDomainFeatures(
    List<int> samples,
    int samplingRateHz,
  ) {
    final features = <String, double>{};

    // Compute FFT magnitude spectrum
    final fftResult = _computeFFT(samples.map((s) => s.toDouble()).toList());
    final magnitudes = fftResult.map((c) => c.magnitude).toList();

    if (magnitudes.isEmpty) {
      return features;
    }

    // Dominant frequency
    final maxIndex = magnitudes.indexOf(magnitudes.reduce(max));
    features['dominantFreq'] = maxIndex * samplingRateHz / samples.length;

    // Spectral centroid (weighted mean of frequencies)
    double weightedSum = 0.0;
    double totalPower = 0.0;
    for (int i = 0; i < magnitudes.length; i++) {
      weightedSum += i * magnitudes[i];
      totalPower += magnitudes[i];
    }
    features['spectralCentroid'] =
        totalPower > 0 ? (weightedSum / totalPower * samplingRateHz / samples.length) : 0.0;

    // Spectral rolloff (frequency below which 85% of energy is contained)
    double cumulative = 0.0;
    final threshold = 0.85 * totalPower;
    int rolloffIndex = 0;
    for (int i = 0; i < magnitudes.length; i++) {
      cumulative += magnitudes[i];
      if (cumulative >= threshold) {
        rolloffIndex = i;
        break;
      }
    }
    features['spectralRolloff'] = rolloffIndex * samplingRateHz / samples.length;

    // Bandpower in specific frequency ranges
    final nyquist = samplingRateHz / 2;
    final binSize = nyquist / magnitudes.length;

    // Low frequency (0-10 Hz)
    final lowBinEnd = (10 / binSize).clamp(0, magnitudes.length).toInt();
    final lowBandPower = magnitudes.sublist(0, lowBinEnd).map((p) => p * p).reduce((a, b) => a + b);
    features['bandPowerLow'] = lowBandPower;

    // Mid frequency (10-50 Hz)
    final midBinStart = lowBinEnd;
    final midBinEnd = (50 / binSize).clamp(0, magnitudes.length).toInt();
    final midBandPower = midBinEnd > midBinStart
        ? magnitudes
            .sublist(midBinStart, midBinEnd)
            .map((p) => p * p)
            .reduce((a, b) => a + b)
        : 0.0;
    features['bandPowerMid'] = midBandPower;

    // High frequency (50-100 Hz)
    final highBinStart = midBinEnd;
    final highBinEnd = (100 / binSize).clamp(0, magnitudes.length).toInt();
    final highBandPower = highBinEnd > highBinStart
        ? magnitudes
            .sublist(highBinStart, highBinEnd)
            .map((p) => p * p)
            .reduce((a, b) => a + b)
        : 0.0;
    features['bandPowerHigh'] = highBandPower;

    return features;
  }

  /// Extract statistical features
  static Map<String, double> _extractStatisticalFeatures(List<int> samples) {
    final features = <String, double>{};
    final n = samples.length;
    final mean = samples.reduce((a, b) => a + b) / n;

    // Interquartile range (IQR)
    final sorted = List<int>.from(samples)..sort();
    final q1 = sorted[(n * 0.25).floor()].toDouble();
    final q3 = sorted[(n * 0.75).floor()].toDouble();
    features['iqr'] = q3 - q1;

    // Median Absolute Deviation (MAD)
    final medianValue = sorted[(sorted.length / 2).floor()].toDouble();
    final deviations = sorted.map((s) => (s - medianValue).abs()).toList();
    deviations.sort();
    final mad = deviations[deviations.length ~/ 2].toDouble();
    features['mad'] = mad;

    // Coefficient of variation (CV)
    final stdDev = sqrt(samples.map((s) => pow(s - mean, 2)).reduce((a, b) => a + b) / n);
    features['cv'] = mean != 0 ? (stdDev / mean).abs() : 0.0;

    return features;
  }

  /// Extract wavelet-domain features
  static Map<String, double> _extractWaveletFeatures(List<int> samples) {
    final features = <String, double>{};

    // Single-level Haar decomposition
    final n = samples.length;
    if (n < 2) return features;

    final approximation = <double>[];
    final detail = <double>[];

    for (int i = 0; i < n ~/ 2; i++) {
      final a = (samples[2 * i] + samples[2 * i + 1]) / sqrt(2);
      final d = (samples[2 * i] - samples[2 * i + 1]) / sqrt(2);
      approximation.add(a);
      detail.add(d);
    }

    // Energy in approximation coefficients
    final approxEnergy = approximation.map((c) => c * c).reduce((a, b) => a + b);
    features['waveletEnergyApprox'] = approxEnergy;

    // Energy in detail coefficients
    final detailEnergy = detail.map((c) => c * c).reduce((a, b) => a + b);
    features['waveletEnergyDetail'] = detailEnergy;

    // Energy ratio
    features['waveletEnergyRatio'] =
        (approxEnergy + detailEnergy) > 0 ? approxEnergy / (approxEnergy + detailEnergy) : 0.0;

    return features;
  }

  /// Calculate linear drift using simple linear regression
  static Map<String, double> _calculateLinearDrift(List<int> samples) {
    final n = samples.length;
    double sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0;

    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += samples[i];
      sumXY += i * samples[i];
      sumX2 += i * i;
    }

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    return {'slope': slope, 'intercept': intercept};
  }

  /// Compute FFT using Cooley-Tukey algorithm (radix-2)
  static List<Complex> _computeFFT(List<double> signal) {
    final n = signal.length;

    // Pad to next power of 2 if necessary
    final paddedN = 1 << (n - 1).bitLength;
    if (n < paddedN) {
      signal = [...signal, ...List.filled(paddedN - n, 0.0)];
    }

    return _fft(signal.map((s) => Complex(s, 0.0)).toList());
  }

  /// Recursive FFT implementation
  static List<Complex> _fft(List<Complex> x) {
    final n = x.length;

    if (n <= 1) {
      return x;
    }

    // Divide
    final even = _fft([for (int i = 0; i < n; i += 2) x[i]]);
    final odd = _fft([for (int i = 1; i < n; i += 2) x[i]]);

    // Combine
    final result = List<Complex>.filled(n, Complex.zero());
    for (int k = 0; k < n ~/ 2; k++) {
      final t = Complex.fromPolar(1.0, -2 * pi * k / n) * odd[k];
      result[k] = even[k] + t;
      result[k + n ~/ 2] = even[k] - t;
    }

    return result;
  }

  /// Helper: calculate median of sorted list
  static double median(List<int> sorted) {
    final n = sorted.length;
    return n % 2 == 0
        ? (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2
        : sorted[n ~/ 2].toDouble();
  }
}

/// Complex number class for FFT
class Complex {
  final double real;
  final double imag;

  const Complex(this.real, this.imag);

  const Complex.zero() : real = 0.0, imag = 0.0;

  double get magnitude => sqrt(real * real + imag * imag);

  Complex operator +(Complex other) =>
      Complex(real + other.real, imag + other.imag);

  Complex operator -(Complex other) =>
      Complex(real - other.real, imag - other.imag);

  Complex operator *(Complex other) => Complex(
        real * other.real - imag * other.imag,
        real * other.imag + imag * other.real,
      );

  factory Complex.fromPolar(double r, double theta) =>
      Complex(r * cos(theta), r * sin(theta));
}
