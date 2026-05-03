import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/live_data.dart';
import '../providers/full_analysis_provider.dart';
import '../providers/history_provider.dart';
import '../providers/sound_provider.dart';
import '../services/sound_service.dart';
import '../utils/number_format.dart' as nf;

class CombinedResultScreen extends ConsumerStatefulWidget {
  const CombinedResultScreen({super.key});

  @override
  ConsumerState<CombinedResultScreen> createState() => _CombinedResultScreenState();
}

class _CombinedResultScreenState extends ConsumerState<CombinedResultScreen> {
  bool _soundPlayed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playResultSound();
    });
  }

  void _playResultSound() {
    if (_soundPlayed) return;
    _soundPlayed = true;

    final state = ref.read(fullAnalysisProvider);
    final sound = ref.read(soundServiceProvider);

    if (state.purity != null && state.density != null) {
      final bothGold = state.density!.metalLabel.toLowerCase() == 'gold' &&
          state.purity!.outcome == PurityOutcome.gold;
      final bothNotGold = state.density!.metalLabel.toLowerCase() != 'gold' &&
          state.purity!.outcome != PurityOutcome.gold;

      if (bothGold) {
        if (state.purity!.karat == 24) {
          sound.play(SoundEffect.chime24k);
        } else {
          sound.play(SoundEffect.chimeGold);
        }
      } else if (bothNotGold) {
        sound.play(SoundEffect.beepNotGold);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fullAnalysisProvider);

    if (state.density == null || state.purity == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Center(
          child: Text(
            'No results available',
            style: GoogleFonts.inter(color: Colors.white54),
          ),
        ),
      );
    }

    final density = state.density!;
    final purity = state.purity!;

    final densityIsGold = density.metalLabel.toLowerCase() == 'gold';
    final purityIsGold = purity.outcome == PurityOutcome.gold;
    final bothGold = densityIsGold && purityIsGold;
    final bothNotGold = !densityIsGold && !purityIsGold;
    final inconsistent = densityIsGold != purityIsGold;

    final verdictColor = bothGold
        ? Colors.green
        : inconsistent
            ? const Color(0xFFFFB300)
            : Colors.red;
    final verdictText = bothGold
        ? 'Both tests confirm gold. Readings are consistent.'
        : densityIsGold && !purityIsGold
            ? 'Inconsistent — possible gold plating detected.'
            : !densityIsGold && purityIsGold
                ? 'Inconsistent — possible hollow or composite sample.'
                : 'Not gold confirmed by both methods.';

    final verdictLabel = bothGold
        ? '${purity.karat}k Gold (${nf.NumberFormat.formatPercent(purity.purityPercent ?? 0)}% purity)'
        : bothNotGold
            ? 'Not Gold'
            : 'Inconsistent';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: Text(
          'Full Analysis',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            const SizedBox(height: 8),
            Text(
              '🏆',
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(height: 12),
            Text(
              'Full Analysis Complete',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),

            // Two result cards side by side
            Row(
              children: [
                Expanded(
                  child: _ResultBox(
                    icon: '⚖️',
                    title: 'Density',
                    value: '${nf.NumberFormat.formatDensity(density.density)} g/cm³',
                    label: density.metalLabel,
                    isGold: densityIsGold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ResultBox(
                    icon: '🔬',
                    title: 'Purity',
                    value: 'ADC: ${nf.NumberFormat.formatADC(purity.meanADC)}',
                    label: purityIsGold
                        ? '${purity.karat}k Gold'
                        : purity.detectedMetal?.metal.metalName ?? 'Not Gold',
                    isGold: purityIsGold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Verdict card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: verdictColor.withAlpha(120), width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    'VERDICT',
                    style: GoogleFonts.inter(
                      color: Colors.white.withAlpha(130),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: verdictColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          bothGold ? Icons.check_circle : inconsistent ? Icons.warning : Icons.cancel,
                          color: verdictColor,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          verdictLabel,
                          style: GoogleFonts.inter(
                            color: verdictColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    verdictText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white.withAlpha(150),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _saveReport(),
                      child: Text(
                        'Save Full Report',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {
                        ref.read(fullAnalysisProvider.notifier).reset();
                        context.go('/home');
                      },
                      child: Text(
                        'Start New Test',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _saveReport() {
    final state = ref.read(fullAnalysisProvider);
    if (state.density != null && state.purity != null) {
      ref.read(historyProvider.notifier).addEntry(
        'fullAnalysis',
        _buildLabel(state),
        FullAnalysisResult(
          density: state.density!,
          purity: state.purity!,
          verdict: 'Full Analysis',
          timestamp: DateTime.now(),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full report saved to history')),
      );
    }
  }

  String _buildLabel(FullAnalysisState state) {
    final purity = state.purity!;
    if (purity.outcome == PurityOutcome.gold) {
      return 'Full Analysis — ${purity.karat}k Gold — ${DateTime.now()}';
    }
    return 'Full Analysis — ${purity.detectedMetal?.metal.metalName ?? 'Unknown'} — ${DateTime.now()}';
  }
}

class _ResultBox extends StatelessWidget {
  final String icon;
  final String title;
  final String value;
  final String label;
  final bool isGold;

  const _ResultBox({
    required this.icon,
    required this.title,
    required this.value,
    required this.label,
    required this.isGold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.white.withAlpha(150),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: isGold ? const Color(0xFFFFB300) : Colors.white.withAlpha(130),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              if (isGold)
                const Icon(Icons.check_circle, color: Color(0xFFFFB300), size: 14),
            ],
          ),
        ],
      ),
    );
  }
}
