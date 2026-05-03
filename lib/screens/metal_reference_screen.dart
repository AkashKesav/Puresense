import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/live_data.dart';
import '../models/purity_calculation_method.dart';
import '../providers/bt_provider.dart';
import '../providers/live_data_provider.dart';
import '../providers/metal_identification_provider.dart';
import '../providers/metal_reference_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/number_format.dart' as nf;
import '../utils/range_calculator.dart';
import '../utils/statistical_classifier.dart';
import '../utils/unified_detector.dart';
import '../widgets/live_data_bar.dart';
import '../widgets/metal_id_result_card.dart';
import '../widgets/noble_metal_scale_chart.dart';

class MetalReferenceScreen extends ConsumerStatefulWidget {
  const MetalReferenceScreen({super.key});

  @override
  ConsumerState<MetalReferenceScreen> createState() =>
      _MetalReferenceScreenState();
}

class _MetalReferenceScreenState extends ConsumerState<MetalReferenceScreen> {
  bool _showGoldOnly = false;
  bool _isIdentifying = false;
  bool _showResult = false;
  MetalRange? _singleTestTarget;
  Timer? _identifyTimer;

  @override
  void dispose() {
    _identifyTimer?.cancel();
    super.dispose();
  }

  void _startIdentifyAll() async {
    setState(() {
      _isIdentifying = true;
      _showResult = false;
      _singleTestTarget = null;
    });

    final result = await _captureMetalIdentificationResult();
    if (!mounted) return;

    ref.read(metalIdentificationProvider.notifier).setResult(result);

    setState(() {
      _isIdentifying = false;
      _showResult = true;
    });
  }

  void _startSingleTest(MetalRange targetMetal) async {
    setState(() {
      _isIdentifying = true;
      _showResult = false;
      _singleTestTarget = targetMetal;
    });

    final result = await _captureMetalIdentificationResult();
    if (!mounted) return;

    ref.read(metalIdentificationProvider.notifier).setResult(result);

    setState(() {
      _isIdentifying = false;
      _showResult = true;
    });
  }

  Future<MetalIdentificationResult> _captureMetalIdentificationResult() async {
    final bt = ref.read(btProvider);
    final settings = ref.read(settingsProvider);
    final method = settings.calculationMethod;

    int classificationADC;
    StatisticalResult? statResult;

    // Use unified detector if selected
    if (method == PurityCalculationMethod.unifiedEnsemble) {
      final rawSamples = bt.purityADCSamplesCopy;
      final unifiedResult = await UnifiedGoldDetector.detect(rawSamples);
      classificationADC = unifiedResult.meanAdc;
    } else {
      // Use existing methods
      final collectedMean = await bt.startPurityTestFor(method.sampleDuration);
      final rawSamples = bt.purityADCSamplesCopy;
      final robustMean = rawSamples.isNotEmpty
          ? RangeCalculator.computeRobustADC(rawSamples)
          : collectedMean;

      classificationADC = robustMean;

      if (method.usesStatisticalAnalysis) {
        final timedSamples = bt.purityTimedSamplesCopy
            .where((sample) => sample.adc <= 15000)
            .toList(growable: false);

        if (timedSamples.length >= 2) {
          statResult = StatisticalClassifier.analyze(timedSamples);
          switch (method) {
            case PurityCalculationMethod.standardMean:
              classificationADC = robustMean;
              break;
            case PurityCalculationMethod.detrendedSlope:
              classificationADC = statResult.adcInt;
              break;
            case PurityCalculationMethod.adaptiveStatistical:
              classificationADC =
                  StatisticalClassifier.computeAdaptiveADC(statResult);
              break;
            case PurityCalculationMethod.unifiedEnsemble:
              // Already handled above
              classificationADC = robustMean;
              break;
          }
        }
      }
    }

    final metalState = ref.read(metalReferenceProvider);
    final effectiveMetals = method.usesAdaptiveRanges && statResult != null
        ? RangeCalculator.computeAdaptiveMetalRanges(
            metalState.allMetals,
            statResult,
          )
        : metalState.allMetals;

    final matches =
        RangeCalculator.identifyMetal(classificationADC, effectiveMetals);

    return MetalIdentificationResult(
      meanADC: classificationADC,
      matches: matches,
      timestamp: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveAsync = ref.watch(liveDataProvider);
    final metalState = ref.watch(metalReferenceProvider);
    final identResult = ref.watch(metalIdentificationProvider);

    final adc = liveAsync.when(
        data: (d) => d.adcValue, loading: () => 0, error: (_, __) => 0);
    final weight = liveAsync.when(
        data: (d) => d.weightGrams, loading: () => 0.0, error: (_, __) => 0.0);

    // Live closest match
    final closestMatch = _findClosestMatch(adc, metalState.allMetals);

    // Filter metals for display
    final displayMetals = _showGoldOnly
        ? metalState.allMetals
            .where((m) => m.metalName.contains('Gold'))
            .toList()
        : metalState.allMetals;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: Text(
          'Metals Lab',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              ref.read(metalReferenceProvider.notifier).resetToDefaults();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reset to original values')),
              );
            },
            icon: const Icon(Icons.restore, size: 22),
            tooltip: 'Revert to Originals',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          _showAddCustomMetalSheet(context);
        },
        backgroundColor: const Color(0xFFFFB300),
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Live identification banner
                  _buildLiveBanner(adc, weight, closestMatch),

                  // Noble metal scale chart
                  const NobleMetalScaleChart(),

                  const SizedBox(height: 16),

                  // Toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildToggleButton('Gold Tiers', _showGoldOnly),
                        const SizedBox(width: 8),
                        _buildToggleButton('All Metals', !_showGoldOnly),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Metal reference table — inline, reads from metalReferenceProvider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildMetalList(displayMetals, adc),
                  ),

                  // Identification result
                  if (_showResult && identResult.result != null)
                    MetalIdResultCard(
                      result: identResult.result!,
                      isSingleTest: _singleTestTarget != null,
                      targetMetal: _singleTestTarget,
                      onTestAgain: () => _startIdentifyAll(),
                      onTestAnotherMetal: () {
                        setState(() {
                          _showResult = false;
                          _singleTestTarget = null;
                        });
                      },
                    ),

                  if (_isIdentifying)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(
                                color: Color(0xFFFFB300)),
                            const SizedBox(height: 16),
                            Text(
                              'Touch probe to sample & hold steady...',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // How it works card
                  _buildInfoCard(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          const LiveDataBar(),
        ],
      ),
    );
  }

  Widget _buildMetalList(List<MetalRange> metals, int adc) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final metal = metals[index];
        final isMatch = adc >= metal.min && adc <= metal.max && adc <= 15000;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isMatch
                ? const Color(0xFFFFB300).withAlpha(30)
                : const Color(0xFF222222),
            borderRadius: BorderRadius.circular(12),
            border: isMatch
                ? Border.all(
                    color: const Color(0xFFFFB300).withAlpha(150), width: 1.5)
                : Border.all(color: Colors.white.withAlpha(8)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: metal.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      metal.metalName,
                      style: GoogleFonts.inter(
                        color: isMatch ? const Color(0xFFFFB300) : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (metal.isCustom)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Custom',
                        style: GoogleFonts.inter(
                          color: Colors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (isMatch)
                    Text(
                      ' ◄',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFFB300),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Expected: ${nf.NumberFormat.formatADC(metal.expectedADC.toInt())}  •  Range: ${nf.NumberFormat.formatADCRange(metal.min, metal.max)}',
                style: GoogleFonts.inter(
                  color: Colors.white.withAlpha(100),
                  fontSize: 12,
                ),
              ),
              if (metal.densityGcm3 != null)
                Text(
                  'Density: ${metal.densityGcm3} g/cm³',
                  style: GoogleFonts.inter(
                    color: Colors.white.withAlpha(100),
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isIdentifying ? null : () {
                        HapticFeedback.mediumImpact();
                        _startSingleTest(metal);
                      },
                      child: Text(
                        'Test Sample',
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _showEditADCSheet(context, metal);
                      },
                      child: Text(
                        'Edit ADC',
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (metal.isCustom) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          ref
                              .read(metalReferenceProvider.notifier)
                              .removeCustomMetal(metal.metalName);
                        },
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        tooltip: 'Delete',
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveBanner(int adc, double weight, MetalMatch? closest) {
    final isAir = adc > 15000;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAir
              ? const Color(0xFFFFB300).withAlpha(80)
              : closest != null && closest.confidence >= 40
                  ? closest.metal.color.withAlpha(80)
                  : Colors.white.withAlpha(15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live values row
          Row(
            children: [
              Text(
                '⚡ Live ADC: ${nf.NumberFormat.formatADC(adc)}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '⚖ ${nf.NumberFormat.formatWeight(weight)} g',
                style: GoogleFonts.inter(
                  color: Colors.white.withAlpha(150),
                  fontSize: 14,
                ),
              ),
            ],
          ),

          if (isAir) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: Color(0xFFFFB300), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Probe in air — touch sample to identify',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFFB300),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (closest != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: closest.metal.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Closest match:  ${closest.metal.metalName}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Confidence: ',
                  style: GoogleFonts.inter(
                    color: Colors.white.withAlpha(130),
                    fontSize: 13,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (closest.confidence / 100).clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withAlpha(15),
                      valueColor: AlwaysStoppedAnimation(closest.metal.color),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${closest.confidence.toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Identify button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isIdentifying ? null : () {
                HapticFeedback.heavyImpact();
                _startIdentifyAll();
              },
              child: Text(
                'Identify This Sample →',
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _showGoldOnly = label == 'Gold Tiers');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFFB300).withAlpha(25)
              : const Color(0xFF222222),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isActive ? const Color(0xFFFFB300) : Colors.white.withAlpha(20),
          ),
        ),
        child: Text(
          label,
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
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How It Works',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The electrochemical probe measures the metal\'s surface potential. '
            'Gold produces readings closest to zero (most noble), '
            'while cruder metals (Steel, Iron) show deeply negative ADC values.',
            style: GoogleFonts.inter(
              color: Colors.white.withAlpha(120),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  MetalMatch? _findClosestMatch(int adc, List<MetalRange> metals) {
    if (adc > 15000 || metals.isEmpty) return null;
    final ranked = RangeCalculator.identifyMetal(adc, metals);
    return ranked.isNotEmpty ? ranked.first : null;
  }

  void _showAddCustomMetalSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final adcCtrl = TextEditingController();
    final rangeStartCtrl = TextEditingController();
    final rangeEndCtrl = TextEditingController();
    final densCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Custom Metal',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Metal Name'),
                style: GoogleFonts.inter(color: Colors.white),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: adcCtrl,
                decoration: const InputDecoration(
                  labelText: 'Expected ADC (center value)',
                  hintText: 'e.g. -5000 or 1500',
                  hintStyle: TextStyle(color: Colors.white24),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
                style: GoogleFonts.inter(color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'Custom Range',
                style: GoogleFonts.inter(
                  color: const Color(0xFFFFB300),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: rangeStartCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Range Start (min)',
                        hintText: 'e.g. -5200',
                        hintStyle: TextStyle(color: Colors.white24),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(signed: true),
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: rangeEndCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Range End (max)',
                        hintText: 'e.g. -4800',
                        hintStyle: TextStyle(color: Colors.white24),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(signed: true),
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Leave blank to auto-calculate ±200 from expected ADC',
                style: GoogleFonts.inter(
                  color: Colors.white.withAlpha(80),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: densCtrl,
                decoration: const InputDecoration(
                    labelText: 'Density g/cm³ (optional)'),
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(color: Colors.white),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    final name = nameCtrl.text.trim();
                    final adc = double.tryParse(adcCtrl.text);
                    final dens = double.tryParse(densCtrl.text);

                    if (name.isEmpty || adc == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                            content: Text('Name and ADC value are required')),
                      );
                      return;
                    }

                    // Use explicit range if provided, otherwise default ±200
                    final rangeStart =
                        double.tryParse(rangeStartCtrl.text) ?? (adc - 200);
                    final rangeEnd =
                        double.tryParse(rangeEndCtrl.text) ?? (adc + 200);

                    // Ensure min < max
                    final actualMin =
                        rangeStart < rangeEnd ? rangeStart : rangeEnd;
                    final actualMax =
                        rangeStart < rangeEnd ? rangeEnd : rangeStart;

                    ref.read(metalReferenceProvider.notifier).addCustomMetal(
                          MetalRange(
                            metalName: name,
                            expectedADC: adc,
                            min: actualMin,
                            max: actualMax,
                            color: Colors.teal,
                            description: 'Custom metal',
                            densityGcm3: dens,
                            isCustom: true,
                          ),
                        );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$name added to metals list')),
                    );
                  },
                  child: Text(
                    'Save Custom Metal',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditADCSheet(BuildContext context, MetalRange metal) {
    final adcCtrl =
        TextEditingController(text: metal.expectedADC.toStringAsFixed(0));
    final rangeStartCtrl =
        TextEditingController(text: metal.min.toStringAsFixed(0));
    final rangeEndCtrl =
        TextEditingController(text: metal.max.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit ${metal.metalName}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: adcCtrl,
                decoration:
                    const InputDecoration(labelText: 'Expected ADC (center)'),
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
                style: GoogleFonts.inter(color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'Custom Range',
                style: GoogleFonts.inter(
                  color: const Color(0xFFFFB300),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: rangeStartCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Range Start (min)',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(signed: true),
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: rangeEndCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Range End (max)',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(signed: true),
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        final adc = double.tryParse(adcCtrl.text);
                        if (adc == null) return;

                        final rangeStart = double.tryParse(rangeStartCtrl.text);
                        final rangeEnd = double.tryParse(rangeEndCtrl.text);

                        if (rangeStart != null && rangeEnd != null) {
                          // Use explicit range
                          final actualMin =
                              rangeStart < rangeEnd ? rangeStart : rangeEnd;
                          final actualMax =
                              rangeStart < rangeEnd ? rangeEnd : rangeStart;
                          ref
                              .read(metalReferenceProvider.notifier)
                              .updateMetalRange(
                                metal.metalName,
                                adc,
                                actualMin,
                                actualMax,
                              );
                        } else {
                          // Fallback: compute tolerance from provided range values
                          final tol = ((metal.max - metal.min) / 2).abs();
                          ref
                              .read(metalReferenceProvider.notifier)
                              .updateMetalADC(
                                metal.metalName,
                                adc,
                                tol,
                              );
                        }

                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${metal.metalName} updated')),
                        );
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
