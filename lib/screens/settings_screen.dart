import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/purity_calculation_method.dart';
import '../providers/bt_provider.dart';
import '../providers/calibration_provider.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sound_provider.dart';
import '../services/sound_service.dart';
import '../utils/number_format.dart' as nf;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final cal = ref.watch(calibrationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calibration
            _sectionHeader('CALIBRATION'),
            _buildCard(
              child: Column(
                children: [
                  _buildRow(
                    'Anchor Karat',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withAlpha(20)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: cal.anchorKarat,
                          dropdownColor: const Color(0xFF2A2A2A),
                          isDense: true,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          items: [9, 10, 14, 18, 22, 24].map((k) {
                            return DropdownMenuItem(
                                value: k, child: Text('${k}k'));
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(calibrationProvider.notifier)
                                  .updateCalibration(
                                    cal.anchorADC,
                                    v,
                                    cal.tolerance,
                                  );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Anchor karat changed to ${v}k',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  backgroundColor: const Color(0xFF222222),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  _divider(),
                  _buildRow(
                    'Anchor ADC Value',
                    subtitle: nf.NumberFormat.formatADC(cal.anchorADC.toInt()),
                    trailing: IconButton(
                      onPressed: () => _showADCEditor(context, ref, cal),
                      icon: const Icon(Icons.edit,
                          size: 18, color: Color(0xFFFFB300)),
                    ),
                  ),
                  _divider(),
                  _buildRow(
                    'Gold Tolerance Band',
                    subtitle: '+/-${cal.tolerance.toInt()} ADC',
                  ),
                  Slider(
                    value: cal.tolerance,
                    min: 10,
                    max: 2000,
                    divisions: 199,
                    label: '+/-${cal.tolerance.toInt()} ADC',
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      ref.read(calibrationProvider.notifier).updateCalibration(
                            cal.anchorADC,
                            cal.anchorKarat,
                            v,
                          );
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB300),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${cal.anchorKarat}k Gold: ${nf.NumberFormat.formatADCRange(
                            cal.anchorADC - cal.tolerance,
                            cal.anchorADC + cal.tolerance,
                          )}',
                          style: GoogleFonts.inter(
                            color: Colors.white.withAlpha(150),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.push('/purity?mode=standalone');
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.science, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Recalibrate from Sample',
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Classification method
            _sectionHeader('CLASSIFICATION METHOD'),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose how purity is computed from ADC samples.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withAlpha(120),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...PurityCalculationMethod.values.map((method) {
                    final selected = settings.calculationMethod == method;
                    final durationLabel = method
                                .sampleDuration.inMilliseconds >=
                            1000
                        ? '${(method.sampleDuration.inMilliseconds / 1000).toStringAsFixed(0)}s'
                        : '${(method.sampleDuration.inMilliseconds / 1000).toStringAsFixed(1)}s';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref
                                .read(settingsProvider.notifier)
                                .setPurityCalculationMethod(method);
                            if (!selected) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Switched to ${method.title}',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  backgroundColor: const Color(0xFF222222),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFFFB300).withAlpha(18)
                                  : const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFFFFB300)
                                    : Colors.white.withAlpha(20),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  size: 18,
                                  color: selected
                                      ? const Color(0xFFFFB300)
                                      : Colors.white.withAlpha(90),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        method.title,
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        method.description,
                                        style: GoogleFonts.inter(
                                          color: Colors.white.withAlpha(110),
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(14),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    durationLabel,
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withAlpha(170),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Color(0xFFFFB300),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Adaptive Statistical uses a shorter capture window so ADC drift has less time to bias readings. It computes mean, slope, and variance, then derives dynamic ranges from that same test.',
                            style: GoogleFonts.inter(
                              color: Colors.white.withAlpha(110),
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // SOUND
            _sectionHeader('SOUND'),
            _buildCard(
              child: Column(
                children: [
                  _buildRow(
                    'Sound Effects',
                    trailing: Switch(
                      value: settings.soundEnabled,
                      onChanged: (v) {
                        HapticFeedback.lightImpact();
                        ref.read(settingsProvider.notifier).setSoundEnabled(v);
                      },
                    ),
                  ),
                  _divider(),
                  _buildRow('Volume',
                      subtitle: '${(settings.volume * 100).toInt()}%'),
                  Slider(
                    value: settings.volume,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    label: '${(settings.volume * 100).toInt()}%',
                    onChanged: settings.soundEnabled
                        ? (v) {
                            ref.read(settingsProvider.notifier).setVolume(v);
                          }
                        : null,
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: settings.soundEnabled
                          ? () {
                              HapticFeedback.lightImpact();
                              ref
                                  .read(soundServiceProvider)
                                  .play(SoundEffect.chimeGold);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Playing test sound...',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  backgroundColor: const Color(0xFF222222),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.volume_up, size: 18),
                      label: Text(
                        'Test Sound',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // DISPLAY
            _sectionHeader('DISPLAY'),
            _buildCard(
              child: Column(
                children: [
                  _buildRow(
                    'Live ADC Chart',
                    subtitle: 'Show on purity test screen',
                    trailing: Switch(
                      value: settings.showLiveChart,
                      onChanged: (v) {
                        HapticFeedback.lightImpact();
                        ref.read(settingsProvider.notifier).setShowLiveChart(v);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // BLUETOOTH
            _sectionHeader('BLUETOOTH'),
            _buildCard(
              child: Column(
                children: [
                  _buildRow(
                    'Auto-reconnect',
                    subtitle:
                        'Retry once on connection failure and after unexpected disconnects',
                    trailing: Switch(
                      value: settings.autoReconnect,
                      onChanged: (v) {
                        HapticFeedback.lightImpact();
                        ref.read(settingsProvider.notifier).setAutoReconnect(v);
                      },
                    ),
                  ),
                  _divider(),
                  _buildRow(
                    'Device Name',
                    subtitle: 'ESP32_GoldDetector',
                  ),
                  _divider(),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        _showConfirmDialog(
                          context,
                          'Forget Device',
                          'This will disconnect and forget the paired device. You will need to reconnect.',
                          () {
                            ref.read(btProvider).disconnect();
                            context.go('/connect');
                          },
                        );
                      },
                      icon: const Icon(Icons.link_off,
                          size: 18, color: Colors.red),
                      label: Text(
                        'Forget Device',
                        style: GoogleFonts.inter(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // DATA
            _sectionHeader('DATA'),
            _buildCard(
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        try {
                          final path = await ref
                              .read(historyProvider.notifier)
                              .exportToCsv();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.green),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Data exported successfully!',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF222222),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.red),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Export failed: $e',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFFCF6679),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.download, size: 18),
                      label: Text(
                        'Export All Data as CSV',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        _showConfirmDialog(
                          context,
                          'Clear All History',
                          'This will permanently delete all test results. This cannot be undone.',
                          () {
                            ref.read(historyProvider.notifier).clearAll();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.delete_outline, color: Colors.red),
                                    const SizedBox(width: 12),
                                    Text(
                                      'All history cleared',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF222222),
                              ),
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      label: Text(
                        'Clear All History',
                        style: GoogleFonts.inter(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        _showConfirmDialog(
                          context,
                          'Reset Calibration',
                          'Reset to default anchor: 22k at -1,500 ADC with +/-50 tolerance?',
                          () {
                            ref
                                .read(calibrationProvider.notifier)
                                .resetToDefaults();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.restore, color: Color(0xFFFFB300)),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Calibration reset to defaults',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF222222),
                              ),
                            );
                          },
                        );
                      },
                      icon: Icon(Icons.restore,
                          size: 18, color: Colors.white.withAlpha(130)),
                      label: Text(
                        'Reset Calibration to Defaults',
                        style: GoogleFonts.inter(
                          color: Colors.white.withAlpha(130),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ABOUT
            _sectionHeader('ABOUT'),
            _buildCard(
              child: Column(
                children: [
                  _buildRow('App Version', subtitle: '1.0.0'),
                  _divider(),
                  _buildRow('Build', subtitle: 'PureSense for Android'),
                ],
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white.withAlpha(100),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: child,
    );
  }

  Widget _buildRow(String title, {String? subtitle, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: Colors.white.withAlpha(100),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(color: Colors.white.withAlpha(15), height: 20);
  }

  void _showADCEditor(BuildContext context, WidgetRef ref, dynamic cal) {
    final ctrl = TextEditingController(text: cal.anchorADC.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Anchor ADC',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'ADC Value',
            labelStyle: GoogleFonts.inter(color: Colors.white.withAlpha(150)),
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withAlpha(30)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFFFB300), width: 1.5),
            ),
          ),
          style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Colors.white.withAlpha(180),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final adc = double.tryParse(ctrl.text);
              if (adc != null) {
                ref
                    .read(calibrationProvider.notifier)
                    .updateCalibration(adc, cal.anchorKarat, cal.tolerance);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please enter a valid number',
                      style: GoogleFonts.inter(color: Colors.white),
                    ),
                    backgroundColor: const Color(0xFFCF6679),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: Colors.black,
            ),
            child: Text(
              'Save',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(BuildContext context, String title, String message,
      VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: Colors.white.withAlpha(180),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Colors.white.withAlpha(180),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Confirm',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
