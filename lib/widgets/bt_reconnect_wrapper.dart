import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/bt_provider.dart';
import '../services/bluetooth_service.dart';

/// A wrapper widget that shows a reconnect banner at the top of any screen
/// when Bluetooth is disconnected. Provides one-tap reconnect without
/// navigating back to the connection screen.
class BtReconnectWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const BtReconnectWrapper({super.key, required this.child});

  @override
  ConsumerState<BtReconnectWrapper> createState() => _BtReconnectWrapperState();
}

class _BtReconnectWrapperState extends ConsumerState<BtReconnectWrapper>
    with SingleTickerProviderStateMixin {
  bool _isReconnecting = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _reconnect() async {
    final bt = ref.read(btProvider);
    if (bt.lastConnectedDevice == null) {
      // No device remembered — go to connection screen
      if (mounted) context.go('/connect');
      return;
    }

    setState(() => _isReconnecting = true);

    final success = await bt.reconnect();

    if (!mounted) return;
    setState(() => _isReconnecting = false);

    if (success && bt.status.value == BtStatus.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reconnected to ${bt.lastConnectedDevice?.name ?? "device"}',
            style: GoogleFonts.inter(fontSize: 13),
          ),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final btStatusAsync = ref.watch(btStatusProvider);

    final isDisconnected = btStatusAsync.when(
      data: (s) => s == BtStatus.disconnected,
      loading: () => false,
      error: (_, __) => false,
    );

    final isConnecting = btStatusAsync.when(
      data: (s) => s == BtStatus.connecting,
      loading: () => false,
      error: (_, __) => false,
    );

    // Don't show on the connection screen itself
    final currentRoute = GoRouterState.of(context).uri.toString();
    final isOnConnectionScreen =
        currentRoute == '/connect' || currentRoute == '/splash';

    final showBanner =
        (isDisconnected || isConnecting || _isReconnecting) &&
        !isOnConnectionScreen;

    return Column(
      children: [
        if (showBanner)
          _buildReconnectBanner(isConnecting || _isReconnecting),
        Expanded(child: widget.child),
      ],
    );
  }

  Widget _buildReconnectBanner(bool connecting) {
    final bt = ref.read(btProvider);
    final deviceName = bt.lastConnectedDevice?.name ?? 'ESP32';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: connecting
            ? const Color(0xFFFFB300).withAlpha(25)
            : Colors.red.withAlpha(25),
        border: Border(
          bottom: BorderSide(
            color: connecting
                ? const Color(0xFFFFB300).withAlpha(60)
                : Colors.red.withAlpha(60),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Status icon
            if (connecting)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Icon(
                  Icons.bluetooth_searching,
                  size: 20,
                  color: Color.lerp(
                    const Color(0xFFFFB300).withAlpha(100),
                    const Color(0xFFFFB300),
                    _pulseController.value,
                  ),
                ),
              )
            else
              const Icon(Icons.bluetooth_disabled, size: 20, color: Colors.red),

            const SizedBox(width: 10),

            // Message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    connecting ? 'Reconnecting…' : 'Disconnected',
                    style: GoogleFonts.inter(
                      color: connecting
                          ? const Color(0xFFFFB300)
                          : Colors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    connecting
                        ? 'Connecting to $deviceName'
                        : 'Lost connection to $deviceName',
                    style: GoogleFonts.inter(
                      color: Colors.white.withAlpha(120),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Reconnect / Switch device buttons
            if (!connecting) ...[
              TextButton(
                onPressed: () => context.go('/connect'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(
                  'Switch',
                  style: GoogleFonts.inter(
                    color: Colors.white.withAlpha(130),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: _reconnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Reconnect',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
