import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/bt_provider.dart';
import '../providers/full_analysis_provider.dart';
import '../widgets/bt_status_chip.dart';
import '../widgets/live_data_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Pure Black background
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', height: 24, width: 24),
            const SizedBox(width: 10),
            Text(
              'PureSense',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: BtStatusChip(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Navigation Menu moved out of AppBar to prevent overflow
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withAlpha(20)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _NavMenuButton(
                          icon: Icons.science_outlined,
                          label: 'Metals',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push('/metals');
                          },
                        ),
                        Container(width: 1, height: 24, color: Colors.white.withAlpha(20)),
                        _NavMenuButton(
                          icon: Icons.history,
                          label: 'History',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push('/history');
                          },
                        ),
                        Container(width: 1, height: 24, color: Colors.white.withAlpha(20)),
                        _NavMenuButton(
                          icon: Icons.settings_outlined,
                          label: 'Settings',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push('/settings');
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Select Test Mode',
                    style: GoogleFonts.inter(
                      color: Colors.white.withAlpha(160),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _TestCard(
                    icon: Icons.workspace_premium,
                    title: 'Full Analysis',
                    badge: 'RECOMMENDED',
                    description: 'Density + Purity combined',
                    gradientColors: [
                      const Color(0xFFFFB300).withAlpha(20),
                      const Color(0xFFFFB300).withAlpha(5),
                    ],
                    borderColor: const Color(0xFFFFB300).withAlpha(80),
                    iconColor: const Color(0xFFFFB300),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      ref.read(fullAnalysisProvider.notifier).startFullAnalysis();
                      context.push('/density?mode=fullAnalysis');
                    },
                  ),
                  const SizedBox(height: 12),

                  _TestCard(
                    icon: Icons.scale_outlined,
                    title: 'Density Test',
                    description: 'Archimedes principle (HX711)',
                    gradientColors: [
                      Colors.white.withAlpha(8),
                      Colors.transparent,
                    ],
                    borderColor: Colors.white.withAlpha(20),
                    iconColor: const Color(0xFF4FC3F7),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/density?mode=standalone');
                    },
                  ),
                  const SizedBox(height: 12),

                  _TestCard(
                    icon: Icons.electric_bolt_outlined,
                    title: 'Purity Test',
                    description: 'Electrochemical sensor (ADS1115)',
                    gradientColors: [
                      Colors.white.withAlpha(8),
                      Colors.transparent,
                    ],
                    borderColor: Colors.white.withAlpha(20),
                    iconColor: const Color(0xFFFFB300),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/purity?mode=standalone');
                    },
                  ),
                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      'Quick Actions',
                      style: GoogleFonts.inter(
                        color: Colors.white.withAlpha(120),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  _QuickActionCard(
                    icon: Icons.exposure_zero,
                    title: 'Tare Scale',
                    description: 'Zero the load cell sensor',
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      ref.read(btProvider).zeroScale();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Tare command sent',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          backgroundColor: const Color(0xFF222222),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          const LiveDataBar(),
        ],
      ),
    );
  }
}

class _NavMenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavMenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withAlpha(200), size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white.withAlpha(180),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? badge;
  final String description;
  final List<Color> gradientColors;
  final Color borderColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _TestCard({
    required this.icon,
    required this.title,
    this.badge,
    required this.description,
    required this.gradientColors,
    required this.borderColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_TestCard> createState() => _TestCardState();
}

class _TestCardState extends State<_TestCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _pressed = true);
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradientColors,
            ),
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.borderColor, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.iconColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.iconColor,
                  size: 24,
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
                            widget.title,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16, // Reduced font size
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB300).withAlpha(30),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.badge!,
                              style: GoogleFonts.inter(
                                color: const Color(0xFFFFB300),
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: GoogleFonts.inter(
                        color: Colors.white.withAlpha(140),
                        fontSize: 12, // Reduced font size
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withAlpha(60),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _pressed = true);
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withAlpha(15),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.icon,
                  color: Colors.white.withAlpha(200),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14, // Reduced font size
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.description,
                      style: GoogleFonts.inter(
                        color: Colors.white.withAlpha(120),
                        fontSize: 11, // Reduced font size
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

