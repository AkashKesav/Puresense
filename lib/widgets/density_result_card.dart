import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/live_data.dart';
import '../providers/history_provider.dart';
import '../utils/number_format.dart' as nf;

class DensityResultCard extends ConsumerWidget {
  final DensityResult result;
  final bool showSave;
  const DensityResultCard({super.key, required this.result, this.showSave = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB300).withAlpha(80), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Density Result',
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(130),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${nf.NumberFormat.formatDensity(result.density)} g/cm³',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withAlpha(15),
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
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getReferenceRange(result.metalLabel),
                        style: GoogleFonts.inter(
                          color: Colors.white.withAlpha(120),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: Color(0xFFFFB300), size: 28),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withAlpha(15)),
          const SizedBox(height: 12),
          _buildDetailRow('Air weight:', '${nf.NumberFormat.formatWeight(result.wAir)} g'),
          _buildDetailRow('Water baseline:', '${nf.NumberFormat.formatWeight(result.wWater)} g'),
          _buildDetailRow('Submerged:', '${nf.NumberFormat.formatWeight(result.wSubmerged)} g'),
          _buildDetailRow('Buoyancy force:', '${nf.NumberFormat.formatWeight(result.buoyancy)} g'),
          const SizedBox(height: 20),
          if (showSave)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _saveResult(ref, context),
                child: Text(
                  'Save Result',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                ),
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
          Text(
            label,
            style: GoogleFonts.inter(color: Colors.white.withAlpha(100), fontSize: 14),
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

  void _saveResult(WidgetRef ref, BuildContext context) {
    final label = 'Density Test — ${result.metalLabel} ${nf.NumberFormat.formatDensity(result.density)} g/cm³';
    ref.read(historyProvider.notifier).addEntry('density', label, result);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Result saved to history')),
    );
  }
}
