import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puresense/utils/range_calculator.dart';
import 'package:puresense/models/live_data.dart';

void main() {
  group('Custom ADC Ranges Verification', () {
    test('Custom metal ranges are included in metal identification', () {
      // Start with default ranges
      final defaultRanges = RangeCalculator.computeMetalRanges(-1500.0);

      // Create a custom metal range (e.g., Platinum at -4000 ADC)
      final customPlatinum = MetalRange(
        metalName: 'Platinum',
        expectedADC: -4000.0,
        min: -4200.0,
        max: -3800.0,
        color: const Color(0xFFE5E4E2),
        description: 'Precious metal',
        densityGcm3: 21.45,
        isCustom: true,
      );

      // Combine default and custom ranges
      final allRanges = [...defaultRanges, customPlatinum];

      // Test that an ADC value in the custom platinum range identifies as platinum
      final result = RangeCalculator.identifyMetal(-4000, allRanges);

      print('\n=== Custom Metal Range Test ===');
      print('Testing ADC -4000 (should be Platinum):');
      print('Best match: ${result.first.metal.metalName}');
      print('Confidence: ${result.first.confidence.toStringAsFixed(1)}%');

      expect(result.isNotEmpty, true);
      expect(result.first.metal.metalName, 'Platinum');
      expect(result.first.confidence, greaterThan(80));
    });

    test('Updated built-in metal ranges work for categorization', () {
      // Start with default ranges
      final defaultRanges = RangeCalculator.computeMetalRanges(-1500.0);

      // Find Silver and update its ADC range significantly
      final updatedRanges = defaultRanges.map((metal) {
        if (metal.metalName == 'Silver') {
          return MetalRange(
            metalName: metal.metalName,
            expectedADC: -3000.0, // Changed from -5000 to -3000
            min: -3200.0,
            max: -2800.0,
            color: metal.color,
            description: metal.description,
            densityGcm3: metal.densityGcm3,
            isCustom: metal.isCustom,
          );
        }
        return metal;
      }).toList();

      // Test that -3000 ADC now categorizes as Silver (updated range)
      final result = RangeCalculator.identifyMetal(-3000, updatedRanges);

      print('\n=== Updated Built-in Metal Range Test ===');
      print('Testing ADC -3000 (should be Silver after update):');
      print('Best match: ${result.first.metal.metalName}');
      print('Confidence: ${result.first.confidence.toStringAsFixed(1)}%');

      expect(result.isNotEmpty, true);
      expect(result.first.metal.metalName, 'Silver');
      expect(result.first.confidence, greaterThan(90));
    });

    test('Multiple custom metals coexist with built-in metals', () {
      // Start with default ranges
      final defaultRanges = RangeCalculator.computeMetalRanges(-1500.0);

      // Add multiple custom metals
      final customMetals = [
        MetalRange(
          metalName: 'Platinum',
          expectedADC: -4000.0,
          min: -4200.0,
          max: -3800.0,
          color: const Color(0xFFE5E4E2),
          description: 'Precious metal',
          densityGcm3: 21.45,
          isCustom: true,
        ),
        MetalRange(
          metalName: 'Palladium',
          expectedADC: -4500.0,
          min: -4700.0,
          max: -4300.0,
          color: const Color(0xFFE5E4E2),
          description: 'Precious metal',
          densityGcm3: 12.02,
          isCustom: true,
        ),
      ];

      final allRanges = [...defaultRanges, ...customMetals];

      // Test categorization for each custom metal
      final platinumResult = RangeCalculator.identifyMetal(-4000, allRanges);
      final palladiumResult = RangeCalculator.identifyMetal(-4500, allRanges);

      print('\n=== Multiple Custom Metals Test ===');
      print('Platinum at -4000: ${platinumResult.first.metal.metalName} (${platinumResult.first.confidence.toStringAsFixed(1)}%)');
      print('Palladium at -4500: ${palladiumResult.first.metal.metalName} (${palladiumResult.first.confidence.toStringAsFixed(1)}%)');

      expect(platinumResult.first.metal.metalName, 'Platinum');
      expect(palladiumResult.first.metal.metalName, 'Palladium');
      expect(platinumResult.first.confidence, greaterThan(80));
      expect(palladiumResult.first.confidence, greaterThan(80));
    });

    test('Custom metal range correctly handles edge cases', () {
      // Start with default ranges
      final defaultRanges = RangeCalculator.computeMetalRanges(-1500.0);

      // Add custom metal with tight range
      final customMetal = MetalRange(
        metalName: 'Custom Alloy',
        expectedADC: -2500.0,
        min: -2550.0, // Very tight range: only 50 ADC units
        max: -2450.0,
        color: const Color(0xFFCCCCCC),
        description: 'Custom alloy',
        densityGcm3: 8.0,
        isCustom: true,
      );

      final allRanges = [...defaultRanges, customMetal];

      // Test exact center (should match perfectly)
      final centerResult = RangeCalculator.identifyMetal(-2500, allRanges);

      // Test just inside range (should still match)
      print('\n=== DEBUG INFO ===');
      print('Custom Alloy range: ${customMetal.min} to ${customMetal.max} (expected: ${customMetal.expectedADC})');
      print('Looking for ADC -2460');

      // Find what Gold 14k range is
      final gold14k = defaultRanges.firstWhere((r) => r.metalName.contains('14k'));
      print('Gold 14k range: ${gold14k.min} to ${gold14k.max} (expected: ${gold14k.expectedADC})');

      final insideResult = RangeCalculator.identifyMetal(-2460, allRanges);

      print('\nAll matches for ADC -2460:');
      for (final match in insideResult.take(3)) {
        print('  ${match.metal.metalName}: ${match.confidence.toStringAsFixed(1)}% (expected: ${match.metal.expectedADC.toStringAsFixed(0)})');
      }

      // Test just outside range (should match nearest, not custom)
      final outsideResult = RangeCalculator.identifyMetal(-2400, allRanges);

      print('\n=== Custom Metal Edge Cases Test ===');
      print('Center -2500: ${centerResult.first.metal.metalName} (${centerResult.first.confidence.toStringAsFixed(1)}%)');
      print('Inside -2460: ${insideResult.first.metal.metalName} (${insideResult.first.confidence.toStringAsFixed(1)}%)');
      print('Outside -2400: ${outsideResult.first.metal.metalName} (${outsideResult.first.confidence.toStringAsFixed(1)}%)');

      expect(centerResult.first.metal.metalName, 'Custom Alloy');
      expect(centerResult.first.confidence, greaterThan(95));

      expect(insideResult.first.metal.metalName, 'Custom Alloy');
      expect(insideResult.first.confidence, greaterThan(50));

      // Outside the tight range should NOT match the custom metal
      expect(outsideResult.first.metal.metalName, isNot('Custom Alloy'));
    });

    test('Custom ranges persist when anchor ADC changes', () {
      // Simulate the real workflow: user has custom metals, then recalibrates

      // 1. Start with default ranges at -1500 anchor
      final initialRanges = RangeCalculator.computeMetalRanges(-1500.0);

      // 2. User adds custom metal
      final customMetal = MetalRange(
        metalName: 'Platinum',
        expectedADC: -4000.0,
        min: -4200.0,
        max: -3800.0,
        color: const Color(0xFFE5E4E2),
        description: 'Precious metal',
        densityGcm3: 21.45,
        isCustom: true,
      );

      // 3. User recalibrates to -2000 anchor (built-in metals change)
      final recalculatedRanges = RangeCalculator.computeMetalRanges(-2000.0);

      // 4. Custom metal should still be present and functional
      final allRanges = [...recalculatedRanges, customMetal];

      final result = RangeCalculator.identifyMetal(-4000, allRanges);

      print('\n=== Custom Range Persistence Test ===');
      print('After recalibration to -2000, Platinum at -4000:');
      print('Best match: ${result.first.metal.metalName}');
      print('Confidence: ${result.first.confidence.toStringAsFixed(1)}%');

      expect(result.first.metal.metalName, 'Platinum');
      expect(result.first.confidence, greaterThan(80));
    });

    test('Overlapping custom and built-in ranges prioritize correct match', () {
      // Test what happens when custom metal overlaps with built-in metal

      final defaultRanges = RangeCalculator.computeMetalRanges(-1500.0);

      // Create custom metal that overlaps with Silver (-5000)
      final overlappingCustom = MetalRange(
        metalName: 'Sterling Silver',
        expectedADC: -5100.0, // Very close to Silver's -5000
        min: -5300.0,
        max: -4900.0, // Overlaps with Silver's range
        color: const Color(0xFFC0C0C0),
        description: '92.5% silver',
        densityGcm3: 10.3,
        isCustom: true,
      );

      final allRanges = [...defaultRanges, overlappingCustom];

      // Test at -5100 (center of custom, within both ranges)
      final result = RangeCalculator.identifyMetal(-5100, allRanges);

      print('\n=== Overlapping Ranges Test ===');
      print('ADC -5100 (in both Silver and Sterling Silver ranges):');
      print('Best match: ${result.first.metal.metalName}');
      print('Confidence: ${result.first.confidence.toStringAsFixed(1)}%');

      // Should match the closer expected value (Sterling Silver at -5100 vs Silver at -5000)
      expect(result.first.metal.metalName, 'Sterling Silver');
      expect(result.first.confidence, greaterThan(80));
    });
  });
}
