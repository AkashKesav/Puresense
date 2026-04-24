import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/live_data.dart';
import '../providers/bt_provider.dart';
import '../providers/calibration_provider.dart';
import '../providers/full_analysis_provider.dart';
import '../providers/live_data_provider.dart';
import '../providers/purity_test_provider.dart';
import '../providers/settings_provider.dart';
import '../services/bluetooth_service.dart';
import '../services/sound_service.dart';
import '../widgets/bt_status_chip.dart';
import '../widgets/calibration_card.dart';
import '../widgets/live_adc_chart.dart';
import '../widgets/live_data_bar.dart';
import '../widgets/probe_status_badge.dart';
import '../widgets/purity_result_card.dart';
import '../widgets/range_ladder.dart';

class PurityTestScreen extends ConsumerStatefulWidget {
  final String? mode;
  const PurityTestScreen({super.key, this.mode});

  @override
  ConsumerState<PurityTestScreen> createState() => _PurityTestScreenState();
}

class _PurityTestScreenState extends ConsumerState<PurityTestScreen> {
  bool _showGoldTiers = true;
  bool _calibrationExpanded = false;
  StreamSubscription<String>? _linesSubscription;

  @override
  void initState() {
    super.initState();
    _listenToLines();
  }

  void _listenToLines() {
    final bt = ref.read(btProvider);
    _linesSubscription?.cancel();
    _linesSubscription = bt.linesStream.listen((line) {
      final outcome = _parsePurityOutcome(line);
      if (outcome != null) {
        ref.read(purityTestProvider.notifier).parseAndComplete(line);
        return;
      }
      final mean = _parseMeanADC(line);
      if (mean != null && ref.read(purityTestProvider).isCalibrating) {
        ref.read(purityTestProvider.notifier).onCalibrationMean(mean);
        return;
      }
      final error = _parseErrorMessage(line);
      if (error != null) {
        ref.read(purityTestProvider.notifier).setError(error);
        return;
      }
      final samples = _parseSamples(line);
      if (samples != null) {
        ref.read(purityTestProvider.notifier).onTestProgress(samples);
      }
    });
  }

  @override
  void dispose() {
    _linesSubscription?.cancel();
    super.dispose();
  }

  PurityOutcome? _parsePurityOutcome(String line) {
    if (line.contains('>>> GOLD')) return PurityOutcome.gold;
    if (line.contains('>>> NOT GOLD')) return PurityOutcome.notGold;
    if (line.contains('>>> ERROR: PROBE IN AIR')) return PurityOutcome.probeInAir;
    return null;
  }

  int? _parseMeanADC(String line) {
    final regex = RegExp(r'Mean\s*:\s*(\d+)');
    final match = regex.firstMatch(line);
    if (match != null) return int.tryParse(match.group(1)!);
    return null;
  }

  String? _parseErrorMessage(String line) {
    final regex = RegExp(r'ERROR:\s*(.+)');
    final match = regex.firstMatch(line);
    if (match != null) return match.group(1)!.trim();
    return null;
  }

  int? _parseSamples(String line) {
    final regex = RegExp(r'Samples collected:\s*(\d+)');
    final match = regex.firstMatch(line);
    if (match != null) return int.tryParse(match.group(1)!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final purityState = ref.watch(purityTestProvider);
    final fullAnalysis = ref.watch(fullAnalysisProvider);
    final settings = ref.watch(settingsProvider);
    final isFullAnalysis = widget.mode == 'fullAnalysis' || fullAnalysis.isFullAnalysisMode;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: Text(
          isFullAnalysis ? 'Full Analysis — Step 2 of 2: Purity' : 'Purity Test',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 16), child: BtStatusChip()),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CalibrationCard(),
                      const SizedBox(height: 8),
                      // Toggle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: true, label: Text('Gold Tiers')),
                            ButtonSegment(value: false, label: Text('All Metals')),
                          ],
                          selected: {_showGoldTiers},
                          onSelectionChanged: (v) => setState(() => _showGoldTiers = v.first),
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.resolveWith((states) {
                              if (states.contains(MaterialState.selected)) {
                                return const Color(0xFFFFB300);
                              }
                              return const Color(0xFF222222);
                            }),
                            foregroundColor: MaterialStateProperty.resolveWith((states) {
                              if (states.contains(MaterialState.selected)) {
                                return Colors.black;
                              }
                              return Colors.white70;
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      RangeLadder(showGoldOnly: _showGoldTiers),
                      if (settings.showLiveChart) ...[
                        const SizedBox(height: 16),
                        const LiveADCChart(),
                      ],
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
              const LiveDataBar(),
            ],
          ),
          // Test overlay
          if (purityState.isTesting)
            _buildTestOverlay(purityState),
          // Probe in air warning
          if (_isProbeInAir())
            _buildProbeInAirOverlay(),
          // Result card
          if (purityState.result != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: SingleChildScrollView(
                    child: purityState.result != null
                        ? PurityResultCard(
                            result: purityState.result!,
                            isFullAnalysis: isFullAnalysis,
                            onContinue: () {
                              ref.read(fullAnalysisProvider.notifier).setPurityResult(purityState.result!);
                              context.push('/combined-result');
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: purityState.result == null && !purityState.isTesting
          ? FloatingActionButton.extended(
              onPressed: () {
                ref.read(purityTestProvider.notifier).startTest();
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Test Sample'),
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: Colors.black,
            )
          : null,
    );
  }

  bool _isProbeInAir() {
    final live = ref.watch(liveDataProvider);
    return live.when(
      data: (d) => d.adcValue > 18000 && !ref.read(purityTestProvider).isTesting && ref.read(purityTestProvider).result == null,
      loading: () => false,
      error: (_, __) => false,
    );
  }

  Widget _buildTestOverlay(PurityTestState state) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFFB300)),
            const SizedBox(height: 24),
            const Text(
              'Collecting electrochemical readings...',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (state.testProgress != null && state.testProgress! > 0)
              Text(
                '${state.testProgress} samples collected',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
              ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => ref.read(purityTestProvider.notifier).cancelTest(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProbeInAirOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: const Color(0xFFFFB300).withOpacity(0.9),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.black, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Probe is in air — place on sample',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
