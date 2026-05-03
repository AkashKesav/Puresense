import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/live_data.dart';
import '../providers/history_provider.dart';
import '../utils/number_format.dart' as nf;

class MetalIdResultCard extends ConsumerWidget {
  final MetalIdentificationResult result;
  final bool isSingleTest;
  final MetalRange? targetMetal;
  final VoidCallback? onTestAgain;
  final VoidCallback? onRunFullAnalysis;
  final VoidCallback? onTestAnotherMetal;

  const MetalIdResultCard({
    super.key,
    required this.result,
    this.isSingleTest = false,
    this.targetMetal,
    this.onTestAgain,
    this.onRunFullAnalysis,
    this.onTestAnotherMetal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (result.matches.isEmpty || result.meanADC > 15000) {
      return _buildUnknownResult(context, ref);
    }

    if (isSingleTest && targetMetal != null) {
      return _buildSingleTestResult(context, ref);
    }

    return _buildMultiMatchResult(context, ref);
  }

  Widget _buildMultiMatchResult(BuildContext context, WidgetRef ref) {
    final best = result.matches.first;
    final isRangeMatch =
        result.meanADC >= best.metal.min && result.meanADC <= best.metal.max;
    final isConfident = isRangeMatch || best.confidence >= 40;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConfident
              ? const Color(0xFFFFB300).withAlpha(80)
              : Colors.white.withAlpha(50),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science, color: Color(0xFFFFB300), size: 20),
              const SizedBox(width: 10),
              Text(
                'Identification Complete',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'ADC Reading: ${nf.NumberFormat.formatADC(result.meanADC)}',
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(130),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
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
                  isRangeMatch
                      ? 'RANGE MATCH'
                      : (isConfident ? 'BEST MATCH' : 'CLOSEST REFERENCE'),
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
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: best.metal.color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      best.metal.metalName,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Confidence: ${best.confidence.toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    color: isConfident
                        ? const Color(0xFFFFB300)
                        : Colors.white.withAlpha(170),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'ADC Range: ${nf.NumberFormat.formatADCRange(best.metal.min, best.metal.max)}',
                  style: GoogleFonts.inter(
                    color: Colors.white.withAlpha(100),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (!isRangeMatch && !isConfident) ...[
            const SizedBox(height: 10),
            Text(
              'Low confidence reading. Sample may be an alloy or outside saved reference ranges.',
              style: GoogleFonts.inter(
                color: Colors.white.withAlpha(120),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          if (result.matches.length > 1) ...[
            const SizedBox(height: 16),
            Text(
              'Other possible matches:',
              style: GoogleFonts.inter(
                color: Colors.white.withAlpha(120),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            ...result.matches.skip(1).take(3).map(
                  (m) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
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
                            color: Colors.white,
                            fontSize: 13,
                          ),
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
                  ),
                ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onTestAgain,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Test Again',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _saveResult(ref, context),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Save',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              if (onRunFullAnalysis != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onRunFullAnalysis,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Full Analysis',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleTestResult(BuildContext context, WidgetRef ref) {
    final target = targetMetal!;
    final targetMatch = _findMatchByName(target.metalName);
    final closest = result.matches.isNotEmpty ? result.matches.first : null;
    final inTargetRange =
        result.meanADC >= target.min && result.meanADC <= target.max;
    final isMatch =
        inTargetRange || (targetMatch != null && targetMatch.confidence >= 40);
    final deviation = (result.meanADC - target.expectedADC).toInt();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMatch
              ? const Color(0xFFFFB300).withAlpha(80)
              : Colors.red.withAlpha(80),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Testing against: ${target.metalName}',
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(130),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          _buildResultRow(
              'ADC Reading:', nf.NumberFormat.formatADC(result.meanADC)),
          _buildResultRow(
            'Expected:',
            '${nf.NumberFormat.formatADC(target.expectedADC.toInt())} (+/-${((target.max - target.min) / 2).toStringAsFixed(0)})',
          ),
          _buildResultRow(
            'Deviation:',
            '${deviation >= 0 ? '+' : ''}$deviation ADC',
          ),
          const SizedBox(height: 16),
          if (isMatch) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inTargetRange
                              ? 'MATCH - within saved ADC range'
                              : 'MATCH - ${targetMatch?.confidence.toStringAsFixed(0) ?? '40'}% confidence',
                          style: GoogleFonts.inter(
                            color: Colors.green,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Consistent with ${target.metalName}.',
                          style: GoogleFonts.inter(
                            color: Colors.white.withAlpha(130),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cancel, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'NO MATCH - signal is not close to ${target.metalName}',
                          style: GoogleFonts.inter(
                            color: Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (closest != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Closest match: ${closest.metal.metalName} (${closest.confidence.toStringAsFixed(0)}% confidence)',
                      style: GoogleFonts.inter(
                        color: Colors.white.withAlpha(130),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onTestAnotherMetal,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Test Another',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onTestAgain,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Identify All',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _saveResult(ref, context),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Save',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnknownResult(BuildContext context, WidgetRef ref) {
    final hasProbeContact = result.meanADC <= 15000;
    final closest = result.matches.isNotEmpty ? result.matches.first : null;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasProbeContact ? 'Unknown Metal or Alloy' : 'Probe in Air',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasProbeContact
                ? 'Signal does not strongly match saved references.'
                : 'No sample contact detected. Touch probe to sample and retry.',
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(100),
              fontSize: 14,
            ),
          ),
          if (closest != null && hasProbeContact) ...[
            const SizedBox(height: 8),
            Text(
              'Closest saved reference: ${closest.metal.metalName} (${closest.confidence.toStringAsFixed(0)}%)',
              style: GoogleFonts.inter(
                color: Colors.white.withAlpha(120),
                fontSize: 13,
              ),
            ),
          ],
          if (result.meanADC < 500 && hasProbeContact)
            Text(
              'No signal detected - check probe contact.',
              style: GoogleFonts.inter(
                color: Colors.red.withAlpha(180),
                fontSize: 13,
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onTestAgain,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Test Again',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _saveResult(ref, context),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Save',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(100),
              fontSize: 14,
            ),
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

  MetalMatch? _findMatchByName(String metalName) {
    for (final match in result.matches) {
      if (match.metal.metalName == metalName) return match;
    }
    return null;
  }

  void _saveResult(WidgetRef ref, BuildContext context) {
    final best = result.matches.isNotEmpty ? result.matches.first : null;
    final label = best != null
        ? 'Metal ID - ${best.metal.metalName} (${best.confidence.toStringAsFixed(0)}%)'
        : 'Metal ID - Unknown Metal';

    ref.read(historyProvider.notifier).addEntry('metalId', label, result);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Result saved to history')),
    );
  }
}
