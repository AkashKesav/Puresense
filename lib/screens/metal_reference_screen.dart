import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/live_data.dart';
import '../providers/calibration_provider.dart';
import '../providers/live_data_provider.dart';
import '../providers/metal_identification_provider.dart';
import '../providers/metal_reference_provider.dart';
import '../utils/range_calculator.dart';
import '../widgets/live_data_bar.dart';
import '../widgets/metal_id_result_card.dart';
import '../widgets/metal_reference_table.dart';
import '../widgets/noble_metal_scale_chart.dart';

class MetalReferenceScreen extends ConsumerStatefulWidget {
  const MetalReferenceScreen({super.key});

  @override
  ConsumerState<MetalReferenceScreen> createState() => _MetalReferenceScreenState();
}

class _MetalReferenceScreenState extends ConsumerState<MetalReferenceScreen> {
  bool _showGoldOnly = true;
  MetalRange? _editingMetal;

  @override
  Widget build(BuildContext context) {
    final cal = ref.watch(calibrationProvider);
    final metalRef = ref.watch(metalReferenceProvider);
    final liveAsync = ref.watch(liveDataProvider);
    final idState = ref.watch(metalIdentificationProvider);
    final adc = liveAsync.when(data: (d) => d.adcValue, loading: () => 0, error: (_, __) => 0);

    // Find closest match
    final allMetals = [...cal.metalRanges, ...metalRef.customMetals];
    final matches = RangeCalculator.identifyMetal(adc, allMetals);
    final closest = matches.isNotEmpty ? matches.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'Metals Lab',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              ref.read(metalReferenceProvider.notifier).refreshFromOnline(cal.anchorADC);
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh', style: TextStyle(fontSize: 12)),
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
                      // Live Identification Banner
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF222222),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.3), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bolt, color: Color(0xFFFFB300), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Live ADC: ${adc.toString()}',
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    ref.read(metalIdentificationProvider.notifier).startIdentification();
                                  },
                                  child: const Text('Identify This Sample →'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (adc > 18000)
                              const Text(
                                'Probe in air',
                                style: TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.w700),
                              )
                            else if (adc < 500)
                              const Text(
                                'No signal detected',
                                style: TextStyle(color: Colors.grey),
                              )
                            else if (closest != null) ...[
                              Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: closest.metal.color,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Closest match: ${closest.metal.metalName}',
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: closest.confidence / 100,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                valueColor: const AlwaysStoppedAnimation(Color(0xFFFFB300)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Confidence: ${closest.confidence.toStringAsFixed(0)}%',
                                style: const TextStyle(color: Color(0xFFFFB300), fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Scale chart
                      NobleMetalScaleChart(
                        onTapSegment: (metal) {
                          // Scroll to metal or highlight
                        },
                      ),
                      const SizedBox(height: 16),
                      // Toggle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: true, label: Text('Gold Tiers')),
                            ButtonSegment(value: false, label: Text('All Metals')),
                          ],
                          selected: {_showGoldOnly},
                          onSelectionChanged: (v) => setState(() => _showGoldOnly = v.first),
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.resolveWith((states) {
                              if (states.contains(MaterialState.selected)) return const Color(0xFFFFB300);
                              return const Color(0xFF222222);
                            }),
                            foregroundColor: MaterialStateProperty.resolveWith((states) {
                              if (states.contains(MaterialState.selected)) return Colors.black;
                              return Colors.white70;
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      MetalReferenceTable(
                        showGoldOnly: _showGoldOnly,
                        onTestSample: (metal) {
                          ref.read(metalIdentificationProvider.notifier).startIdentification(
                            mode: MetalIdMode.singleMetal,
                            target: metal,
                          );
                        },
                        onUseAsAnchor: (metal) {
                          final karat = int.tryParse(metal.metalName.replaceAll(RegExp(r'[^0-9]'), '')) ?? 24;
                          ref.read(calibrationProvider.notifier).updateCalibration(
                            metal.expectedADC,
                            karat,
                            800,
                          );
                          _showToast('${metal.metalName} set as anchor');
                        },
                        onEditADC: (metal) {
                          _showEditDialog(metal);
                        },
                      ),
                      // How It Works
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF222222),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          title: const Text(
                            'How It Works',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          iconColor: const Color(0xFFFFB300),
                          collapsedIconColor: Colors.white54,
                          children: [
                            Text(
                              'Higher ADC = more noble/conductive metal. The electrochemical probe measures the metal\'s surface potential. Noble metals (Gold, Platinum, Silver) have higher electrode potentials and produce higher ADC readings.',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
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
          // Identification overlay
          if (idState.isIdentifying)
            _buildIdOverlay(idState),
          // Result overlay
          if (idState.result != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: SingleChildScrollView(
                    child: MetalIdResultCard(
                      result: idState.result!,
                      isSingleTest: idState.mode == MetalIdMode.singleMetal,
                      targetMetal: idState.targetMetal,
                      onTestAgain: () => ref.read(metalIdentificationProvider.notifier).clearResult(),
                      onTestAnotherMetal: () => ref.read(metalIdentificationProvider.notifier).clearResult(),
                      onRunFullAnalysis: () {
                        ref.read(metalIdentificationProvider.notifier).clearResult();
                        context.push('/density?mode=fullAnalysis');
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCustomMetalDialog(),
        backgroundColor: const Color(0xFFFFB300),
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildIdOverlay(MetalIdentificationState state) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFFB300)),
            const SizedBox(height: 24),
            const Text(
              'Scanning electrochemical signal...',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (state.progress != null && state.progress! > 0)
              Text(
                '${state.progress} samples',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
              ),
          ],
        ),
      ),
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF333333)),
    );
  }

  void _showEditDialog(MetalRange metal) {
    final adcController = TextEditingController(text: metal.expectedADC.toStringAsFixed(0));
    final tolController = TextEditingController(text: '800');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text('Edit ${metal.metalName}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: adcController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Expected ADC',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            TextField(
              controller: tolController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Tolerance',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Reset'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddCustomMetalDialog() {
    final nameController = TextEditingController();
    final adcController = TextEditingController();
    final tolController = TextEditingController(text: '800');
    final densityController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Custom Metal',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Metal name',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: adcController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Expected ADC',
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    // Quick measure
                  },
                  child: const Text('Measure'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tolController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Tolerance ±',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: densityController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Density g/cm³ (optional)',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final name = nameController.text;
                  final adc = double.tryParse(adcController.text) ?? 0;
                  final tol = double.tryParse(tolController.text) ?? 800;
                  final density = double.tryParse(densityController.text);

                  if (name.isNotEmpty && adc > 0) {
                    ref.read(metalReferenceProvider.notifier).addCustomMetal(
                      MetalRange(
                        metalName: name,
                        expectedADC: adc,
                        min: adc - tol,
                        max: adc + tol,
                        color: Colors.teal,
                        description: 'Custom metal',
                        densityGcm3: density,
                        isCustom: true,
                      ),
                    );
                    Navigator.pop(context);
                    _showToast('Custom metal added');
                  }
                },
                child: const Text('Save Custom Metal'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
