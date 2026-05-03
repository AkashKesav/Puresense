import 'dart:math';

/// Wavelet Denoising for ADC Signal Processing
///
/// Uses Haar wavelet decomposition with soft thresholding
/// to remove noise while preserving signal features
class WaveletDenoise {
  /// Denoise ADC samples using wavelet decomposition
  ///
  /// Parameters:
  /// - samples: Raw ADC readings
  /// - levels: Number of decomposition levels (default: 4)
  /// - thresholdMethod: 'soft' or 'hard' thresholding (default: 'soft')
  ///
  /// Returns: Denoised signal (same length as input)
  static List<int> denoise(
    List<int> samples, {
    int levels = 4,
    String thresholdMethod = 'soft',
  }) {
    if (samples.length < 8) {
      // Signal too short for wavelet transform
      return List.from(samples);
    }

    // Convert to double for processing
    final signal = samples.map((s) => s.toDouble()).toList();

    // Pad signal to power of 2 for efficient decomposition
    final paddedSignal = _padToPowerOf2(signal);

    // Wavelet decomposition
    final coefficients = _decompose(paddedSignal, levels);

    // Threshold detail coefficients (noise removal)
    final thresholded = _thresholdCoefficients(
      coefficients,
      thresholdMethod: thresholdMethod,
    );

    // Reconstruct signal
    final reconstructed = _reconstruct(thresholded, levels);

    // Remove padding and convert back to int
    final result = reconstructed.sublist(0, samples.length);

    return result.map((v) => v.round()).toList();
  }

  /// Pad signal to next power of 2
  static List<double> _padToPowerOf2(List<double> signal) {
    final n = signal.length;
    final nextPower = 1 << (n.bitLength);
    if (n == nextPower) return signal;

    // Zero-padding
    return [...signal, ...List.filled(nextPower - n, 0.0)];
  }

  /// Single-level Haar wavelet decomposition
  ///
  /// Returns: [approximation, detail] coefficients
  static List<List<double>> _haarDecomposition(List<double> signal) {
    final n = signal.length;
    if (n < 2) {
      return [signal, []];
    }

    final approximation = <double>[];
    final detail = <double>[];

    // Decompose: (a[i], d[i]) from (signal[2i], signal[2i+1])
    for (int i = 0; i < n ~/ 2; i++) {
      final a = (signal[2 * i] + signal[2 * i + 1]) / sqrt(2); // Approximation
      final d = (signal[2 * i] - signal[2 * i + 1]) / sqrt(2); // Detail
      approximation.add(a);
      detail.add(d);
    }

    return [approximation, detail];
  }

  /// Single-level Haar wavelet reconstruction
  static List<double> _haarReconstruction(
    List<double> approximation,
    List<double> detail,
  ) {
    final n = approximation.length;
    final reconstructed = <double>[];

    for (int i = 0; i < n; i++) {
      final x = (approximation[i] + detail[i]) / sqrt(2);
      final y = (approximation[i] - detail[i]) / sqrt(2);
      reconstructed.add(x);
      reconstructed.add(y);
    }

    return reconstructed;
  }

  /// Multi-level wavelet decomposition
  ///
  /// Returns nested coefficients structure:
  /// [approx_N, detail_N, detail_N-1, ..., detail_1]
  /// where N is the number of levels
  static List<List<double>> _decompose(List<double> signal, int levels) {
    final coefficients = <List<double>>[];
    List<double> current = signal;

    // Decompose repeatedly
    for (int level = 0; level < levels; level++) {
      final result = _haarDecomposition(current);

      // Store detail coefficients
      coefficients.insert(0, result[1]); // Prepend detail

      // Continue with approximation
      current = result[0];

      if (current.length < 2) break;
    }

    // Store final approximation
    coefficients.insert(0, current);

    return coefficients;
  }

  /// Reconstruct signal from wavelet coefficients
  static List<double> _reconstruct(
    List<List<double>> coefficients,
    int levels,
  ) {
    List<double> current = coefficients[0]; // Start with approximation

    // Reconstruct level by level
    for (int level = 0; level < levels && level < coefficients.length - 1; level++) {
      final detail = coefficients[level + 1];

      if (current.length != detail.length) {
        // Handle odd length case
        current = _haarReconstruction(current, detail.sublist(0, current.length));
      } else {
        current = _haarReconstruction(current, detail);
      }
    }

    return current;
  }

  /// Apply thresholding to detail coefficients (noise removal)
  static List<List<double>> _thresholdCoefficients(
    List<List<double>> coefficients, {
    String thresholdMethod = 'soft',
  }) {
    final result = <List<double>>[];

    // Keep approximation coefficients unchanged (index 0)
    result.add(List.from(coefficients[0]));

    // Threshold detail coefficients
    for (int i = 1; i < coefficients.length; i++) {
      final detail = coefficients[i];
      final threshold = _calculateThreshold(detail);
      final thresholded = _applyThreshold(detail, threshold, method: thresholdMethod);
      result.add(thresholded);
    }

    return result;
  }

  /// Calculate threshold value using Bayes/Shrink method
  static double _calculateThreshold(List<double> coefficients) {
    if (coefficients.isEmpty) return 0.0;

    // Estimate noise standard deviation from finest detail coefficients
    final n = coefficients.length;
    final absCoeffs = coefficients.map((c) => c.abs()).toList();
    absCoeffs.sort();

    // Median Absolute Deviation (MAD) estimator
    final median = absCoeffs[n ~/ 2];
    final sigma = median / 0.6745;

    // Universal threshold (VisuShrink)
    return sigma * sqrt(2 * log(n));
  }

  /// Apply threshold to coefficients
  static List<double> _applyThreshold(
    List<double> coeffs,
    double threshold, {
    String method = 'soft',
  }) {
    return coeffs.map((c) {
      if (method == 'soft') {
        // Soft thresholding
        if (c.abs() <= threshold) {
          return 0.0;
        } else {
          return c.sign * (c.abs() - threshold);
        }
      } else {
        // Hard thresholding
        return c.abs() <= threshold ? 0.0 : c;
      }
    }).toList();
  }

  /// Calculate Signal-to-Noise Ratio improvement
  static double calculateSNR(List<int> original, List<int> denoised) {
    if (original.length != denoised.length) return 0.0;

    final signalPower = original
        .map((s) => s * s)
        .reduce((a, b) => a + b) / original.length;

    final noise = List.generate(
      original.length,
      (i) => (original[i] - denoised[i]).toDouble(),
    );

    final noisePower = noise
        .map((n) => n * n)
        .reduce((a, b) => a + b) / noise.length;

    return 10 * log(signalPower / noisePower) / log(10);
  }
}

/// Alternative: Daubechies-4 wavelet coefficients
/// (Can be implemented for better performance at the cost of complexity)
class DaubechiesWavelet {
  // Daubechies-4 coefficients
  static const List<double> h = [
    0.4829629131445341,
    0.8365163037378079,
    0.2241438680420134,
    -0.1294095225512603,
  ];

  static const List<double> g = [
    -0.1294095225512603,
    0.2241438680420134,
    0.8365163037378079,
    -0.4829629131445341,
  ];

  // Daubechies-4 decomposition (more complex than Haar)
  // TODO: Implement if needed for better accuracy
}
