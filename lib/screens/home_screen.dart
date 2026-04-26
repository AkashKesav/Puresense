import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/full_analysis_provider.dart';
import '../widgets/bt_status_chip.dart';
import '../widgets/live_data_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: Text(
          'PureSense',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push('/metals'),
            icon: const Icon(Icons.science_outlined, size: 22),
            tooltip: 'Metals Lab',
          ),
          IconButton(
            onPressed: () => context.push('/history'),
            icon: const Icon(Icons.history, size: 22),
            tooltip: 'History',
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: 'Settings',
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: BtStatusChip(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Welcome text
                  Text(
                    'What would you like to test?',
                    style: GoogleFonts.inter(
                      color: Colors.white.withAlpha(160),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Full Analysis Card — RECOMMENDED
                  _TestCard(
                    emoji: '🏆',
                    title: 'Full Analysis',
                    badge: 'RECOMMENDED',
                    description: 'Density + Purity combined\nMost accurate result',
                    ctaText: 'Start Full Analysis →',
                    gradientColors: [
                      const Color(0xFFFFB300).withAlpha(20),
                      const Color(0xFFFFB300).withAlpha(8),
                    ],
                    borderColor: const Color(0xFFFFB300).withAlpha(80),
                    onTap: () {
                      ref.read(fullAnalysisProvider.notifier).startFullAnalysis();
                      context.push('/density?mode=fullAnalysis');
                    },
                  ),

                  const SizedBox(height: 16),

                  // Density Card
                  _TestCard(
                    emoji: '⚖️',
                    title: 'Density Test',
                    description: 'Archimedes principle\nHX711 load cell',
                    ctaText: 'Start →',
                    gradientColors: [
                      Colors.white.withAlpha(8),
                      Colors.transparent,
                    ],
                    borderColor: Colors.white.withAlpha(20),
                    onTap: () => context.push('/density?mode=standalone'),
                  ),

                  const SizedBox(height: 16),

                  // Purity Card
                  _TestCard(
                    emoji: '🔬',
                    title: 'Purity Test',
                    description: 'Electrochemical sensor\nADS1115',
                    ctaText: 'Start →',
                    gradientColors: [
                      Colors.white.withAlpha(8),
                      Colors.transparent,
                    ],
                    borderColor: Colors.white.withAlpha(20),
                    onTap: () => context.push('/purity?mode=standalone'),
                  ),

                  const SizedBox(height: 32),
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

class _TestCard extends StatefulWidget {
  final String emoji;
  final String title;
  final String? badge;
  final String description;
  final String ctaText;
  final List<Color> gradientColors;
  final Color borderColor;
  final VoidCallback onTap;

  const _TestCard({
    required this.emoji,
    required this.title,
    this.badge,
    required this.description,
    required this.ctaText,
    required this.gradientColors,
    required this.borderColor,
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
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradientColors,
            ),
            color: const Color(0xFF222222),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: widget.borderColor, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(widget.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (widget.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.badge!,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFFB300),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: Text(
                  widget.description,
                  style: GoogleFonts.inter(
                    color: Colors.white.withAlpha(130),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: Text(
                  widget.ctaText,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFFB300),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
