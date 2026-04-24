import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/bt_provider.dart';
import '../services/bluetooth_service.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  List<BluetoothDevice> _devices = [];
  bool _scanning = false;
  BluetoothDevice? _connectingDevice;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await ref.read(btProvider).requestPermissions();
  }

  Future<void> _scanDevices() async {
    setState(() => _scanning = true);
    final devices = await ref.read(btProvider).getPairedDevices();
    setState(() {
      _devices = devices;
      _scanning = false;
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() => _connectingDevice = device);
    final bt = ref.read(btProvider);
    await bt.connect(device);

    // Listen for status changes
    bt.status.addListener(() {
      if (bt.status.value == BtStatus.connected && mounted) {
        context.go('/home');
      }
      if (bt.status.value == BtStatus.disconnected && mounted) {
        setState(() => _connectingDevice = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final btStatus = ref.watch(btProvider).status.value;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Connect your device',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Make sure your ESP32 is powered on and Bluetooth is enabled',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _scanning ? null : _scanDevices,
                  icon: _scanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.bluetooth_searching),
                  label: Text(_scanning ? 'Scanning...' : 'Scan for Devices'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _devices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bluetooth_disabled,
                              size: 64,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No devices found',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16),
                            ),
                            Text(
                              'Tap Scan to find paired devices',
                              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          final isTarget = device.name?.contains('ESP32_GoldDetector') ?? false;
                          final isConnecting = _connectingDevice?.address == device.address;

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(12),
                              border: isTarget
                                  ? Border.all(color: const Color(0xFFFFB300), width: 2)
                                  : null,
                            ),
                            child: ListTile(
                              leading: isConnecting
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          isTarget ? const Color(0xFFFFB300) : Colors.white,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.bluetooth,
                                      color: isTarget ? const Color(0xFFFFB300) : Colors.white54,
                                    ),
                              title: Text(
                                device.name ?? 'Unknown Device',
                                style: TextStyle(
                                  color: isTarget ? const Color(0xFFFFB300) : Colors.white,
                                  fontWeight: isTarget ? FontWeight.w700 : FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                device.address,
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                              ),
                              trailing: isTarget
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFB300).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Recommended',
                                        style: TextStyle(
                                          color: Color(0xFFFFB300),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                  : null,
                              onTap: isConnecting
                                  ? null
                                  : () => _connect(device),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
