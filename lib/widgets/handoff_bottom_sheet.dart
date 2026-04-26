import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../utils/number_format.dart' as nf;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 24),
              const SizedBox(width: 10),
              Text(
                'Density Test Complete',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${nf.NumberFormat.formatDensity(density)} g/cm³  →  $metalLabel',
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(150),
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 20),
          Divider(color: Colors.white.withAlpha(15)),
          const SizedBox(height: 20),

          Row(
            children: [
              const Text('🔬', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue to Purity Test',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Confirm karat purity with the electrochemical sensor for a complete analysis.',
                      style: GoogleFonts.inter(
                        color: Colors.white.withAlpha(120),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/purity?mode=fullAnalysis');
                    },
                    child: Text(
                      'Continue →',
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
                      Navigator.pop(context);
                      context.go('/home');
                    },
                    child: Text(
                      'Skip & Finish',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
