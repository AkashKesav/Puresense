import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/live_data.dart';
import '../providers/full_analysis_provider.dart';
import '../providers/history_provider.dart';
import '../providers/sound_provider.dart';
import '../services/sound_service.dart';

class CombinedResultScreen extends ConsumerWidget {
  const CombinedResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fullAnalysis = ref.watch(fullAnalysisProvider);
    final density = fullAnalysis.densityResult;
    final purity = fullAnalysis.purityResult;

    if (density == null || purity == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Result data is missing',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    }

    // Determine verdict
    final isDensityGold = density.metalLabel.toLowerCase().contains('gold');
    final isPurityGold = purity.outcome == PurityOutcome.gold;
    late String verdict;
    late Color verdictColor;
    late String verdictMessage;

    if (isDensityGold && isPurityGold) {
      verdict = '${purity.karat}k Gold (${purity.purityPercent?.toStringAsFixed(1)}% purity)';
      verdictColor = Colors.green;
      verdictMessage = 'Both tests confirm gold. Readings are consistent.';
      ref.read(soundServiceProvider).play(
        purity.karat == 24 ? SoundEffect.chime24k : SoundEffect.chimeGold,
      );
    } else if (isDensityGold && !isPurityGold) {
      verdict = 'Inconsistent Result';
      verdictColor = const Color(0xFFFFB300);
      verdictMessage = 'Inconsistent — possible gold plating detected.';
    } else if (!isDensityGold && isPurityGold) {
      verdict = 'Inconsistent Result';
      verdictColor = const Color(0xFFFFB300);
      verdictMessage = 'Inconsistent — possible hollow or composite sample.';
    } else {
      verdict = 'Not Gold';
      verdictColor = Colors.red;
      verdictMessage = 'Not gold confirmed by both methods.';
      ref.read(soundServiceProvider).play(SoundEffect.beepNotGold);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'Full Analysis Result',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: verdictColor.withOpacity(0.5), width: 2),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.workspace_premium, color: Color(0xFFFFB300), size: 32),
                      SizedBox(width: 12),
                      Text(
                        'Full Analysis Complete',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Two cards side by side
                  Row(
                    children: [
                      Expanded(
                        child: _buildSubCard(
                          icon: Icons.scale,
                          title: 'Density',
                          value: '${density.density.toStringAsFixed(2)} g/cm³',
                          subtitle: density.metalLabel,
                          color: isDensityGold ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSubCard(
                          icon: Icons.biotech,
                          title: 'Purity',
                          value: purity.karat != null ? '${purity.karat}k Gold' : 'Not Gold',
                          subtitle: purity.meanADC.toString(),
                          color: isPurityGold ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFF333333)),
                  const SizedBox(height: 16),
                  const Text(
                    'VERDICT',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 2),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: verdictColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          verdict,
                          style: TextStyle(
                            color: verdictColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    verdictMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _saveResult(ref, density, purity),
                          child: const Text('Save Full Report'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ref.read(fullAnalysisProvider.notifier).reset();
                            context.go('/home');
                          },
                          child: const Text('Start New Test'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFFB300), size: 18),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                subtitle,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _saveResult(WidgetRef ref, DensityResult density, PurityResult purity) {
    final entry = FullAnalysisResult(
      density: density,
      purity: purity,
      verdict: 'Full Analysis — ${purity.karat}k Gold',
      timestamp: DateTime.now(),
    );
    ref.read(historyProvider.notifier).addEntry('full', entry.historyLabel, entry);
  }
}
