import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HandoffBottomSheet extends StatelessWidget {
  final double density;
  final String metalLabel;

  const HandoffBottomSheet({
    super.key,
    required this.density,
    required this.metalLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Density Test Complete',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${density.toStringAsFixed(2)} g/cm³ → $metalLabel',
              style: const TextStyle(color: Color(0xFFFFB300), fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Divider(color: Color(0xFF333333), height: 32),
            const Text(
              'Continue to Purity Test',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Confirm karat purity with the electrochemical sensor for a complete analysis.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Skip & Finish'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/purity?mode=fullAnalysis');
                    },
                    child: const Text('Continue →'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
