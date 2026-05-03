import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/live_data.dart';
import '../models/purity_calculation_method.dart';
import '../providers/bt_provider.dart';
import '../providers/calibration_provider.dart';
import '../providers/full_analysis_provider.dart';
import '../providers/metal_reference_provider.dart';
import '../providers/purity_test_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/range_calculator.dart';
import '../utils/statistical_classifier.dart';
import '../utils/unified_detector.dart';
import '../utils/electrochemical_range_predictor.dart';
import '../widgets/calibration_card.dart';
import '../widgets/live_adc_chart.dart';
import '../widgets/live_data_bar.dart';
import '../widgets/purity_result_card.dart';
import '../widgets/range_ladder.dart';

class PurityTestScreen extends ConsumerStatefulWidget {
  final String mode;
  const PurityTestScreen({super.key, this.mode = 'standalone'});

  @override
  ConsumerState<PurityTestScreen> createState() => _PurityTestScreenState();
}

class _PurityTestScreenState extends ConsumerState<PurityTestScreen>
    with SingleTickerProviderStateMixin {
  bool _isCountingDown = false;
  int _countdown = 3;
  bool _isCollecting = false;
  int _sampleCount = 0;
  Timer? _countdownTimer;
  Timer? _progressTimer;
  late AnimationController _waveController;

  bool get isFullAnalysis => widget.mode == 'fullAnalysis';

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _progressTimer?.cancel();
    _waveController.dispose();
    super.dispose();
  }

  void _resetTest() {
    ref.read(purityTestProvider.notifier).reset();
  }

  /// Fallback unified result if detector fails
  UnifiedResult _createFallbackUnifiedResult(int meanADC) {
    return UnifiedResult(
      karat: 'Unknown',
      confidence: 50.0,
      meanAdc: meanADC,
      allProbabilities: {},
      explanation: 'Detector unavailable - using raw ADC: $meanADC',
    );
  }

  /// Identify metal from live ADC value for real-time display (using metals lab logic)
  MetalIdentification _identifyMetalFromAdc(int adc) {
    // Use SAME identification logic as metals lab!
    final metalState = ref.read(metalReferenceProvider);
    final matches = RangeCalculator.identifyMetal(adc, metalState.allMetals);

    if (matches.isNotEmpty) {
      final best = matches.first;
      return MetalIdentification(
        name: best.metal.metalName,
        isGold: best.metal.metalName.contains('Gold'),
        isExactMatch: best.confidence >= 40,
        color: best.metal.color,
      );
    }

    // Fallback if no matches at all
    return MetalIdentification(
      name: 'Unknown',
      isGold: false,
      isExactMatch: false,
      color: Colors.grey,
    );
  }

  void _startTest() {
    setState(() {
      _isCountingDown = true;
      _countdown = 3;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
        _beginCollection();
      }
    });
  }

  void _beginCollection() async {
    setState(() {
      _isCountingDown = false;
      _isCollecting = true;
      _sampleCount = 0;
    });

    final bt = ref.read(btProvider);
    final settings = ref.read(settingsProvider);
    final method = settings.calculationMethod;

    // Start real-time collection tracking
    final purityNotifier = ref.read(purityTestProvider.notifier);

    // CRITICAL: Collection duration must match Bluetooth service timers exactly!
    // Otherwise UI progress and actual collection will be out of sync
    Duration collectionDuration;
    Duration bluetoothCollectionDuration; // Must match BT service duration
    switch (method) {
      case PurityCalculationMethod.standardMean:
        collectionDuration = const Duration(seconds: 2);
        bluetoothCollectionDuration = const Duration(seconds: 2);
        break;
      case PurityCalculationMethod.detrendedSlope:
        collectionDuration = const Duration(seconds: 1);
        bluetoothCollectionDuration = const Duration(seconds: 1);
        break;
      case PurityCalculationMethod.adaptiveStatistical:
        collectionDuration = const Duration(milliseconds: 800);
        bluetoothCollectionDuration = const Duration(milliseconds: 800);
        break;
      case PurityCalculationMethod.unifiedEnsemble:
        collectionDuration = const Duration(milliseconds: 800);
        bluetoothCollectionDuration = const Duration(milliseconds: 800);
        break;
    }

    // Start collection state
    purityNotifier.startCollection(collectionDuration);

    // Update sample count and ADC values periodically with real-time feedback
    Timer? collectionTimer;
    collectionTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted && bt.puritySampleCount > 0) {
        final samples = bt.purityADCSamplesCopy;
        if (samples.isNotEmpty) {
          final latestAdc = samples.last;
          purityNotifier.onAdcSample(latestAdc);
          setState(() => _sampleCount = bt.puritySampleCount);
        }
      }
    });

    // Collect using the selected method - use matching durations!
    late final int meanADC;
    UnifiedResult? unifiedResult;

    print('🎯 Starting collection for $method (${bluetoothCollectionDuration.inMilliseconds}ms)');

    try {
      switch (method) {
        case PurityCalculationMethod.standardMean:
          meanADC = await bt.startPurityTestFor(bluetoothCollectionDuration)
              .timeout(const Duration(seconds: 5), onTimeout: () {
            print('⚠️ Standard mean collection timed out!');
            return 0;
          });
          print('🎯 Standard mean collection completed: $meanADC ADC');
          break;
        case PurityCalculationMethod.detrendedSlope:
          meanADC = await bt.startPurityTestFor(bluetoothCollectionDuration)
              .timeout(const Duration(seconds: 5), onTimeout: () {
            print('⚠️ Detrended slope collection timed out!');
            return 0;
          });
          print('🎯 Detrended slope collection completed: $meanADC ADC');
          break;
        case PurityCalculationMethod.adaptiveStatistical:
          meanADC = await bt.startPurityTestFor(bluetoothCollectionDuration)
              .timeout(const Duration(seconds: 5), onTimeout: () {
            print('⚠️ Adaptive statistical collection timed out!');
            return 0;
          });
          print('🎯 Adaptive statistical collection completed: $meanADC ADC');
          break;
        case PurityCalculationMethod.unifiedEnsemble:
          // CRITICAL FIX: Collect samples FIRST, then use unified detector
          print('🎯 Starting unified ensemble collection...');
          meanADC = await bt.startPurityTestFor(bluetoothCollectionDuration)
              .timeout(const Duration(seconds: 5), onTimeout: () {
            print('⚠️ Unified ensemble collection timed out!');
            return 0;
          });
          final adcSamples = bt.purityADCSamplesCopy;
          print('🎯 Unified ensemble collection completed: $meanADC ADC, ${adcSamples.length} samples');

          if (adcSamples.isEmpty) {
            print('⚠️ No samples for unified detector, using mean ADC only');
            unifiedResult = null;
          } else {
            try {
              print('🎯 Running unified detector on ${adcSamples.length} samples...');
              unifiedResult = await UnifiedGoldDetector.detect(adcSamples)
                  .timeout(const Duration(seconds: 2), onTimeout: () {
                print('⚠️ Unified detector timed out!');
                return _createFallbackUnifiedResult(meanADC);
              });
              print('🎯 Unified detector result: ${unifiedResult?.karat} (${unifiedResult?.confidence.toStringAsFixed(1)}% confidence)');
            } catch (e) {
              print('❌ Unified detector failed: $e, using fallback');
              unifiedResult = _createFallbackUnifiedResult(meanADC);
            }
          }
          break;
      }
    } catch (e) {
      print('❌ Collection failed with error: $e');
      meanADC = 0; // Fallback to 0 on error
    }

    collectionTimer?.cancel();
    _progressTimer?.cancel();

    print('🎯 Cleaning up timers and resetting state');

    if (!mounted) {
      print('⚠️ Widget disposed during collection, skipping result processing');
      return;
    }

    // CRITICAL: Always reset collecting state BEFORE any processing
    setState(() {
      _isCollecting = false;
      _sampleCount = bt.puritySampleCount;
    });

    print('🎯 Collection state reset: _isCollecting=false, sampleCount=$_sampleCount');

    // Force a UI update to ensure overlay is hidden
    await Future.delayed(const Duration(milliseconds: 50));

    if (!mounted) return;

    // Get the raw ADC samples for real distribution computation
    final adcSamples = bt.purityADCSamplesCopy;

    print('🎯 Collection completed! meanADC=$meanADC, samples=${adcSamples.length}');
    print('🎯 unifiedResult=${unifiedResult?.karat}, method=$method');

    // Safety check: if no samples were collected, show error
    if (adcSamples.isEmpty) {
      setState(() => _isCollecting = false);
      ref.read(purityTestProvider.notifier).onTestError('No samples collected. Please check probe connection and try again.');
      print('❌ No samples collected, showing error');
      return;
    }

    // Statistical analysis for drift-aware methods.
    StatisticalResult? statResult;
    int classificationADC = meanADC;

    if (method.usesStatisticalAnalysis) {
      final timedSamples = bt.purityTimedSamplesCopy;
      statResult = StatisticalClassifier.analyze(timedSamples);

      switch (method) {
        case PurityCalculationMethod.standardMean:
          classificationADC = meanADC;
          break;
        case PurityCalculationMethod.detrendedSlope:
          classificationADC = statResult.adcInt;
          break;
        case PurityCalculationMethod.adaptiveStatistical:
          classificationADC =
              StatisticalClassifier.computeAdaptiveADC(statResult);
          break;
        case PurityCalculationMethod.unifiedEnsemble:
          // Use the material classification from unified detector!
          if (unifiedResult != null) {
            classificationADC = unifiedResult.meanAdc;

            // For unified ensemble, directly use the detector's classification
            final materialName = unifiedResult.karat;
            final confidence = unifiedResult.confidence;

            // Convert unified detector result to purity result
            if (materialName.contains('Gold')) {
              // Extract karat number (e.g., "Gold 22k" -> 22)
              final karatNum = int.tryParse(materialName.replaceAll(RegExp(r'[^0-9]'), '')) ?? 22;
              final purityPct = RangeCalculator.karatToPurityPercent(karatNum);

              // Compute distribution against electrochemical ranges
              final metalRanges = ElectrochemicalRangePredictor.getAllPredictedRanges();
              final goldRange = metalRanges.firstWhere((m) => m.metalName == materialName);

              int goldCount = 0;
              int leftCount = 0;
              int rightCount = 0;

              for (final sample in adcSamples) {
                if (sample >= goldRange.min && sample <= goldRange.max) {
                  goldCount++;
                } else if (sample < goldRange.min) {
                  leftCount++;
                } else {
                  rightCount++;
                }
              }

              final total = adcSamples.isNotEmpty ? adcSamples.length : 1;
              final distGold = ((goldCount / total) * 100).round();
              final distLeft = ((leftCount / total) * 100).round();
              final distRight = 100 - distGold - distLeft;

              ref.read(purityTestProvider.notifier).onTestComplete(PurityResult(
                outcome: PurityOutcome.gold,
                meanADC: classificationADC,
                karat: karatNum,
                purityPercent: purityPct,
                distributionGold: distGold,
                distributionLeft: distLeft,
                distributionRight: distRight,
                otherMatches: [],
                timestamp: DateTime.now(),
                calculationMethod: method,
                statisticalResult: statResult,
                unifiedResult: unifiedResult, // Include unified detector result!
              ));
              return;
            } else {
              // Not gold - use metal identification
              final metalRanges = ElectrochemicalRangePredictor.getAllPredictedRanges();
              final matches = RangeCalculator.identifyMetal(classificationADC, metalRanges);
              final best = matches.isNotEmpty ? matches.first : null;
              final others = matches.length > 1 ? matches.sublist(1, matches.length.clamp(0, 6)) : <MetalMatch>[];

              ref.read(purityTestProvider.notifier).onTestComplete(PurityResult(
                outcome: PurityOutcome.notGold,
                meanADC: classificationADC,
                detectedMetal: best,
                otherMatches: others,
                distributionGold: 0,
                distributionLeft: 0,
                distributionRight: 0,
                timestamp: DateTime.now(),
                calculationMethod: method,
                statisticalResult: statResult,
                unifiedResult: unifiedResult, // Include unified detector result!
              ));
              return;
            }
          }
          classificationADC = meanADC; // Fallback
          break;
      }
    }

    // For non-unified methods, determine result using calibration data
    final cal = ref.read(calibrationProvider);
    final metalState = ref.read(metalReferenceProvider);

    final effectiveKaratRanges = method.usesAdaptiveRanges && statResult != null
        ? RangeCalculator.computeAdaptiveKaratRanges(
            cal.karatRanges,
            statResult,
          )
        : cal.karatRanges;

    final effectiveMetalRanges = method.usesAdaptiveRanges && statResult != null
        ? RangeCalculator.computeAdaptiveMetalRanges(
            metalState.allMetals,
            statResult,
          )
        : metalState.allMetals;

    // Probe in air: ADC very high positive means no metal contact
    if (classificationADC > 15000) {
      ref.read(purityTestProvider.notifier).onTestComplete(PurityResult(
            outcome: PurityOutcome.probeInAir,
            meanADC: classificationADC,
            distributionGold: 0,
            distributionLeft: 0,
            distributionRight: 0,
            otherMatches: [],
            timestamp: DateTime.now(),
            calculationMethod: method,
            statisticalResult: statResult,
            unifiedResult: unifiedResult, // Include unified detector result
          ));
      return;
    }

    // Compute sample distribution against the selected gold band.
    int goldCount = 0;
    int leftCount = 0;
    int rightCount = 0;

    KaratRange? bestKaratRange;
    for (final range in effectiveKaratRanges) {
      if (range.contains(classificationADC)) {
        bestKaratRange = range;
        break;
      }
    }

    final refRange = bestKaratRange ?? effectiveKaratRanges.first;

    for (final sample in adcSamples) {
      if (sample >= refRange.min && sample <= refRange.max) {
        goldCount++;
      } else if (sample < refRange.min) {
        leftCount++;
      } else {
        rightCount++;
      }
    }

    final total = adcSamples.isNotEmpty ? adcSamples.length : 1;
    final distGold = ((goldCount / total) * 100).round();
    final distLeft = ((leftCount / total) * 100).round();
    final distRight = 100 - distGold - distLeft; // Ensure they sum to 100

    if (bestKaratRange != null) {
      final purityPct =
          RangeCalculator.karatToPurityPercent(bestKaratRange.karat);
      ref.read(purityTestProvider.notifier).onTestComplete(PurityResult(
            outcome: PurityOutcome.gold,
            meanADC: classificationADC,
            karat: bestKaratRange.karat,
            purityPercent: purityPct,
            distributionGold: distGold,
            distributionLeft: distLeft,
            distributionRight: distRight,
            otherMatches: [],
            timestamp: DateTime.now(),
            calculationMethod: method,
            statisticalResult: statResult,
            unifiedResult: unifiedResult, // Include unified detector result
          ));
    } else {
      final matches = RangeCalculator.identifyMetal(
        classificationADC,
        effectiveMetalRanges,
      );

      final best = matches.isNotEmpty ? matches.first : null;
      final others = matches.length > 1
          ? matches.sublist(1, matches.length.clamp(0, 6))
          : <MetalMatch>[];

      ref.read(purityTestProvider.notifier).onTestComplete(PurityResult(
            outcome: PurityOutcome.notGold,
            meanADC: classificationADC,
            detectedMetal: best,
            otherMatches: others,
            distributionGold: distGold,
            distributionLeft: distLeft,
            distributionRight: distRight,
            timestamp: DateTime.now(),
            calculationMethod: method,
            statisticalResult: statResult,
            unifiedResult: unifiedResult, // Include unified detector result
          ));
    }

    // In full analysis mode, also set purity result
    if (isFullAnalysis) {
      final result = ref.read(purityTestProvider).result;
      if (result != null) {
        ref.read(fullAnalysisProvider.notifier).setPurityResult(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final purityState = ref.watch(purityTestProvider);
    final settings = ref.watch(settingsProvider);
    final hasResult = purityState.result != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: Text(
          isFullAnalysis ? 'Full Analysis - Step 2: Purity' : 'Purity Test',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (hasResult)
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(purityTestProvider.notifier).reset();
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
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Calibration card
                      const CalibrationCard(),

                      // Range ladder
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: RangeLadder(showGoldOnly: true),
                      ),

                      const SizedBox(height: 16),

                      // Live ADC chart
                      if (settings.showLiveChart) const LiveADCChart(),

                      const SizedBox(height: 16),

                      // Test button
                      if (!hasResult)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildTestButton(),
                        ),

                      // Result card inline so range ladder stays visible above.
                      if (hasResult && !_isCollecting && !_isCountingDown)
                        PurityResultCard(
                          result: purityState.result!,
                          isFullAnalysis: isFullAnalysis,
                          onContinue: isFullAnalysis
                              ? () {
                                  HapticFeedback.heavyImpact();
                                  context.push('/combined-result');
                                }
                              : null,
                          onReset: () {
                            HapticFeedback.lightImpact();
                            _resetTest();
                          },
                        ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              const LiveDataBar(),
            ],
          ),

          // Countdown overlay
          if (_isCountingDown) _buildCountdownOverlay(),

          // Collecting overlay
          if (_isCollecting) _buildCollectingOverlay(),

          // Error overlay
          if (purityState.errorMessage != null)
            _buildErrorOverlay(purityState.errorMessage!),
        ],
      ),
    );
  }

  Widget _buildTestButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB300), Color(0xFFFFC107)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            _startTest();
          },
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: Text(
              'Test Sample',
              style: GoogleFonts.inter(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    return Container(
      color: Colors.black.withAlpha(220),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: (3 - _countdown) / 3,
                      strokeWidth: 4,
                      backgroundColor: Colors.white.withAlpha(20),
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFFFFB300)),
                    ),
                  ),
                  Text(
                    '$_countdown',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFFB300),
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Touch probe to sample NOW',
              style: GoogleFonts.inter(
                color: const Color(0xFFFFB300),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hold the probe tip firmly against\nthe metal surface before timer ends',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white.withAlpha(180),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectingOverlay() {
    final purityState = ref.watch(purityTestProvider);

    return Container(
      color: Colors.black.withAlpha(220),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated waveform
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(200, 60),
                  painter: _WaveformPainter(progress: _waveController.value),
                );
              },
            ),
            const SizedBox(height: 24),

            // Enhanced real-time status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFB300).withAlpha(20),
                    const Color(0xFFFFC107).withAlpha(15),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFFB300).withAlpha(40),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sync,
                        size: 16,
                        color: const Color(0xFFFFB300),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'LIVE ANALYSIS',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFFB300),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Real-time ADC display with live metal identification
                  if (purityState.currentAdcSamples.isNotEmpty)
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              purityState.currentAdcSamples.last.toString(),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'ADC',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withAlpha(150),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // LIVE METAL IDENTIFICATION
                        Builder(
                          builder: (context) {
                            final metalId = _identifyMetalFromAdc(purityState.currentAdcSamples.last);
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: metalId.isGold
                                    ? const Color(0xFFFFB300).withAlpha(25)
                                    : metalId.isExactMatch
                                        ? Colors.blue.withAlpha(25)
                                        : Colors.grey.withAlpha(25),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: metalId.isGold
                                      ? const Color(0xFFFFB300).withAlpha(60)
                                      : metalId.isExactMatch
                                          ? Colors.blue.withAlpha(60)
                                          : Colors.grey.withAlpha(60),
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!metalId.isExactMatch)
                                    Icon(
                                      Icons.help_outline,
                                      size: 16,
                                      color: metalId.color,
                                    ),
                                  if (metalId.isExactMatch)
                                    Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: metalId.color,
                                    ),
                                  const SizedBox(width: 8),
                                  Text(
                                    metalId.name,
                                    style: GoogleFonts.inter(
                                      color: metalId.isGold
                                          ? const Color(0xFFFFB300)
                                          : metalId.isExactMatch
                                              ? Colors.blue
                                              : Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Mean: ${purityState.currentMeanAdc.toString()} ADC',
                          style: GoogleFonts.inter(
                            color: Colors.white.withAlpha(180),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Reading signal...',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFFB300),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Sample count and progress
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$_sampleCount samples',
                        style: GoogleFonts.inter(
                          color: Colors.white.withAlpha(150),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${(purityState.collectionProgress * 100).toInt()}%',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFFB300),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: purityState.collectionProgress,
                      backgroundColor: Colors.white.withAlpha(20),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFFFB300)),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Hold probe steady - do not lift!',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay(String message) {
    return Container(
      color: Colors.black.withAlpha(200),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.withAlpha(100)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(purityTestProvider.notifier).clearError();
                },
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Waveform painter for collection animation.
class _WaveformPainter extends CustomPainter {
  final double progress;
  _WaveformPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFB300)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final midY = size.height / 2;

    for (double x = 0; x <= size.width; x += 1) {
      final normalized = x / size.width;
      final wave1 = 15 *
          (1 - (normalized - 0.5).abs() * 2).clamp(0.0, 1.0) *
          _sin((normalized * 6 + progress * 2) * 3.14159);
      final wave2 = 8 *
          (1 - (normalized - 0.5).abs() * 2).clamp(0.0, 1.0) *
          _sin((normalized * 10 + progress * 3) * 3.14159);

      final y = midY + wave1 + wave2;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw a subtle fill below the wave
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFFFB300).withAlpha(30),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
  }

  double _sin(double x) => x - (x * x * x) / 6 + (x * x * x * x * x) / 120;

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.progress != progress;
}

/// Helper class for live metal identification
class MetalIdentification {
  final String name;
  final bool isGold;
  final bool isExactMatch;
  final Color color;

  MetalIdentification({
    required this.name,
    required this.isGold,
    required this.isExactMatch,
    required this.color,
  });
}
