import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/live_data.dart';

enum BtStatus { connecting, connected, disconnected }
enum ProbeStatus { inAir, contact, noSignal, unknown }

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  final FlutterBluetoothSerial _bt = FlutterBluetoothSerial.instance;
  BluetoothConnection? _connection;
  final _status = ValueNotifier<BtStatus>(BtStatus.disconnected);
  final _linesController = StreamController<String>.broadcast();
  final _liveDataController = StreamController<LiveData>.broadcast();
  final _probeStatusController = StreamController<ProbeStatus>.broadcast();

  ValueNotifier<BtStatus> get status => _status;
  BtStatus get currentStatus => _status.value;
  Stream<String> get linesStream => _linesController.stream;
  Stream<LiveData> get liveDataStream => _liveDataController.stream;
  Stream<ProbeStatus> get probeStatusStream => _probeStatusController.stream;

  String _buffer = '';
  Timer? _retryTimer;
  BluetoothDevice? _lastDevice;

  Future<bool> requestPermissions() async {
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ];
    final results = await permissions.request();
    return results.values.every((r) => r.isGranted);
  }

  Future<void> ensureBluetoothReady({bool requestEnable = true}) async {
    final hasPermissions = await requestPermissions();
    if (!hasPermissions) {
      throw StateError('Bluetooth and location permissions are required.');
    }

    final enabled = await _bt.isEnabled ?? false;
    if (enabled) return;

    if (requestEnable) {
      final turnedOn = await _bt.requestEnable() ?? false;
      if (turnedOn) return;
    }

    throw StateError('Bluetooth is turned off. Turn it on and try again.');
  }

  Future<void> openSettings() => _bt.openSettings();

  Future<List<BluetoothDevice>> getPairedDevices() async {
    await ensureBluetoothReady();
    try {
      final devices = await _bt.getBondedDevices();
      devices.sort((a, b) => (a.name ?? a.address).compareTo(b.name ?? b.address));
      return devices;
    } catch (e) {
      throw StateError('Unable to load paired Bluetooth devices.');
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    _lastDevice = device;
    _retryTimer?.cancel();
    if (_connection?.isConnected ?? false) {
      await disconnect();
    }

    await ensureBluetoothReady();
    _status.value = BtStatus.connecting;
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      if (_connection != null && _connection!.isConnected) {
        _status.value = BtStatus.connected;
        _connection!.input!.listen(_onData, onDone: _onDisconnect, onError: (_) => _onDisconnect());
      } else {
        _connection = null;
        _status.value = BtStatus.disconnected;
        throw StateError('Connection could not be established.');
      }
    } catch (e) {
      _connection = null;
      _status.value = BtStatus.disconnected;
      throw StateError('Could not connect to ${device.name ?? device.address}.');
    }
  }

  Future<void> disconnect() async {
    _retryTimer?.cancel();
    await _connection?.close();
    _connection = null;
    _buffer = '';
    _status.value = BtStatus.disconnected;
  }

  void _onData(Uint8List data) {
    _buffer += String.fromCharCodes(data);
    while (_buffer.contains('\n')) {
      final idx = _buffer.indexOf('\n');
      final line = _buffer.substring(0, idx).trim();
      _buffer = _buffer.substring(idx + 1);
      if (line.isNotEmpty) {
        _linesController.add(line);
        _parseLiveLine(line);
      }
    }
  }

  void _parseLiveLine(String line) {
    final live = _parseLiveData(line);
    if (live != null) {
      _liveDataController.add(live);
      _updateProbeStatus(live);
    }
  }

  LiveData? _parseLiveData(String line) {
    final regex = RegExp(r'HX711:\s*([0-9.]+)\s*g\s*\|\s*ADS:\s*(-?\d+)');
    final match = regex.firstMatch(line);
    if (match != null) {
      final weight = double.tryParse(match.group(1)!) ?? 0.0;
      final adc = int.tryParse(match.group(2)!) ?? 0;
      return LiveData(
        weightGrams: weight,
        adcValue: adc,
        timestamp: DateTime.now(),
      );
    }
    return null;
  }

  void _updateProbeStatus(LiveData live) {
    if (live.adcValue > 18000) {
      _probeStatusController.add(ProbeStatus.inAir);
    } else if (live.adcValue < 500) {
      _probeStatusController.add(ProbeStatus.noSignal);
    } else {
      _probeStatusController.add(ProbeStatus.contact);
    }
  }

  void _onDisconnect() {
    if (_status.value == BtStatus.connected) {
      _status.value = BtStatus.disconnected;
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 3), () {
        if (_lastDevice != null && _status.value == BtStatus.disconnected) {
          connect(_lastDevice!);
        }
      });
    }
  }

  void _sendCommand(String char) {
    if (_connection != null && _connection!.isConnected) {
      _connection!.output.add(Uint8List.fromList([char.codeUnitAt(0)]));
    }
  }

  // Public methods that internally send commands
  void startPurityTest() => _sendCommand('T');
  void startCalibration() => _sendCommand('R');
  void requestDensityAir() => _sendCommand('A');
  void requestDensityWater() => _sendCommand('W');
  void requestDensitySubmerged() => _sendCommand('S');
  void requestDensityCalculate() => _sendCommand('C');
  void zeroScale() => _sendCommand('Z');
  void readADS() => _sendCommand('D');
  void printMenu() => _sendCommand('M');

  void dispose() {
    _retryTimer?.cancel();
    _linesController.close();
    _liveDataController.close();
    _probeStatusController.close();
    disconnect();
  }
}
