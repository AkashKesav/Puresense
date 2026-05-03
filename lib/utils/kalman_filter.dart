import 'dart:math';

/// Kalman Filter for ADC drift correction and optimal estimation
///
/// State vector: [ADC_value, drift_rate, slope]
/// - ADC_value: Current estimate of true ADC
/// - drift_rate: Rate of ADC drift per sample
/// - slope: Rate of change of drift (acceleration)
class KalmanFilter {
  // State vector: x = [ADC, drift, slope]
  late List<double> _x;

  // State covariance matrix: P (3x3)
  late List<List<double>> _P;

  // State transition matrix: F (3x3)
  final List<List<double>> _F;

  // Measurement matrix: H (1x3) - we only measure ADC directly
  final List<double> _H;

  // Process noise covariance: Q (3x3)
  final List<List<double>> _Q;

  // Measurement noise: R (scalar)
  final double _R;

  // Identity matrix: I (3x3)
  static const List<List<double>> _I = [
    [1.0, 0.0, 0.0],
    [0.0, 1.0, 0.0],
    [0.0, 0.0, 1.0],
  ];

  /// Create a new Kalman filter
  ///
  /// Parameters:
  /// - processNoise: Q matrix diagonal [ADC_noise, drift_noise, slope_noise]
  /// - measurementNoise: R value (ADC measurement variance)
  /// - initialState: Initial state [ADC, drift, slope]
  KalmanFilter({
    List<double>? processNoise,
    double measurementNoise = 100.0,
    List<double>? initialState,
  })  : _F = [
          [1.0, 1.0, 0.5], // ADC += drift * dt + 0.5 * slope * dt² (dt=1)
          [0.0, 1.0, 1.0], // drift += slope * dt
          [0.0, 0.0, 1.0], // slope constant
        ],
        _H = [1.0, 0.0, 0.0], // We measure ADC directly
        _Q = _createDiagonalMatrix(processNoise ?? [10.0, 1.0, 0.1]),
        _R = measurementNoise {
    // Initialize state
    _x = initialState ?? [0.0, 0.0, 0.0];

    // Initialize covariance (high uncertainty initially)
    _P = [
      [1000.0, 0.0, 0.0],
      [0.0, 100.0, 0.0],
      [0.0, 0.0, 10.0],
    ];
  }

  /// Filter a sequence of ADC samples and return the optimal estimate
  static KalmanResult filter(List<int> samples, {
    List<double>? processNoise,
    double measurementNoise = 100.0,
  }) {
    final kf = KalmanFilter(
      processNoise: processNoise,
      measurementNoise: measurementNoise,
      initialState: [samples.first.toDouble(), 0.0, 0.0],
    );

    // Run filter through all samples
    for (final sample in samples) {
      kf.update(sample);
    }

    // Get final estimate
    final estimatedAdc = kf._x[0].round();
    final driftRate = kf._x[1];
    final slope = kf._x[2];

    // Calculate confidence based on covariance
    final uncertainty = sqrt(kf._P[0][0]);
    final confidence = max(50.0, min(99.0, 100.0 - (uncertainty / 10.0)));

    return KalmanResult(
      estimatedAdc: estimatedAdc,
      confidence: confidence,
      driftRate: driftRate,
      slope: slope,
      uncertainty: uncertainty,
    );
  }

  /// Single update step with new measurement
  void update(int measurement) {
    // ===== PREDICT STEP =====
    // Predict state: x_pred = F * x
    final x_pred = _matrixVectorMultiply(_F, _x);

    // Predict covariance: P_pred = F * P * F^T + Q
    final Ft = _transpose(_F);
    final FP = _matrixMultiply(_F, _P);
    final FPFT = _matrixMultiply(FP, Ft);
    final P_pred = _matrixAdd(FPFT, _Q);

    // ===== UPDATE STEP =====
    // Innovation: y = z - H * x_pred
    final Hx_pred = _dotProduct(_H, x_pred);
    final y = measurement - Hx_pred;

    // Innovation covariance: S = H * P_pred * H^T + R
    final PHt = _matrixVectorMultiply(P_pred, _H);
    final S = _dotProduct(_H, PHt) + _R;

    // Kalman gain: K = P_pred * H^T * S^(-1)
    final K = PHt.map((val) => val / S).toList();

    // Update state: x = x_pred + K * y
    final Ky = K.map((val) => val * y).toList();
    _x = _vectorAdd(x_pred, Ky);

    // Update covariance: P = (I - K * H) * P_pred
    final KH = _outerProduct(K, _H);
    final I_KH = _matrixSubtract(_I, KH);
    _P = _matrixMultiply(I_KH, P_pred);
  }

  // ===== Matrix/Vector Helper Methods =====

  static List<List<double>> _createDiagonalMatrix(List<double> diag) {
    final n = diag.length;
    return List.generate(
      n,
      (i) => List.generate(
        n,
        (j) => (i == j) ? diag[i] : 0.0,
      ),
    );
  }

  static List<double> _matrixVectorMultiply(
    List<List<double>> matrix,
    List<double> vector,
  ) {
    return matrix.map((row) => _dotProduct(row, vector)).toList();
  }

  static List<List<double>> _matrixMultiply(
    List<List<double>> A,
    List<List<double>> B,
  ) {
    final m = A.length;
    final n = B[0].length;
    final p = B.length;

    return List.generate(
      m,
      (i) => List.generate(
        n,
        (j) {
          double sum = 0.0;
          for (int k = 0; k < p; k++) {
            sum += A[i][k] * B[k][j];
          }
          return sum;
        },
      ),
    );
  }

  static List<List<double>> _matrixAdd(
    List<List<double>> A,
    List<List<double>> B,
  ) {
    return List.generate(
      A.length,
      (i) => List.generate(
        A[i].length,
        (j) => A[i][j] + B[i][j],
      ),
    );
  }

  static List<List<double>> _matrixSubtract(
    List<List<double>> A,
    List<List<double>> B,
  ) {
    return List.generate(
      A.length,
      (i) => List.generate(
        A[i].length,
        (j) => A[i][j] - B[i][j],
      ),
    );
  }

  static List<List<double>> _transpose(List<List<double>> matrix) {
    final m = matrix.length;
    final n = matrix[0].length;
    return List.generate(
      n,
      (j) => List.generate(m, (i) => matrix[i][j]),
    );
  }

  static List<double> _vectorAdd(
    List<double> a,
    List<double> b,
  ) {
    return List.generate(a.length, (i) => a[i] + b[i]);
  }

  static double _dotProduct(List<double> a, List<double> b) {
    double sum = 0.0;
    for (int i = 0; i < a.length; i++) {
      sum += a[i] * b[i];
    }
    return sum;
  }

  static List<List<double>> _outerProduct(
    List<double> a,
    List<double> b,
  ) {
    return List.generate(
      a.length,
      (i) => List.generate(b.length, (j) => a[i] * b[j]),
    );
  }
}

/// Result from Kalman filtering
class KalmanResult {
  final int estimatedAdc; // Optimal estimate of true ADC
  final double confidence; // Confidence 0-100 based on uncertainty
  final double driftRate; // ADC drift per sample
  final double slope; // Rate of change of drift
  final double uncertainty; // Standard deviation of estimate

  const KalmanResult({
    required this.estimatedAdc,
    required this.confidence,
    required this.driftRate,
    required this.slope,
    required this.uncertainty,
  });

  @override
  String toString() {
    return 'KalmanResult(adc: $estimatedAdc ± ${uncertainty.toStringAsFixed(1)}, drift: ${driftRate.toStringAsFixed(2)}/sample, conf: ${confidence.toStringAsFixed(1)}%)';
  }
}
