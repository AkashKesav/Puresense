import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/full_analysis_provider.dart';
import '../widgets/bt_status_chip.dart';
import '../widgets/live_data_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'PureSense',
          style: TextStyle(
            color: Color(0xFFFFB300),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.science, color: Colors.white70),
            onPressed: () => context.push('/metals'),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white70),
            onPressed: () => context.push('/history'),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () => context.push('/settings'),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: BtStatusChip(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Full Analysis Card
                  _buildCard(
                    icon: Icons.workspace_premium,
                    title: 'Full Analysis',
                    subtitle: 'Density + Purity combined',
                    description: 'Most accurate result',
                    badge: 'RECOMMENDED',
                    badgeColor: const Color(0xFFFFB300),
                    onTap: () {
                      ref.read(fullAnalysisProvider.notifier).startFullAnalysis();
                      context.push('/density?mode=fullAnalysis');
                    },
                  ),
                  const SizedBox(height: 16),
                  // Density Test Card
                  _buildCard(
                    icon: Icons.scale,
                    title: 'Density Test',
                    subtitle: 'Archimedes principle',
                    description: 'HX711 load cell',
                    onTap: () => context.push('/density?mode=standalone'),
                  ),
                  const SizedBox(height: 16),
                  // Purity Test Card
                  _buildCard(
                    icon: Icons.biotech,
                    title: 'Purity Test',
                    subtitle: 'Electrochemical sensor',
                    description: 'ADS1115',
                    onTap: () => context.push('/purity?mode=standalone'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          const LiveDataBar(),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF222222),
              const Color(0xFF2A2A2A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFFFFB300), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? const Color(0xFFFFB300)).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: badgeColor ?? const Color(0xFFFFB300),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Start',
                  style: TextStyle(
                    color: const Color(0xFFFFB300).withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Icons.arrow_forward, color: const Color(0xFFFFB300).withOpacity(0.8), size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
