import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/live_data.dart';
import '../models/purity_calculation_method.dart';
import '../providers/history_provider.dart';
import '../providers/sound_provider.dart';
import '../providers/purity_test_provider.dart';
import '../services/sound_service.dart';
import '../utils/number_format.dart' as nf;

class PurityResultCard extends ConsumerStatefulWidget {
  final PurityResult result;
  final bool isFullAnalysis;
  final VoidCallback? onContinue;
  final VoidCallback? onReset;

  const PurityResultCard({
    super.key,
    required this.result,
    this.isFullAnalysis = false,
    this.onContinue,
    this.onReset,
  });

  @override
  ConsumerState<PurityResultCard> createState() => _PurityResultCardState();
}

class _PurityResultCardState extends ConsumerState<PurityResultCard> {
  bool _soundPlayed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playSound());
  }

  void _playSound() {
    if (_soundPlayed) return;
    _soundPlayed = true;
    final sound = ref.read(soundServiceProvider);
    switch (widget.result.outcome) {
      case PurityOutcome.gold:
        if (widget.result.karat == 24) {
          sound.play(SoundEffect.chime24k);
        } else {
          sound.play(SoundEffect.chimeGold);
        }
      case PurityOutcome.notGold:
        sound.play(SoundEffect.beepNotGold);
      case PurityOutcome.probeInAir:
        sound.play(SoundEffect.beepProbeAir);
      case PurityOutcome.unknown:
        sound.play(SoundEffect.beepNotGold);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.result.outcome) {
      case PurityOutcome.gold:
        return _buildGoldResult(context);
      case PurityOutcome.notGold:
        return _buildNotGoldResult(context);
      case PurityOutcome.probeInAir:
        return _buildProbeInAirResult(context);
      case PurityOutcome.unknown:
        return _buildNotGoldResult(context);
    }
  }

  Widget _buildGoldResult(BuildContext context) {
    final r = widget.result;
    final pct =
        r.purityPercent ?? (r.karat != null ? (r.karat! / 24.0) * 100 : 0);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFFFB300).withAlpha(100), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle,
                  color: Color(0xFFFFB300), size: 24),
              const SizedBox(width: 10),
              Text(
                'GOLD DETECTED',
                style: GoogleFonts.inter(
                  color: const Color(0xFFFFB300),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _row('Purity:',
              '${r.karat}k  (${nf.NumberFormat.formatPercent(pct)}% pure gold)'),
          _row('ADC:', nf.NumberFormat.formatADC(r.meanADC)),
          _row('Zone:', '${r.karat}k Gold Range'),
          const SizedBox(height: 20),

          // Distribution bar
          Text(
            'Sample Distribution',
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(130),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildDistributionBar(
              r.distributionGold, r.distributionLeft, r.distributionRight),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Gold Zone: ${r.distributionGold}%',
                style: GoogleFonts.inter(
                    color: const Color(0xFFFFB300), fontSize: 12),
              ),
              const Spacer(),
              Text(
                'Below: ${r.distributionLeft}%    Above: ${r.distributionRight}%',
                style: GoogleFonts.inter(
                    color: Colors.white.withAlpha(80), fontSize: 12),
              ),
            ],
          ),

          // Statistical analysis details (drift-aware methods)
          if (r.statisticalResult != null) _buildStatisticalInfo(r),

          const SizedBox(height: 24),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildNotGoldResult(BuildContext context) {
    final r = widget.result;
    final best = r.detectedMetal;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withAlpha(80), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cancel, color: Colors.grey, size: 24),
              const SizedBox(width: 10),
              Text(
                'NOT GOLD',
                style: GoogleFonts.inter(
                  color: Colors.grey,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _row('ADC Reading:', nf.NumberFormat.formatADC(r.meanADC)),
          const SizedBox(height: 16),

          // Detected metal
          if (best != null && best.confidence >= 40) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: best.metal.color.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DETECTED METAL',
                    style: GoogleFonts.inter(
                      color: Colors.white.withAlpha(130),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: best.metal.color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        best.metal.metalName,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Confidence: ${best.confidence.toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFFB300),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Expected ADC: ${nf.NumberFormat.formatADC(best.metal.expectedADC.toInt())}  (+/-${((best.metal.max - best.metal.min) / 2).toStringAsFixed(0)})',
                    style: GoogleFonts.inter(
                      color: Colors.white.withAlpha(100),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unknown metal or alloy',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.meanADC < 500
                        ? 'No signal - poor probe contact.\nClean the probe tip and try again.'
                        : 'Signal does not match any known reference.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withAlpha(100),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Other matches
          if (r.otherMatches.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Other possible matches:',
              style: GoogleFonts.inter(
                color: Colors.white.withAlpha(120),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            ...r.otherMatches.take(3).map((m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: m.metal.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        m.metal.metalName,
                        style: GoogleFonts.inter(
                            color: Colors.white, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        '${m.confidence.toStringAsFixed(0)}% confidence',
                        style: GoogleFonts.inter(
                          color: Colors.white.withAlpha(80),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          // Statistical analysis details (drift-aware methods)
          if (r.statisticalResult != null) _buildStatisticalInfo(r),

          const SizedBox(height: 24),
          _buildNotGoldActions(context),
        ],
      ),
    );
  }

  Widget _buildProbeInAirResult(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFFFB300).withAlpha(80), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber,
                  color: Color(0xFFFFB300), size: 24),
              const SizedBox(width: 10),
              Text(
                'PROBE IN AIR',
                style: GoogleFonts.inter(
                  color: const Color(0xFFFFB300),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'No sample detected on probe. Place the sample on the sensor and try again.',
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(130),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onReset?.call(),
              child: Text(
                'Try Again',
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionBar(int gold, int left, int right) {
    final total = gold + left + right;
    if (total == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (left > 0)
              Expanded(
                flex: left,
                child: Container(color: Colors.grey.withAlpha(100)),
              ),
            Expanded(
              flex: gold,
              child: Container(color: const Color(0xFFFFB300)),
            ),
            if (right > 0)
              Expanded(
                flex: right,
                child: Container(color: Colors.grey.withAlpha(60)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    if (widget.isFullAnalysis) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: widget.onContinue,
          child: Text(
            'View Combined Result >',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              widget.onReset?.call();
            },
            child: Text(
              'Test Again',
              style:
                  GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _saveResult(),
            child: Text(
              'Save Result',
              style:
                  GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotGoldActions(BuildContext context) {
    if (widget.isFullAnalysis) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: widget.onContinue,
          child: Text(
            'View Combined Result >',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              widget.onReset?.call();
            },
            child: Text(
              'Test Again',
              style:
                  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => context.push('/metals'),
            child: Text(
              'View in Metals Lab',
              style:
                  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _saveResult(),
            child: Text(
              'Save',
              style:
                  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
                color: Colors.white.withAlpha(120), fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the statistical analysis info panel shown for drift-aware methods.
  Widget _buildStatisticalInfo(PurityResult result) {
    final stat = result.statisticalResult!;
    final adc0 = stat.adc0 as double;
    final slope = stat.slope as double;
    final rawMean = stat.rawMean as double;
    final residualStdDev = stat.residualStdDev as double;
    final rSquared = stat.rSquared as double;
    final sampleCount = stat.sampleCount as int;
    final durationSeconds = stat.durationSeconds as double;
    final confidence = stat.confidence as double;

    final driftDirection = slope > 0
        ? '^'
        : slope < 0
            ? 'v'
            : '->';
    final correction = (adc0 - rawMean).abs();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFFFB300).withAlpha(40),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.trending_up,
                      size: 16, color: Color(0xFFFFB300)),
                  const SizedBox(width: 8),
                  Text(
                    'STATISTICAL ANALYSIS',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFFB300),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      result.calculationMethod.shortLabel,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFFB300),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _statRow('ADC0 (de-trended)',
                  nf.NumberFormat.formatADC(adc0.toInt())),
              _statRow('Raw Mean', nf.NumberFormat.formatADC(rawMean.toInt())),
              _statRow('Drift Correction',
                  '$driftDirection ${correction.toStringAsFixed(0)} ADC'),
              _statRow('Slope', '${slope.toStringAsFixed(1)} ADC/sec'),
              _statRow('Signal Noise (sigma)', residualStdDev.toStringAsFixed(1)),
              _statRow('Fit Quality (R^2)',
                  '${(rSquared * 100).toStringAsFixed(1)}%'),
              _statRow('Samples',
                  '$sampleCount in ${durationSeconds.toStringAsFixed(1)}s'),
              _statRow(
                  'Statistical Conf.', '${confidence.toStringAsFixed(0)}%'),
              if (result.calculationMethod ==
                  PurityCalculationMethod.adaptiveStatistical)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Adaptive ranges were derived from this test using mean, slope, and variance.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withAlpha(110),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(90),
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(200),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _saveResult() {
    final r = widget.result;
    String label;
    if (r.outcome == PurityOutcome.gold) {
      label =
          'Purity Test - ${r.karat}k Gold (${nf.NumberFormat.formatPercent(r.purityPercent ?? 0)}%)';
    } else if (r.detectedMetal != null) {
      label =
          'Purity Test - ${r.detectedMetal!.metal.metalName} (${r.detectedMetal!.confidence.toStringAsFixed(0)}%)';
    } else {
      label = 'Purity Test - Unknown Metal';
    }

    ref.read(historyProvider.notifier).addEntry('purity', label, r);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Result saved to history')),
    );
  }
}
