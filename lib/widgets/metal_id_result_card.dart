import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_data.dart';
import '../providers/history_provider.dart';

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
    if (result.matches.isEmpty || result.matches.first.confidence < 40) {
      return _buildUnknownResult(context, ref);
    }

    if (isSingleTest && targetMetal != null) {
      return _buildSingleTestResult(context, ref);
    }

    return _buildMultiMatchResult(context, ref);
  }

  Widget _buildMultiMatchResult(BuildContext context, WidgetRef ref) {
    final best = result.matches.first;

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
          const Text(
            'Identification Complete',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Text(
            'ADC Reading: ${result.meanADC}',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: best.metal.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BEST MATCH',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
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
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Confidence: ${best.confidence.toStringAsFixed(0)}%',
                  style: const TextStyle(color: Color(0xFFFFB300), fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  'ADC Range: ${best.metal.min.toStringAsFixed(0)} – ${best.metal.max.toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                ),
              ],
            ),
          ),
          if (result.matches.length > 1) ...[
            const SizedBox(height: 16),
            Text(
              'Other possible matches:',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
            ),
            const SizedBox(height: 8),
            ...result.matches.skip(1).take(3).map((m) => Padding(
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
                  Text(m.metal.metalName, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  const Spacer(),
                  Text('${m.confidence.toStringAsFixed(0)}% confidence',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                ],
              ),
            )),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onTestAgain,
                  child: const Text('Test Again', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _saveResult(ref),
                  child: const Text('Save', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              if (onRunFullAnalysis != null)
                Expanded(
                  child: ElevatedButton(
                    onPressed: onRunFullAnalysis,
                    child: const Text('Full Analysis', style: TextStyle(fontSize: 12)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleTestResult(BuildContext context, WidgetRef ref) {
    final match = result.matches.isNotEmpty ? result.matches.first : null;
    final isMatch = match != null && match.confidence >= 40;
    final deviation = isMatch ? (result.meanADC - targetMetal!.expectedADC).toInt() : 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMatch ? const Color(0xFFFFB300).withOpacity(0.5) : Colors.red.withOpacity(0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Testing against: ${targetMetal!.metalName}',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildResultRow('ADC Reading:', result.meanADC.toString()),
          _buildResultRow('Expected:', '${targetMetal!.expectedADC.toStringAsFixed(0)} (±${((targetMetal!.max - targetMetal!.min) / 2).toStringAsFixed(0)})'),
          if (isMatch)
            _buildResultRow('Deviation:', '${deviation >= 0 ? '+' : ''}$deviation ADC'),
          const SizedBox(height: 16),
          if (isMatch) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
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
                          'MATCH — ${match!.confidence.toStringAsFixed(0)}% confidence',
                          style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Consistent with ${targetMetal!.metalName}.',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
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
                color: Colors.red.withOpacity(0.15),
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
                          'NO MATCH — signal too low for ${targetMetal!.metalName}',
                          style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  if (result.matches.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Closest match: ${result.matches.first.metal.metalName} (${result.matches.first.confidence.toStringAsFixed(0)}% confidence)',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
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
                  child: const Text('Test Another', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onTestAgain,
                  child: const Text('Identify All', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _saveResult(ref),
                  child: const Text('Save', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Unknown Metal or Alloy',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Signal does not match any known reference.',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
          ),
          if (result.meanADC < 500)
            Text(
              'No signal detected — check probe contact.',
              style: TextStyle(color: Colors.red.withOpacity(0.8), fontSize: 13),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onTestAgain,
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

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _saveResult(WidgetRef ref) {
    ref.read(historyProvider.notifier).addEntry('metalId', result.historyLabel, result);
  }
}
