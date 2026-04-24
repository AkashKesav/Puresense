import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_data.dart';
import '../providers/density_test_provider.dart';
import '../providers/history_provider.dart';

class DensityResultCard extends ConsumerWidget {
  final DensityResult result;
  final bool showSave;
  const DensityResultCard({super.key, required this.result, this.showSave = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            'Density Result',
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.density.toStringAsFixed(2)} g/cm³',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFB300),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.metalLabel.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getReferenceRange(result.metalLabel),
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: Color(0xFFFFB300), size: 28),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF333333)),
          const SizedBox(height: 12),
          _buildDetailRow('Air weight:', '${result.wAir.toStringAsFixed(2)} g'),
          _buildDetailRow('Water baseline:', '${result.wWater.toStringAsFixed(2)} g'),
          _buildDetailRow('Submerged:', '${result.wSubmerged.toStringAsFixed(2)} g'),
          _buildDetailRow('Buoyancy force:', '${result.buoyancy.toStringAsFixed(2)} g'),
          const SizedBox(height: 20),
          if (showSave)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _saveResult(ref),
                child: const Text('Save Result'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
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

  String _getReferenceRange(String label) {
    switch (label.toLowerCase()) {
      case 'gold':
        return 'Reference range: 18.5 – 20.0 g/cm³';
      case 'silver/lead':
        return 'Reference range: 10.0 – 11.5 g/cm³';
      case 'steel/iron':
        return 'Reference range: 7.5 – 8.2 g/cm³';
      case 'copper/brass':
        return 'Reference range: 8.3 – 9.0 g/cm³';
      case 'aluminum':
        return 'Reference range: 2.5 – 2.9 g/cm³';
      case 'floats':
        return 'Reference range: < 1.0 g/cm³';
      default:
        return 'No reference range available';
    }
  }

  void _saveResult(WidgetRef ref) {
    ref.read(historyProvider.notifier).addEntry('density', result.historyLabel, result);
  }
}
