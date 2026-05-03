import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/calibration_provider.dart';
import '../providers/bt_provider.dart';
import '../providers/metal_reference_provider.dart';
import '../utils/number_format.dart' as nf;

class CalibrationCard extends ConsumerStatefulWidget {
  const CalibrationCard({super.key});

  @override
  ConsumerState<CalibrationCard> createState() => _CalibrationCardState();
}

class _CalibrationCardState extends ConsumerState<CalibrationCard> {
  bool _isExpanded = false;
  bool _isCalibrating = false;
  int? _karatSelection;
  late final TextEditingController _adcController;

  @override
  void initState() {
    super.initState();
    _adcController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update text controller when calibration changes
    final cal = ref.watch(calibrationProvider);
    if (_adcController.text.isEmpty ||
        _adcController.text == nf.NumberFormat.formatADC(-1500)) {
      _adcController.text = nf.NumberFormat.formatADC(cal.anchorADC.toInt());
    }
  }

  @override
  void dispose() {
    _adcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cal = ref.watch(calibrationProvider);
    final metalState = ref.watch(metalReferenceProvider); // Watch metal reference provider!
    // Check if actually calibrated (not default -1500) or if user has set a custom value
    final isCalibrated = cal.anchorADC != -1500.0;

    _karatSelection ??= cal.anchorKarat;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCalibrated && !_isExpanded
              ? Colors.green.withAlpha(60)
              : const Color(0xFFFFB300).withAlpha(40),
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    isCalibrated ? Icons.check_circle : Icons.tune,
                    color: isCalibrated && !_isExpanded
                        ? Colors.green
                        : const Color(0xFFFFB300),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: isCalibrated && !_isExpanded
                        ? Text(
                            'Anchor: ${cal.anchorKarat}k gold at ${nf.NumberFormat.formatADC(cal.anchorADC.toInt())} ADC',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : Text(
                            'Set your calibration anchor',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  if (isCalibrated && !_isExpanded)
                    Text(
                      'Edit',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFFB300),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white.withAlpha(100),
                      size: 22,
                    ),
                ],
              ),
            ),
          ),

          // Expanded content - only show when explicitly expanded
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Color(0xFF333333), height: 1),
                  const SizedBox(height: 16),

                  // Karat & ADC inputs
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Karat',
                              style: GoogleFonts.inter(
                                color: Colors.white.withAlpha(130),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withAlpha(20)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _karatSelection,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF2A2A2A),
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                                  items: [9, 10, 14, 18, 22, 24].map((k) {
                                    return DropdownMenuItem(value: k, child: Text('${k}k'));
                                  }).toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _karatSelection = v);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ADC Value',
                              style: GoogleFonts.inter(
                                color: Colors.white.withAlpha(130),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _adcController,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: nf.NumberFormat.formatADC(cal.anchorADC.toInt()),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Calibrate from sample
                  Text(
                    'OR measure live with a known sample:',
                    style: GoogleFonts.inter(
                      color: Colors.white.withAlpha(100),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isCalibrating ? null : _calibrateFromSample,
                      icon: _isCalibrating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFFB300),
                              ),
                            )
                          : const Icon(Icons.sensors, size: 18),
                      label: Text(
                        _isCalibrating ? 'Collecting readings...' : 'Calibrate from Sample',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final adcText = _adcController.text.replaceAll(',', '');
                        final adc = double.tryParse(adcText) ?? cal.anchorADC;
                        final karat = _karatSelection ?? cal.anchorKarat;

                        ref.read(calibrationProvider.notifier).updateCalibration(adc, karat, cal.tolerance);
                        print('✅ Calibration updated: ADC=$adc, Karat=$karat');

                        // Close the card after successful save
                        setState(() {
                          _isExpanded = false;
                        });

                        print('✅ Metal reference ranges synced to new anchor');

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Calibration saved: ${karat}k at ${nf.NumberFormat.formatADC(adc.toInt())} ADC'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      child: Text(
                        'Confirm & Save',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                  // Live preview - Now with electrochemical predictions!
                  const SizedBox(height: 12),
                  Text(
                    'Live Range Preview',
                    style: GoogleFonts.inter(
                      color: Colors.white.withAlpha(100),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Use metal reference provider for electrochemical predictions
                  ...metalState.allMetals.where((m) => m.metalName.contains('Gold')).take(3).map((metal) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: metal.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          metal.metalName, // Shows "Gold 24k", "Gold 22k", etc.
                          style: GoogleFonts.inter(
                            color: Colors.white.withAlpha(130),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          nf.NumberFormat.formatADCRange(metal.min, metal.max),
                          style: GoogleFonts.inter(
                            color: Colors.white.withAlpha(100),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _calibrateFromSample() async {
    setState(() => _isCalibrating = true);

    final bt = ref.read(btProvider);
    final meanADC = await bt.startCalibration();

    if (mounted) {
      setState(() {
        _isCalibrating = false;
        _adcController.text = nf.NumberFormat.formatADC(meanADC);
      });
    }
  }
}
