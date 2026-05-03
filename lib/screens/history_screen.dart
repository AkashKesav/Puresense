import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/history_provider.dart';
import '../models/live_data.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _filter = 'All';
  final _filters = ['All', 'Full Analysis', 'Density', 'Purity', 'Metal ID'];

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(historyProvider);
    final filtered = _filter == 'All'
        ? entries
        : entries.where((e) {
            switch (_filter) {
              case 'Full Analysis': return e.type == 'fullAnalysis';
              case 'Density': return e.type == 'density';
              case 'Purity': return e.type == 'purity';
              case 'Metal ID': return e.type == 'metalId';
              default: return true;
            }
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: Text(
          'History',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (entries.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _exportCSV(entries);
              },
              icon: const Icon(Icons.download, size: 18),
              label: Text(
                'CSV',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isActive = _filter == filter;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _filter = filter);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFFFB300).withAlpha(25)
                          : const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFFFFB300)
                            : Colors.white.withAlpha(20),
                      ),
                    ),
                    child: Text(
                      filter,
                      style: GoogleFonts.inter(
                        color: isActive
                            ? const Color(0xFFFFB300)
                            : Colors.white.withAlpha(130),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Entries list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history,
                            size: 48, color: Colors.white.withAlpha(40)),
                        const SizedBox(height: 16),
                        Text(
                          'No test results yet',
                          style: GoogleFonts.inter(
                            color: Colors.white.withAlpha(100),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Complete a test to see it here',
                          style: GoogleFonts.inter(
                            color: Colors.white.withAlpha(60),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = filtered[filtered.length - 1 - index];
                      return Dismissible(
                        key: ValueKey(entry.timestamp),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(40),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.delete, color: Colors.red),
                        ),
                        onDismissed: (_) {
                          ref.read(historyProvider.notifier).deleteEntry(entry.id);
                        },
                        child: _HistoryCard(entry: entry),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _exportCSV(List<HistoryEntry> entries) async {
    try {
      final path = await ref.read(historyProvider.notifier).exportToCsv();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}

class _HistoryCard extends StatelessWidget {
  final dynamic entry;
  const _HistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final iconMap = {
      'fullAnalysis': '🏆',
      'density': '⚖️',
      'purity': '🔬',
      'metalId': '🔬',
    };

    final colorMap = {
      'fullAnalysis': const Color(0xFFFFB300),
      'density': Colors.blue,
      'purity': Colors.green,
      'metalId': Colors.purple,
    };

    final emoji = iconMap[entry.type] ?? '📊';
    final accent = colorMap[entry.type] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label ?? entry.type ?? 'Result',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(entry.timestamp),
                  style: GoogleFonts.inter(
                    color: Colors.white.withAlpha(80),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 20, color: Colors.white.withAlpha(40)),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime ts) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[ts.month - 1]} ${ts.day}, ${ts.year}  ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
  }
}
