import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/density_test_provider.dart';

class DensityWizardStep extends ConsumerWidget {
  final int stepNumber;
  final String title;
  final String instruction;
  final String buttonLabel;
  final String action;
  final double? recordedValue;
  final bool isCurrent;
  final bool isCompleted;
  final VoidCallback onAction;
  final VoidCallback? onReMeasure;

  const DensityWizardStep({
    super.key,
    required this.stepNumber,
    required this.title,
    required this.instruction,
    required this.buttonLabel,
    required this.action,
    this.recordedValue,
    required this.isCurrent,
    required this.isCompleted,
    required this.onAction,
    this.onReMeasure,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testState = ref.watch(densityTestProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(12),
        border: isCurrent
            ? Border.all(color: const Color(0xFFFFB300), width: 1.5)
            : isCompleted
                ? Border.all(color: Colors.green.withOpacity(0.5), width: 1)
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.green
                    : isCurrent
                        ? const Color(0xFFFFB300)
                        : const Color(0xFF333333),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : Text(
                        '$stepNumber',
                        style: TextStyle(
                          color: isCurrent ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            subtitle: isCompleted && recordedValue != null
                ? Text(
                    'Recorded: ${recordedValue!.toStringAsFixed(2)} g',
                    style: const TextStyle(color: Color(0xFFFFB300), fontSize: 13),
                  )
                : null,
            trailing: isCompleted && onReMeasure != null
                ? TextButton(
                    onPressed: onReMeasure,
                    child: const Text('Re-measure', style: TextStyle(fontSize: 12)),
                  )
                : null,
          ),
          if (isCurrent && !isCompleted) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    instruction,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: testState.isRecording ? null : onAction,
                      child: testState.isRecording
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(buttonLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
