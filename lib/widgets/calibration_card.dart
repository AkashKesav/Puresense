import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/calibration_provider.dart';
import '../providers/purity_test_provider.dart';
import '../providers/sound_provider.dart';
import '../services/sound_service.dart';
import '../utils/range_calculator.dart';

class CalibrationCard extends ConsumerStatefulWidget {
  const CalibrationCard({super.key});

  @override
  ConsumerState<CalibrationCard> createState() => _CalibrationCardState();
}

class _CalibrationCardState extends ConsumerState<CalibrationCard> {
  bool _expanded = false;
  final _adcController = TextEditingController(text: '22000');
  int _selectedKarat = 24;

  @override
  Widget build(BuildContext context) {
    final cal = ref.watch(calibrationProvider);
    final purityState = ref.watch(purityTestProvider);

    if (!_expanded && _adcController.text.isEmpty) {
      _adcController.text = cal.anchorADC.toStringAsFixed(0);
      _selectedKarat = cal.anchorKarat;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          ListTile(
            title: Row(
              children: [
                const Icon(Icons.verified, color: Color(0xFFFFB300), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Anchor: ${cal.anchorKarat}k gold at ${cal.anchorADC.toStringAsFixed(0)} ADC',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            trailing: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Done' : 'Edit'),
            ),
          ),
          if (_expanded) ...[
            const Divider(color: Color(0xFF333333), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set your calibration anchor',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildKaratDropdown(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildADCField(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: purityState.isCalibrating
                          ? null
                          : () => _startCalibration(),
                      icon: purityState.isCalibrating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sensors),
                      label: Text(purityState.isCalibrating ? 'Calibrating...' : 'Calibrate from Sample'),
                    ),
                  ),
                  if (purityState.calibrationProgress != null && purityState.calibrationProgress! > 0) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Measured: ${purityState.calibrationProgress} ADC',
                      style: const TextStyle(color: Color(0xFFFFB300), fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _confirmAndSave,
                        child: const Text('Confirm & Save'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildLivePreview(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKaratDropdown() {
    return DropdownButtonFormField<int>(
      value: _selectedKarat,
      dropdownColor: const Color(0xFF2A2A2A),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Karat',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: [24, 22, 18, 14, 10, 9].map((k) {
        return DropdownMenuItem(
          value: k,
          child: Text('${k}k'),
        );
      }).toList(),
      onChanged: (v) {
        if (v != null) setState(() => _selectedKarat = v);
      },
    );
  }

  Widget _buildADCField() {
    return TextField(
      controller: _adcController,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'ADC Value',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildLivePreview() {
    final cal = ref.read(calibrationProvider);
    final adc = double.tryParse(_adcController.text) ?? cal.anchorADC;
    final ranges = RangeCalculator.computeKaratRanges(adc, _selectedKarat, cal.tolerance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview ranges:',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
        ),
        const SizedBox(height: 8),
        ...ranges.take(4).map((r) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: r.color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text('${r.karat}k', style: const TextStyle(color: Colors.white, fontSize: 12)),
              const Spacer(),
              Text('${r.min.toStringAsFixed(0)} – ${r.max.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        )),
      ],
    );
  }

  void _startCalibration() {
    ref.read(purityTestProvider.notifier).startCalibration();
  }

  void _confirmAndSave() {
    final adc = ref.read(purityTestProvider).calibrationProgress;
    if (adc != null && adc > 0) {
      ref.read(calibrationProvider.notifier).updateCalibration(adc.toDouble(), _selectedKarat, 800);
      ref.read(soundServiceProvider).play(SoundEffect.clickStep);
      setState(() => _expanded = false);
      _showToast('Calibration saved');
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
