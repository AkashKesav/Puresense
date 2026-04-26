import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../models/live_data.dart';
import '../utils/result_parser.dart';
import '../utils/statistical_classifier.dart';

enum BtStatus { connecting, connected, disconnected }

enum ProbeStatus { inAir, contact, noSignal, unknown }

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  BluetoothConnection? _connection;
  final ValueNotifier<BtStatus> status = ValueNotifier(BtStatus.disconnected);

  // Stream controllers
  final _linesController = StreamController<String>.broadcast();
  final _liveDataController = StreamController<LiveData>.broadcast();
  final _probeStatusController = StreamController<ProbeStatus>.broadcast();

  Stream<String> get linesStream => _linesController.stream;
  Stream<LiveData> get liveDataStream => _liveDataController.stream;
  Stream<ProbeStatus> get probeStatusStream => _probeStatusController.stream;

  String _lineBuffer = '';
  bool _disposed = false;
  bool _autoReconnectEnabled = true;
  bool _manualDisconnect = false;
  Timer? _reconnectTimer;

  // ─── Purity test state ───
  bool _isCollectingPurity = false;
  final List<int> _purityADCSamples = [];
  final List<TimedSample> _purityTimedSamples = [];
  Timer? _purityTimer;
  Completer<int>? _purityCompleter;

  // ─── Probe-in-air sound debounce (5 seconds) ───
  DateTime _lastProbeAirSoundTime = DateTime(2000);
  ProbeStatus _lastProbeStatus = ProbeStatus.unknown;

  void setAutoReconnectEnabled(bool enabled) {
    _autoReconnectEnabled = enabled;
    if (!enabled) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
  }

  /// Connect to a Bluetooth device
  Future<void> connect(BluetoothDevice device) async {
    _manualDisconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _connectInternal(
      device,
      retryOnceOnFailure: _autoReconnectEnabled,
    );
  }

  Future<void> _connectInternal(
    BluetoothDevice device, {
    required bool retryOnceOnFailure,
  }) async {
    if (_disposed) return;
    status.value = BtStatus.connecting;

    try {
      await _openConnection(device);
    } catch (e) {
      status.value = BtStatus.disconnected;
      if (!retryOnceOnFailure || _manualDisconnect || _disposed) {
        return;
      }

      await Future.delayed(const Duration(seconds: 3));
      if (status.value == BtStatus.disconnected &&
          !_disposed &&
          !_manualDisconnect) {
        try {
          await _openConnection(device);
        } catch (_) {
          status.value = BtStatus.disconnected;
        }
      }
    }
  }

  Future<void> _openConnection(BluetoothDevice device) async {
    final connection = await BluetoothConnection.toAddress(device.address)
        .timeout(const Duration(seconds: 10));

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connection = connection;
    _manualDisconnect = false;
    status.value = BtStatus.connected;

    connection.input?.listen(
      (data) => _onDataReceived(data),
      onDone: () => _onDisconnected(device),
      onError: (_) => _onDisconnected(device),
    );
  }

  void _onDisconnected(BluetoothDevice device) {
    status.value = BtStatus.disconnected;
    _connection = null;

    if (_autoReconnectEnabled && !_manualDisconnect && !_disposed) {
      _scheduleReconnect(device);
    }
  }

  void _scheduleReconnect(BluetoothDevice device) {
    if (_reconnectTimer != null) return;

    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _reconnectTimer = null;
      if (_disposed || _manualDisconnect || !_autoReconnectEnabled) return;
      if (status.value == BtStatus.connected ||
          status.value == BtStatus.connecting) {
        return;
      }
      unawaited(_connectInternal(device, retryOnceOnFailure: false));
    });
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _connection?.close();
    _connection = null;
    status.value = BtStatus.disconnected;
  }

  // ─── Data reception & parsing ───
  void _onDataReceived(Uint8List data) {
    _lineBuffer += utf8.decode(data, allowMalformed: true);

    while (_lineBuffer.contains('\n')) {
      final idx = _lineBuffer.indexOf('\n');
      final line = _lineBuffer.substring(0, idx).trim();
      _lineBuffer = _lineBuffer.substring(idx + 1);

      if (line.isEmpty) continue;

      // Emit raw line for listeners
      _linesController.add(line);

      // Parse live data: "HX711: X.XX g | ADS: Y"
      final liveData = ResultParser.parseLiveData(line);
      if (liveData != null) {
        _liveDataController.add(liveData);

        // Update probe status (ADC > 15000 = air, else contact)
        ProbeStatus newStatus;
        if (liveData.adcValue > 15000) {
          newStatus = ProbeStatus.inAir;
        } else {
          newStatus = ProbeStatus.contact;
        }

        // Only emit if changed (reduces unnecessary rebuilds)
        if (newStatus != _lastProbeStatus) {
          _lastProbeStatus = newStatus;
          _probeStatusController.add(newStatus);
        }

        // If collecting purity samples, add this ADC reading
        if (_isCollectingPurity) {
          _purityADCSamples.add(liveData.adcValue);
          _purityTimedSamples.add(TimedSample(
            timestamp: DateTime.now(),
            adc: liveData.adcValue,
          ));
        }
      }
    }
  }

  // ─── Probe-in-air sound debounce ───
  /// Returns true if a probe-in-air sound should play (5s debounce)
  bool shouldPlayProbeAirSound() {
    final now = DateTime.now();
    if (now.difference(_lastProbeAirSoundTime).inSeconds >= 5) {
      _lastProbeAirSoundTime = now;
      return true;
    }
    return false;
  }

  // ─── Command sending (PRIVATE — never expose raw commands to UI) ───
  void _sendCommand(String cmd) {
    if (_connection == null || status.value != BtStatus.connected) return;
    try {
      _connection!.output.add(Uint8List.fromList(utf8.encode('$cmd\n')));
      _connection!.output.allSent;
    } catch (_) {}
  }

  // ─── PUBLIC API: Hardware commands with descriptive names ───

  /// Tare (zero) the scale — sends 'T' to Arduino
  void zeroScale() => _sendCommand('T');

  /// Record air weight — sends 'A' to Arduino
  void requestDensityAir() => _sendCommand('A');

  /// Record water baseline — sends 'W' to Arduino
  void requestDensityWater() => _sendCommand('W');

  /// Record submerged weight — sends 'S' to Arduino
  void requestDensitySubmerged() => _sendCommand('S');

  /// Calculate density — sends 'C' to Arduino
  void requestDensityCalculate() => _sendCommand('C');

  /// Get single live HX711 reading — sends 'R' to Arduino
  void readLiveHX711() => _sendCommand('R');

  /// Get single ADS1115 reading — sends 'D' to Arduino
  void readADS1115() => _sendCommand('D');

  /// Show Arduino menu — sends 'M' to Arduino
  void showMenu() => _sendCommand('M');

  /// Start purity test (standard mode) — collects ADC values for 2 seconds.
  /// Returns the mean ADC value via a Future.
  Future<int> startPurityTest() async {
    return _startCollection(const Duration(seconds: 2));
  }

  Future<int> startPurityTestFor(Duration duration) async {
    return _startCollection(duration);
  }

  /// Start purity test (statistical mode) — collects ADC values for 1 second.
  /// Shorter window because slope-based analysis compensates for drift.
  /// Returns the mean ADC value via a Future.
  Future<int> startPurityTestStatistical() async {
    return _startCollection(const Duration(seconds: 1));
  }

  Future<int> startPurityTestAdaptive() async {
    return _startCollection(const Duration(milliseconds: 800));
  }

  /// Internal collection method with configurable duration.
  Future<int> _startCollection(Duration duration) async {
    _purityADCSamples.clear();
    _purityTimedSamples.clear();
    _isCollectingPurity = true;
    _purityCompleter = Completer<int>();

    _purityTimer = Timer(duration, () {
      _isCollectingPurity = false;
      if (_purityADCSamples.isEmpty) {
        _purityCompleter?.complete(0);
      } else {
        final mean = _purityADCSamples.reduce((a, b) => a + b) ~/
            _purityADCSamples.length;
        _purityCompleter?.complete(mean);
      }
    });

    return _purityCompleter!.future;
  }

  /// Get the raw ADC samples collected during purity test
  List<int> get purityADCSamplesCopy => List.unmodifiable(_purityADCSamples);

  /// Get the timestamped ADC samples for statistical analysis
  List<TimedSample> get purityTimedSamplesCopy =>
      List.unmodifiable(_purityTimedSamples);

  /// Get number of collected purity samples so far
  int get puritySampleCount => _purityADCSamples.length;

  /// Cancel ongoing purity test
  void cancelPurityTest() {
    _isCollectingPurity = false;
    _purityTimer?.cancel();
    _purityADCSamples.clear();
    _purityTimedSamples.clear();
    if (_purityCompleter != null && !_purityCompleter!.isCompleted) {
      _purityCompleter!.complete(0);
    }
  }

  /// Start calibration — collects ADC values from continuous stream for 2 seconds.
  /// Returns mean ADC for calibration anchor.
  Future<int> startCalibration() async {
    return startPurityTest(); // Same collection mechanism
  }

  void dispose() {
    _disposed = true;
    _purityTimer?.cancel();
    _reconnectTimer?.cancel();
    _linesController.close();
    _liveDataController.close();
    _probeStatusController.close();
    _connection?.close();
  }
}
