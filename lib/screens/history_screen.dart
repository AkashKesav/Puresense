import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import '../providers/history_provider.dart';
import '../widgets/live_data_bar.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);

    final filtered = _filter == 'All'
        ? history
        : history.where((e) {
            if (_filter == 'Full Analysis') return e.type == 'full';
            if (_filter == 'Density') return e.type == 'density';
            if (_filter == 'Purity') return e.type == 'purity';
            if (_filter == 'Metal ID') return e.type == 'metalId';
            return true;
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'History',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _exportCSV(history),
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Export CSV', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['All', 'Full Analysis', 'Density', 'Purity', 'Metal ID'].map((f) {
                final selected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = f),
                    backgroundColor: const Color(0xFF222222),
                    selectedColor: const Color(0xFFFFB300),
                    labelStyle: TextStyle(
                      color: selected ? Colors.black : Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text(
                          'No history yet',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      return Dismissible(
                        key: Key(entry.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          ref.read(historyProvider.notifier).deleteEntry(entry.id);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF222222),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ExpansionTile(
                            title: Text(
                              entry.label,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              DateFormat('MMM d, yyyy HH:mm').format(entry.timestamp),
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Text(
                                  entry.result.toString(),
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const LiveDataBar(),
        ],
      ),
    );
  }

  Future<void> _exportCSV(List<dynamic> entries) async {
    final rows = <List<String>>[
      ['ID', 'Type', 'Label', 'Result', 'Timestamp'],
    ];
    for (final entry in entries) {
      rows.add([
        entry.id,
        entry.type,
        entry.label,
        entry.result.toString(),
        DateFormat('yyyy-MM-dd HH:mm:ss').format(entry.timestamp),
      ]);
    }
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/puresense_history.csv');
    await file.writeAsString(csv);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to ${file.path}')),
      );
    }
  }
}
