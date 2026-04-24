import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/calibration_provider.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sound_provider.dart';
import '../services/sound_service.dart';
import '../utils/range_calculator.dart';
import '../widgets/live_data_bar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final cal = ref.watch(calibrationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('CALIBRATION'),
                  _buildSettingCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Anchor Karat', style: TextStyle(color: Colors.white)),
                            const Spacer(),
                            DropdownButton<int>(
                              value: cal.anchorKarat,
                              dropdownColor: const Color(0xFF2A2A2A),
                              style: const TextStyle(color: Colors.white),
                              underline: const SizedBox(),
                              items: [24, 22, 18, 14, 10, 9].map((k) {
                                return DropdownMenuItem(value: k, child: Text('${k}k'));
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  ref.read(calibrationProvider.notifier).updateCalibration(cal.anchorADC, v, cal.tolerance);
                                }
                              },
                            ),
                          ],
                        ),
                        const Divider(color: Color(0xFF333333)),
                        Row(
                          children: [
                            const Text('Anchor ADC', style: TextStyle(color: Colors.white)),
                            const Spacer(),
                            SizedBox(
                              width: 100,
                              child: TextField(
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.end,
                                controller: TextEditingController(text: cal.anchorADC.toStringAsFixed(0)),
                                onSubmitted: (v) {
                                  final adc = double.tryParse(v);
                                  if (adc != null) {
                                    ref.read(calibrationProvider.notifier).updateCalibration(adc, cal.anchorKarat, cal.tolerance);
                                  }
                                },
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: '22000',
                                  hintStyle: TextStyle(color: Colors.white30),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Color(0xFF333333)),
                        const Text('Gold Tolerance Band', style: TextStyle(color: Colors.white)),
                        Slider(
                          value: cal.tolerance,
                          min: 200,
                          max: 2000,
                          divisions: 36,
                          label: '±${cal.tolerance.toInt()}',
                          activeColor: const Color(0xFFFFB300),
                          inactiveColor: const Color(0xFF333333),
                          onChanged: (v) {
                            ref.read(calibrationProvider.notifier).updateCalibration(cal.anchorADC, cal.anchorKarat, v);
                          },
                        ),
                        Center(
                          child: Text(
                            '±${cal.tolerance.toInt()} ADC',
                            style: const TextStyle(color: Color(0xFFFFB300), fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                        // Live preview
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Effect on 18k range:',
                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                              ),
                              Builder(
                                builder: (context) {
                                  final ranges = RangeCalculator.computeKaratRanges(cal.anchorADC, cal.anchorKarat, cal.tolerance);
                                  final r18 = ranges.firstWhere((r) => r.karat == 18, orElse: () => ranges.first);
                                  return Text(
                                    '${r18.min.toStringAsFixed(0)} – ${r18.max.toStringAsFixed(0)}',
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              // Trigger calibration flow
                            },
                            child: const Text('Recalibrate from Sample'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSectionHeader('SOUND'),
                  _buildSettingCard(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Sound Effects', style: TextStyle(color: Colors.white)),
                          subtitle: Text('Enable audio feedback', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                          value: settings.soundEnabled,
                          activeColor: const Color(0xFFFFB300),
                          onChanged: (v) => ref.read(settingsProvider.notifier).setSoundEnabled(v),
                        ),
                        const Divider(color: Color(0xFF333333)),
                        ListTile(
                          title: const Text('Volume', style: TextStyle(color: Colors.white)),
                          subtitle: Slider(
                            value: settings.volume,
                            min: 0,
                            max: 1,
                            divisions: 20,
                            activeColor: const Color(0xFFFFB300),
                            inactiveColor: const Color(0xFF333333),
                            onChanged: (v) => ref.read(settingsProvider.notifier).setVolume(v),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () => ref.read(soundServiceProvider).testSound(),
                            icon: const Icon(Icons.volume_up, size: 18),
                            label: const Text('Test Sound'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSectionHeader('DISPLAY'),
                  _buildSettingCard(
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('Theme', style: TextStyle(color: Colors.white)),
                          trailing: DropdownButton<String>(
                            value: settings.themeMode,
                            dropdownColor: const Color(0xFF2A2A2A),
                            style: const TextStyle(color: Colors.white),
                            underline: const SizedBox(),
                            items: ['dark', 'light'].map((t) {
                              return DropdownMenuItem(value: t, child: Text(t[0].toUpperCase() + t.substring(1)));
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) ref.read(settingsProvider.notifier).setThemeMode(v);
                            },
                          ),
                        ),
                        SwitchListTile(
                          title: const Text('Live ADC Chart', style: TextStyle(color: Colors.white)),
                          subtitle: Text('Show on purity screen', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                          value: settings.showLiveChart,
                          activeColor: const Color(0xFFFFB300),
                          onChanged: (v) => ref.read(settingsProvider.notifier).setShowLiveChart(v),
                        ),
                      ],
                    ),
                  ),
                  _buildSectionHeader('BLUETOOTH'),
                  _buildSettingCard(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Auto-reconnect', style: TextStyle(color: Colors.white)),
                          value: settings.autoReconnect,
                          activeColor: const Color(0xFFFFB300),
                          onChanged: (v) => ref.read(settingsProvider.notifier).setAutoReconnect(v),
                        ),
                        const Divider(color: Color(0xFF333333)),
                        const ListTile(
                          title: Text('Device name', style: TextStyle(color: Colors.white)),
                          trailing: Text('ESP32_GoldDetector', style: TextStyle(color: Colors.white70)),
                        ),
                      ],
                    ),
                  ),
                  _buildSectionHeader('DATA'),
                  _buildSettingCard(
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('Clear All History', style: TextStyle(color: Colors.red)),
                          trailing: const Icon(Icons.delete_outline, color: Colors.red),
                          onTap: () => _showClearDialog(),
                        ),
                        const Divider(color: Color(0xFF333333)),
                        ListTile(
                          title: const Text('Reset Calibration to Defaults', style: TextStyle(color: Colors.white)),
                          onTap: () => ref.read(calibrationProvider.notifier).resetToDefaults(),
                        ),
                      ],
                    ),
                  ),
                  _buildSectionHeader('ABOUT'),
                  _buildSettingCard(
                    child: const Column(
                      children: [
                        ListTile(
                          title: Text('App Version', style: TextStyle(color: Colors.white)),
                          trailing: Text('1.0.0', style: TextStyle(color: Colors.white70)),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Clear All History?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete all test history. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(historyProvider.notifier).clearAll();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
