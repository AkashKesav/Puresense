import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/live_data.dart';
import '../providers/bt_provider.dart';
import '../providers/density_test_provider.dart';
import '../providers/full_analysis_provider.dart';
import '../providers/live_data_provider.dart';
import '../providers/sound_provider.dart';
import '../services/bluetooth_service.dart';
import '../services/sound_service.dart';
import '../utils/result_parser.dart';
import '../widgets/bt_status_chip.dart';
import '../widgets/density_reference_table.dart';
import '../widgets/density_result_card.dart';
import '../widgets/density_wizard_step.dart';
import '../widgets/handoff_bottom_sheet.dart';
import '../widgets/live_data_bar.dart';

class DensityTestScreen extends ConsumerStatefulWidget {
  final String? mode;
  const DensityTestScreen({super.key, this.mode});

  @override
  ConsumerState<DensityTestScreen> createState() => _DensityTestScreenState();
}

class _DensityTestScreenState extends ConsumerState<DensityTestScreen> {
  StreamSubscription<String>? _linesSubscription;
  ProviderSubscription<FullAnalysisState>? _fullAnalysisSubscription;

  @override
  void initState() {
    super.initState();
    _listenToLines();
    _fullAnalysisSubscription = ref.listenManual<FullAnalysisState>(
      fullAnalysisProvider,
      (previous, next) {
      if (next.densityResult != null &&
          (previous?.densityResult == null) &&
          next.isFullAnalysisMode) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showModalBottomSheet(
              context: context,
              isDismissible: false,
              enableDrag: false,
              builder: (_) => HandoffBottomSheet(
                density: next.densityResult!.density,
                metalLabel: next.densityResult!.metalLabel,
              ),
            );
          }
        });
      }
    });
  }

  void _listenToLines() {
    final bt = ref.read(btProvider);
    _linesSubscription?.cancel();
    _linesSubscription = bt.linesStream.listen((line) {
      final densityState = ref.read(densityTestProvider);

      if (ResultParser.parseScaleZeroed(line) == true) {
        ref.read(soundServiceProvider).play(SoundEffect.clickStep);
        ref.read(densityTestProvider.notifier).onScaleZeroed();
        return;
      }

      final airWeight = ResultParser.parseAirWeight(line);
      if (airWeight != null && densityState.currentStep == 1) {
        ref.read(densityTestProvider.notifier).onAirWeight(airWeight);
        return;
      }

      final waterWeight = ResultParser.parseWaterWeight(line);
      if (waterWeight != null && densityState.currentStep == 2) {
        ref.read(densityTestProvider.notifier).onWaterWeight(waterWeight);
        return;
      }

      final submergedWeight = ResultParser.parseSubmergedWeight(line);
      if (submergedWeight != null && densityState.currentStep == 3) {
        ref.read(densityTestProvider.notifier).onSubmergedWeight(submergedWeight);
        return;
      }

      final density = ResultParser.parseDensity(line);
      final metalLabel = ResultParser.parseDensityMetalLabel(line);
      if (density != null) {
        final dState = ref.read(densityTestProvider);
        final result = DensityResult(
          density: density,
          metalLabel: metalLabel ?? 'Unknown',
          wAir: dState.stepValues[1] ?? 0,
          wWater: dState.stepValues[2] ?? 0,
          wSubmerged: dState.stepValues[3] ?? 0,
          buoyancy: (dState.stepValues[3] ?? 0) - (dState.stepValues[2] ?? 0),
          timestamp: DateTime.now(),
        );
        ref.read(densityTestProvider.notifier).onDensityResult(result);
        // Update full analysis provider if in full analysis mode
        final fa = ref.read(fullAnalysisProvider);
        if (fa.isFullAnalysisMode) {
          ref.read(fullAnalysisProvider.notifier).setDensityResult(result);
        }
        return;
      }

      final error = ResultParser.parseErrorMessage(line);
      if (error != null) {
        ref.read(densityTestProvider.notifier).setError(error);
      }
    });
  }

  @override
  void dispose() {
    _linesSubscription?.cancel();
    _fullAnalysisSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final densityState = ref.watch(densityTestProvider);
    final fullAnalysis = ref.watch(fullAnalysisProvider);
    final isFullAnalysis = widget.mode == 'fullAnalysis' || fullAnalysis.isFullAnalysisMode;
    final liveAsync = ref.watch(liveDataProvider);
    final weight = liveAsync.when(data: (d) => d.weightGrams.toStringAsFixed(2), loading: () => '--', error: (_, __) => '--');

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: Text(
          isFullAnalysis ? 'Full Analysis — Step 1 of 2: Density' : 'Density Test',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 16), child: BtStatusChip()),
        ],
      ),
      body: Column(
        children: [
          // Live weight
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.scale, color: Color(0xFFFFB300)),
                const SizedBox(width: 12),
                Text(
                  'Scale: $weight g',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          // Progress dots
          _buildProgressDots(densityState),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Step 0: Zero
                  DensityWizardStep(
                    stepNumber: 1,
                    title: 'Zero the Scale',
                    instruction: 'Ensure nothing is on the scale, then tap Zero.',
                    buttonLabel: 'Zero Scale',
                    action: 'Z',
                    isCurrent: densityState.currentStep == 0,
                    isCompleted: densityState.currentStep > 0,
                    onAction: () => ref.read(densityTestProvider.notifier).zeroScale(),
                    onReMeasure: () => ref.read(densityTestProvider.notifier).reMeasureStep(0),
                  ),
                  // Step 1: Air Weight
                  DensityWizardStep(
                    stepNumber: 2,
                    title: 'Air Weight',
                    instruction: 'Place the dry sample on the scale. Keep it still.',
                    buttonLabel: 'Record Air Weight',
                    action: 'A',
                    recordedValue: densityState.stepValues[1],
                    isCurrent: densityState.currentStep == 1,
                    isCompleted: densityState.currentStep > 1 || densityState.stepValues.containsKey(1),
                    onAction: () => ref.read(densityTestProvider.notifier).recordAirWeight(),
                    onReMeasure: () => ref.read(densityTestProvider.notifier).reMeasureStep(1),
                  ),
                  // Step 2: Water Baseline
                  DensityWizardStep(
                    stepNumber: 3,
                    title: 'Water Baseline',
                    instruction: 'Fill a container with water and place it on the scale. Do NOT put the sample in yet.',
                    buttonLabel: 'Record Baseline',
                    action: 'W',
                    recordedValue: densityState.stepValues[2],
                    isCurrent: densityState.currentStep == 2,
                    isCompleted: densityState.currentStep > 2 || densityState.stepValues.containsKey(2),
                    onAction: () => ref.read(densityTestProvider.notifier).recordWaterBaseline(),
                    onReMeasure: () => ref.read(densityTestProvider.notifier).reMeasureStep(2),
                  ),
                  // Step 3: Submerged Weight
                  DensityWizardStep(
                    stepNumber: 4,
                    title: 'Submerged Weight',
                    instruction: 'Fully submerge the sample in the water. It must not touch the container walls or bottom.',
                    buttonLabel: 'Record Submerged',
                    action: 'S',
                    recordedValue: densityState.stepValues[3],
                    isCurrent: densityState.currentStep == 3,
                    isCompleted: densityState.stepValues.containsKey(3),
                    onAction: () => ref.read(densityTestProvider.notifier).recordSubmergedWeight(),
                    onReMeasure: () => ref.read(densityTestProvider.notifier).reMeasureStep(3),
                  ),
                  // Result step
                  if (densityState.canCalculate || densityState.result != null) ...[
                    if (densityState.result == null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => ref.read(densityTestProvider.notifier).calculateDensity(),
                            child: const Text('Calculate Density'),
                          ),
                        ),
                      ),
                    if (densityState.result != null) ...[
                      DensityResultCard(result: densityState.result!),
                      const DensityReferenceTable(),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => ref.read(densityTestProvider.notifier).reset(),
                            child: const Text('Reset Wizard'),
                          ),
                        ),
                      ),
                    ],
                  ],
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

  Widget _buildProgressDots(DensityTestState state) {
    final completedSteps = state.stepValues.length + (state.currentStep > 0 ? 1 : 0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final filled = index < completedSteps;
        return Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: filled ? const Color(0xFFFFB300) : const Color(0xFF333333),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
