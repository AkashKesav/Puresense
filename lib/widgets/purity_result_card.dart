import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_data.dart';
import '../providers/history_provider.dart';
import '../providers/purity_test_provider.dart';

class PurityResultCard extends ConsumerWidget {
  final PurityResult result;
  final bool isFullAnalysis;
  final VoidCallback? onContinue;

  const PurityResultCard({
    super.key,
    required this.result,
    this.isFullAnalysis = false,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (result.outcome) {
      case PurityOutcome.gold:
        return _buildGoldResult(context, ref);
      case PurityOutcome.notGold:
        return _buildNotGoldResult(context, ref);
      case PurityOutcome.probeInAir:
        return _buildProbeInAirResult(context, ref);
      default:
        return _buildUnknownResult(context, ref);
    }
  }

  Widget _buildGoldResult(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 28),
              const SizedBox(width: 12),
              Text(
                result.karat == 24 ? 'PURE GOLD DETECTED' : 'GOLD DETECTED',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildResultRow('Purity:', '${result.karat}k (${result.purityPercent?.toStringAsFixed(1)}% pure gold)'),
          _buildResultRow('ADC:', result.meanADC.toString()),
          _buildResultRow('Zone:', '${result.karat}k Gold Range'),
          const SizedBox(height: 20),
          const Text(
            'Sample Distribution',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _buildDistributionBar(result.distributionGold, result.distributionLeft, result.distributionRight),
          const SizedBox(height: 20),
          if (isFullAnalysis)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                child: const Text('View Combined Result →'),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ref.read(purityTestProvider.notifier).clearResult(),
                    child: const Text('Test Again'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _saveResult(ref),
                    child: const Text('Save Result'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildNotGoldResult(BuildContext context, WidgetRef ref) {
    final detected = result.detectedMetal;
    final hasGoodMatch = detected != null && detected.confidence >= 40;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cancel, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text(
                'NOT GOLD',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildResultRow('ADC Reading:', result.meanADC.toString()),
          const SizedBox(height: 16),
          if (hasGoodMatch) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: detected.metal.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DETECTED METAL',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: detected.metal.color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        detected.metal.metalName,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Confidence: ${detected.confidence.toStringAsFixed(0)}%',
                    style: const TextStyle(color: Color(0xFFFFB300), fontSize: 14),
                  ),
                  Text(
                    'Expected ADC: ${detected.metal.expectedADC.toStringAsFixed(0)} (±${((detected.metal.max - detected.metal.min) / 2).toStringAsFixed(0)})',
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Text(
              'Unknown metal or alloy',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            Text(
              'Signal does not match any known reference',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
            ),
          ],
          if (result.otherMatches.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Other possible matches:',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
            ),
            const SizedBox(height: 8),
            ...result.otherMatches.take(3).map((m) => Padding(
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
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    '${m.confidence.toStringAsFixed(0)}% confidence',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                ],
              ),
            )),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => ref.read(purityTestProvider.notifier).clearResult(),
                  child: const Text('Test Again'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _saveResult(ref),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProbeInAirResult(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF332200),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB300), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.warning_amber, color: Color(0xFFFFB300), size: 48),
          const SizedBox(height: 12),
          const Text(
            'No sample detected on probe',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Place a metal sample on the probe and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => ref.read(purityTestProvider.notifier).clearResult(),
              child: const Text('Try Again'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnknownResult(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.help_outline, color: Colors.grey, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Unknown Result',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'The test did not produce a clear result.',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => ref.read(purityTestProvider.notifier).clearResult(),
              child: const Text('Test Again'),
            ),
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
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionBar(int gold, int left, int right) {
    final total = gold + left + right;
    if (total == 0) return const SizedBox.shrink();
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              if (left > 0)
                Expanded(
                  flex: left,
                  child: Container(height: 12, color: Colors.red.withOpacity(0.6)),
                ),
              Expanded(
                flex: gold,
                child: Container(height: 12, color: const Color(0xFFFFB300)),
              ),
              if (right > 0)
                Expanded(
                  flex: right,
                  child: Container(height: 12, color: Colors.orange.withOpacity(0.6)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (left > 0)
              Text(
                'Below: $left%',
                style: TextStyle(color: Colors.red.withOpacity(0.8), fontSize: 11),
              ),
            const Spacer(),
            Text(
              'Gold Zone: $gold%',
              style: const TextStyle(color: Color(0xFFFFB300), fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (right > 0)
              Text(
                'Above: $right%',
                style: TextStyle(color: Colors.orange.withOpacity(0.8), fontSize: 11),
              ),
          ],
        ),
      ],
    );
  }

  void _saveResult(WidgetRef ref) {
    ref.read(historyProvider.notifier).addEntry('purity', result.historyLabel, result);
  }
}
