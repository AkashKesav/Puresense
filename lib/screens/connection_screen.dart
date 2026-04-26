
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/bt_provider.dart';
import '../services/bluetooth_service.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen>
    with SingleTickerProviderStateMixin {
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _requestPermissions();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
  }

  Future<void> _scan() async {
    setState(() => _isScanning = true);
    try {
      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      if (mounted) setState(() => _devices = devices);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to scan. Check Bluetooth.')),
        );
      }
    }
    if (mounted) setState(() => _isScanning = false);
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    // Warn if not the expected ESP32 device
    final isRecommended = device.name == 'ESP32_GoldDetector' || device.name == 'ESP32';
    if (!isRecommended && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF333333),
          content: Text(
            'This device may not be a PureSense sensor. Expected "ESP32_GoldDetector".',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    final bt = ref.read(btProvider);
    await bt.connect(device);

    if (bt.status.value == BtStatus.connected && mounted) {
      context.go('/home');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to ${device.name}'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _connectToDevice(device),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final btStatus = ref.watch(btStatusProvider);
    final isConnecting = btStatus.when(
      data: (s) => s == BtStatus.connecting,
      loading: () => false,
      error: (_, __) => false,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              // Status indicator with pulse ring
              Center(
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isConnecting) ...[
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            return Container(
                              width: 80 + _pulseController.value * 20,
                              height: 80 + _pulseController.value * 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFFFB300).withAlpha(
                                    (150 * (1 - _pulseController.value)).toInt(),
                                  ),
                                  width: 2,
                                ),
                              ),
                            );
                          },
                        ),
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            final delayed = (_pulseController.value + 0.3) % 1.0;
                            return Container(
                              width: 80 + delayed * 20,
                              height: 80 + delayed * 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFFFB300).withAlpha(
                                    (100 * (1 - delayed)).toInt(),
                                  ),
                                  width: 1.5,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF222222),
                          border: Border.all(
                            color: isConnecting
                                ? const Color(0xFFFFB300)
                                : Colors.white.withAlpha(30),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.bluetooth,
                          size: 32,
                          color: isConnecting
                              ? const Color(0xFFFFB300)
                              : Colors.white.withAlpha(120),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Heading
              Center(
                child: Text(
                  'Connect your device',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Make sure your ESP32 is powered on\nand Bluetooth is enabled',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white.withAlpha(130),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Scan button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _scan,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.bluetooth_searching, size: 20),
                  label: Text(_isScanning ? 'Scanning...' : 'Scan for Devices'),
                ),
              ),

              const SizedBox(height: 24),

              // Device list
              if (_devices.isNotEmpty)
                Text(
                  'AVAILABLE DEVICES',
                  style: GoogleFonts.inter(
                    color: Colors.white.withAlpha(130),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: _devices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bluetooth_disabled,
                                size: 48, color: Colors.white.withAlpha(40)),
                            const SizedBox(height: 16),
                            Text(
                              'No paired devices found',
                              style: GoogleFonts.inter(
                                color: Colors.white.withAlpha(100),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "Scan" to find your ESP32',
                              style: GoogleFonts.inter(
                                color: Colors.white.withAlpha(60),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _devices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          final isRecommended = device.name == 'ESP32_GoldDetector' ||
                              device.name == 'ESP32';
                          return _DeviceCard(
                            device: device,
                            isRecommended: isRecommended,
                            isConnecting: isConnecting,
                            onTap: () => _connectToDevice(device),
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

class _DeviceCard extends StatelessWidget {
  final BluetoothDevice device;
  final bool isRecommended;
  final bool isConnecting;
  final VoidCallback onTap;

  const _DeviceCard({
    required this.device,
    required this.isRecommended,
    required this.isConnecting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isConnecting ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRecommended
                ? const Color(0xFFFFB300).withAlpha(150)
                : Colors.white.withAlpha(15),
            width: isRecommended ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isRecommended
                    ? const Color(0xFFFFB300).withAlpha(25)
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.bluetooth,
                color: isRecommended
                    ? const Color(0xFFFFB300)
                    : Colors.white.withAlpha(100),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          device.name ?? 'Unknown Device',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300).withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Recommended',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFFB300),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    device.address,
                    style: GoogleFonts.inter(
                      color: Colors.white.withAlpha(80),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.white.withAlpha(60),
            ),
          ],
        ),
      ),
    );
  }
}
