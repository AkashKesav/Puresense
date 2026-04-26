import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/live_data.dart';
import '../providers/bt_provider.dart';
import '../providers/density_test_provider.dart';
import '../providers/full_analysis_provider.dart';
import '../providers/live_data_provider.dart';
import '../providers/sound_provider.dart';
import '../services/sound_service.dart';
import '../utils/number_format.dart' as nf;
import '../utils/result_parser.dart';
import '../widgets/density_reference_table.dart';
import '../widgets/density_result_card.dart';
import '../widgets/density_wizard_step.dart';
import '../widgets/handoff_bottom_sheet.dart';
import '../widgets/live_data_bar.dart';

class DensityTestScreen extends ConsumerStatefulWidget {
  final String mode;
  const DensityTestScreen({super.key, this.mode = 'standalone'});

  @override
  ConsumerState<DensityTestScreen> createState() => _DensityTestScreenState();
}

class _DensityTestScreenState extends ConsumerState<DensityTestScreen>
    with TickerProviderStateMixin {
  bool get isFullAnalysis => widget.mode == 'fullAnalysis';
  StreamSubscription? _linesSub;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _listenToLines();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _linesSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  double? _pendingDensity;

  void _listenToLines() {
    final bt = ref.read(btProvider);
    _linesSub = bt.linesStream.listen((line) {
      final densityNotifier = ref.read(densityTestProvider.notifier);
      final state = ref.read(densityTestProvider);

      // Scale zeroed
      if (ResultParser.isScaleZeroed(line)) {
        densityNotifier.onScaleZeroed();
        return;
      }

      // Air weight
      final airW = ResultParser.parseAirWeight(line);
      if (airW != null && state.currentStep == 1) {
        densityNotifier.onAirWeight(airW);
        return;
      }

      // Water weight
      final waterW = ResultParser.parseWaterWeight(line);
      if (waterW != null && state.currentStep == 2) {
        densityNotifier.onWaterWeight(waterW);
        return;
      }

      // Submerged weight
      final subW = ResultParser.parseSubmergedWeight(line);
      if (subW != null && state.currentStep == 3) {
        densityNotifier.onSubmergedWeight(subW);
        return;
      }

      // Density result (value)
      final density = ResultParser.parseDensityValue(line);
      if (density != null && state.currentStep == 4) {
        _pendingDensity = density;
        return;
      }

      // Metal Label (arrives immediately after density)
      if (_pendingDensity != null && state.currentStep == 4) {
        final label = ResultParser.parseDensityMetalLabel(line);
        if (label != null) {
          final result = DensityResult(
            density: _pendingDensity!,
            metalLabel: label,
            wAir: state.stepValues[1] ?? 0,
            wWater: state.stepValues[2] ?? 0,
            wSubmerged: state.stepValues[3] ?? 0,
            buoyancy: (state.stepValues[3] ?? 0) - (state.stepValues[2] ?? 0),
            timestamp: DateTime.now(),
          );
          _pendingDensity = null; // Clear it
          ref.read(densityTestProvider.notifier).onDensityResult(result);

          if (isFullAnalysis) {
            ref.read(fullAnalysisProvider.notifier).setDensityResult(result);
            _showHandoff(result);
          }
          return;
        }
      }

      // Error
      final error = ResultParser.parseErrorMessage(line);
      if (error != null) {
        _pendingDensity = null; // Clear any pending state
        densityNotifier.setError(error);
        ref.read(soundServiceProvider).play(SoundEffect.errorBeep);
        return;
      }
    });
  }

  void _showHandoff(DensityResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HandoffBottomSheet(
        density: result.density,
        metalLabel: result.metalLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(densityTestProvider);
    final densityNotifier = ref.read(densityTestProvider.notifier);
    final liveAsync = ref.watch(liveDataProvider);
    final weight = liveAsync.when(
      data: (d) => nf.NumberFormat.formatWeight(d.weightGrams),
      loading: () => '--',
      error: (_, __) => '--',
    );

    // Calculate real stability percentage
    final stability = state.isRecording ? densityNotifier.getStabilityPercentage() : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: Text(
          isFullAnalysis ? 'Full Analysis — Step 1: Density' : 'Density Test',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (state.result != null || state.currentStep > 0)
            TextButton(
              onPressed: () {
                ref.read(densityTestProvider.notifier).reset();
              },
              child: Text(
                'Reset',
                style: GoogleFonts.inter(
                  color: const Color(0xFFFFB300),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced live weight card with animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF222222),
                  const Color(0xFF1A1A1A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFFB300).withAlpha(80),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB300).withAlpha(15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB300).withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.scale,
                          color: Color(0xFFFFB300),
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Reading',
                        style: GoogleFonts.inter(
                          color: Colors.white.withAlpha(120),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$weight g',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.speed,
                        size: 14,
                        color: Colors.white.withAlpha(150),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${(state.currentStep + 1).clamp(1, 4)}/4',
                        style: GoogleFonts.inter(
                          color: Colors.white.withAlpha(180),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildStepDots(state.currentStep),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Animated header illustration
                  if (state.currentStep == 0 && state.result == null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF2196F3).withAlpha(15),
                                      const Color(0xFF00BCD4).withAlpha(10),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF2196F3).withAlpha(30),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2196F3)
                                            .withAlpha(20),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.science,
                                        size: 48,
                                        color: Color(0xFF2196F3),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Density Testing',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Follow the steps to measure metal density using Archimedes\' principle',
                                      style: GoogleFonts.inter(
                                        color: Colors.white.withAlpha(120),
                                        fontSize: 13,
                                        height: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  // Step 1: Zero
                  DensityWizardStep(
                    stepNumber: 0,
                    title: 'Zero the Scale',
                    instruction: 'Ensure nothing is on the scale, then tap Zero.',
                    buttonLabel: 'Zero Scale',
                    isCurrent: state.currentStep == 0,
                    isCompleted: state.currentStep > 0,
                    onAction: () => ref.read(densityTestProvider.notifier).zeroScale(),
                    onReMeasure: state.currentStep > 0
                        ? () => ref.read(densityTestProvider.notifier).reMeasureStep(0)
                        : null,
                  ),

                  // Step 2: Air Weight
                  DensityWizardStep(
                    stepNumber: 1,
                    title: 'Air Weight',
                    instruction: 'Place the dry sample on the scale. Keep it still.',
                    buttonLabel: 'Record Air Weight',
                    recordedValue: state.stepValues[1],
                    isCurrent: state.currentStep == 1,
                    isCompleted: state.stepValues.containsKey(1) && state.currentStep > 1,
                    currentLiveWeight: state.isRecording ? state.currentLiveWeight : null,
                    stability: state.isRecording ? stability : null,
                    onAction: () => ref.read(densityTestProvider.notifier).recordAirWeight(),
                    onReMeasure: state.stepValues.containsKey(1) && state.currentStep > 1
                        ? () => ref.read(densityTestProvider.notifier).reMeasureStep(1)
                        : null,
                  ),

                  // Step 3: Water Baseline
                  DensityWizardStep(
                    stepNumber: 2,
                    title: 'Water Baseline',
                    instruction: 'Fill a container with water and place it on the scale.\nDo NOT put the sample in yet.',
                    buttonLabel: 'Record Baseline',
                    recordedValue: state.stepValues[2],
                    isCurrent: state.currentStep == 2,
                    isCompleted: state.stepValues.containsKey(2) && state.currentStep > 2,
                    currentLiveWeight: state.isRecording ? state.currentLiveWeight : null,
                    stability: state.isRecording ? stability : null,
                    onAction: () => ref.read(densityTestProvider.notifier).recordWaterBaseline(),
                    onReMeasure: state.stepValues.containsKey(2) && state.currentStep > 2
                        ? () => ref.read(densityTestProvider.notifier).reMeasureStep(2)
                        : null,
                  ),

                  // Step 4: Submerged
                  DensityWizardStep(
                    stepNumber: 3,
                    title: 'Submerged Weight',
                    instruction: 'Fully submerge the sample in the water.\nIt must not touch the container walls or bottom.',
                    buttonLabel: 'Record Submerged',
                    recordedValue: state.stepValues[3],
                    isCurrent: state.currentStep == 3,
                    isCompleted: state.stepValues.containsKey(3) && state.currentStep > 3,
                    currentLiveWeight: state.isRecording ? state.currentLiveWeight : null,
                    stability: state.isRecording ? stability : null,
                    onAction: () => ref.read(densityTestProvider.notifier).recordSubmergedWeight(),
                    onReMeasure: state.stepValues.containsKey(3) && state.currentStep > 3
                        ? () => ref.read(densityTestProvider.notifier).reMeasureStep(3)
                        : null,
                  ),

                  // Enhanced Step 5: Calculate button
                  if (state.currentStep >= 4 && state.result == null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: 0.8 + (0.2 * value),
                            child: Opacity(
                              opacity: value,
                              child: Container(
                                width: double.infinity,
                                height: 60,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFB300),
                                      Color(0xFFFFC107),
                                      Color(0xFFFFD54F)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFB300).withAlpha(80),
                                      blurRadius: 25,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: state.isRecording
                                        ? null
                                        : () {
                                            HapticFeedback.heavyImpact();
                                            ref.read(densityTestProvider.notifier)
                                                .calculateDensity();
                                          },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Center(
                                      child: state.isRecording
                                          ? SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(
                                                  Colors.black.withAlpha(180),
                                                ),
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.calculate,
                                                  color: Colors.black.withAlpha(180),
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Calculate Density',
                                                  style: GoogleFonts.inter(
                                                    color: Colors.black.withAlpha(180),
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // Result
                  if (state.result != null) ...[
                    DensityResultCard(
                      result: state.result!,
                      showSave: !isFullAnalysis,
                    ),
                    DensityReferenceTable(
                      highlightedLabel: state.result!.metalLabel,
                    ),
                  ],

                  // Error
                  if (state.errorMessage != null)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withAlpha(60)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              state.errorMessage!,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => ref.read(densityTestProvider.notifier).clearError(),
                            icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                          ),
                        ],
                      ),
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

  Widget _buildStepDots(int currentStep) {
    // 4 steps: Zero(0), Air(1), Water(2), Submerged(3) — Calculate is separate
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final isCompleted = i < currentStep;
        final isCurrent = i == currentStep;
        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isCurrent ? 12 : 8,
              height: isCurrent ? 12 : 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isCompleted
                    ? LinearGradient(
                        colors: [Colors.green, Colors.green.withAlpha(200)],
                      )
                    : isCurrent
                        ? LinearGradient(
                            colors: [
                              const Color(0xFFFFB300),
                              const Color(0xFFFFC107)
                            ],
                          )
                        : null,
                color: !isCompleted && !isCurrent
                    ? const Color(0xFF444444)
                    : null,
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFB300).withAlpha(80),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
            ),
            if (i < 3)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 20,
                height: isCompleted ? 3 : 2,
                decoration: BoxDecoration(
                  gradient: isCompleted
                      ? LinearGradient(
                          colors: [
                            Colors.green.withAlpha(180),
                            Colors.green.withAlpha(100)
                          ],
                        )
                      : null,
                  color: !isCompleted ? const Color(0xFF333333) : null,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        );
      }),
    );
  }
}
