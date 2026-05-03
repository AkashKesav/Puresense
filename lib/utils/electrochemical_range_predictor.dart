import 'dart:math';
import 'package:flutter/material.dart';
import '../models/live_data.dart';

/// Electrochemical Range Predictor
///
/// Uses standard reduction potentials to predict ADC ranges for metals
/// based on known reference measurements from your specific probe.
class ElectrochemicalRangePredictor {

  // Your measured anchor points (ADC centers) - DYNAMIC based on calibration
  static Map<String, double> _measuredMetals = {
    'Gold 24k': 2800.0,      // Default - will be updated by calibration!
    'Gold 22k': 2000.0,      // Default anchor - will be updated by calibration!
    'Gold 18k': 1200.0,      // Default - will be updated by calibration!
    'Gold 14k': 400.0,       // Default - will be updated by calibration!
    'Gold 9k': -800.0,       // Default - will be updated by calibration!
    'Silver': -5000.0,       // Default anchor - will be updated by calibration!
    'Platinum': -2000.0,     // Default - will be updated by calibration!
    'Copper': -6500.0,       // Default - will be updated by calibration!
    'Iron': -8500.0,         // Default - will be updated by calibration!
    'Aluminium': -10500.0,   // Default anchor - will be updated by calibration!
  };

  // Standard reduction potentials (volts vs SHE)
  static const Map<String, double> _standardPotentials = {
    'Gold': 1.50,
    'Platinum': 1.18,
    'Silver': 0.80,
    'Copper': 0.34,
    'Iron': -0.44,
    'Aluminium': -1.66,
  };

  // Gold karat purity percentages and their estimated potentials
  // Gold alloys: potential shifts based on purity and alloy composition
  static const Map<String, double> _goldKaratData = {
    'Gold 24k': 1.50,    // 100% gold - pure gold potential
    'Gold 22k': 1.38,    // 91.6% gold - slightly lower due to copper/silver alloys
    'Gold 18k': 1.25,    // 75% gold - more alloyed
    'Gold 14k': 1.10,    // 58.3% gold - significantly alloyed
    'Gold 9k': 0.90,     // 37.5% gold - mostly copper/silver
  };

  /// Predict ADC range for a metal based on its electrochemical potential
  static MetalRange predictRange(String metalName, {double? tolerancePercent}) {
    // Handle gold karats specially using their specific potentials
    if (_goldKaratData.containsKey(metalName)) {
      // If we have a direct measurement, use it
      if (_measuredMetals.containsKey(metalName)) {
        final center = _measuredMetals[metalName]!;
        final tolerance = tolerancePercent ?? _estimateTolerance(center);
        return _createRange(metalName, center, tolerance);
      }

      // Interpolate using gold karat data instead of general metal data
      final predictedADC = _interpolateGoldKarat(metalName);
      final tolerance = tolerancePercent ?? _estimateTolerance(predictedADC);
      return _createRange(metalName, predictedADC, tolerance);
    }

    // Handle other metals
    if (!_standardPotentials.containsKey(metalName)) {
      throw ArgumentError('Unknown metal: $metalName. Known metals: ${_standardPotentials.keys.join(", ")}');
    }

    // If we have a direct measurement, use it
    if (_measuredMetals.containsKey(metalName)) {
      final center = _measuredMetals[metalName]!;
      final tolerance = tolerancePercent ?? _estimateTolerance(center);
      return _createRange(metalName, center, tolerance);
    }

    // Otherwise, interpolate using electrochemical series
    final predictedADC = _interpolateADC(metalName);
    final tolerance = tolerancePercent ?? _estimateTolerance(predictedADC);

    return _createRange(metalName, predictedADC, tolerance);
  }

  /// Interpolate ADC value for gold karats based on purity
  static double _interpolateGoldKarat(String metalName) {
    final karatPotential = _goldKaratData[metalName]!;
    final measured22kADC = _measuredMetals['Gold 22k']!;
    const measured22kPotential = 1.38; // Gold 22k potential

    // Simple linear interpolation from 22k gold
    // Each karat has different potential, so we calculate relative to 22k
    final potentialDifference = karatPotential - measured22kPotential;

    // Estimate ADC shift per volt change (using gold-silver difference as reference)
    // Gold (1.50V) to Silver (0.80V) = 0.70V difference gives ~7000 ADC difference
    // So ~10000 ADC per volt
    const adcPerVolt = 10000.0;

    final predictedADC = measured22kADC + (potentialDifference * adcPerVolt);

    return predictedADC;
  }

  /// Interpolate ADC value based on electrochemical potential
  static double _interpolateADC(String metalName) {
    final metalPotential = _standardPotentials[metalName]!;

    // Find two reference metals that bracket this potential
    String? aboveMetal, belowMetal;
    double? abovePotential, belowPotential;
    double? aboveADC, belowADC;

    _standardPotentials.forEach((metal, potential) {
      if (_measuredMetals.containsKey(metal)) {
        if (potential > metalPotential &&
            (abovePotential == null || potential < abovePotential!)) {
          aboveMetal = metal;
          abovePotential = potential;
          aboveADC = _measuredMetals[metal];
        }
        if (potential < metalPotential &&
            (belowPotential == null || potential > belowPotential!)) {
          belowMetal = metal;
          belowPotential = potential;
          belowADC = _measuredMetals[metal];
        }
      }
    });

    // Linear interpolation
    if (aboveADC != null && belowADC != null && abovePotential != null && belowPotential != null) {
      // Formula: ADC = belowADC + (potential - belowPotential) * (aboveADC - belowADC) / (abovePotential - belowPotential)
      final slope = (aboveADC! - belowADC!) / (abovePotential! - belowPotential!);
      final predictedADC = belowADC! + (metalPotential - belowPotential!) * slope;
      return predictedADC;
    }

    // Extrapolation if needed (less accurate)
    if (aboveADC != null && abovePotential != null && belowADC != null && belowPotential != null) {
      final slope = (aboveADC! - belowADC!) / (abovePotential! - belowPotential!);
      return aboveADC! + (metalPotential - abovePotential!) * slope;
    }

    // Fallback: use closest metal
    return _measuredMetals.values.first;
  }

  /// Estimate tolerance range based on ADC magnitude
  /// Higher ADC = larger tolerance due to measurement uncertainty
  static double _estimateTolerance(double centerADC) {
    // Base tolerance ±500, scaled by magnitude
    final baseTolerance = 500.0;
    final magnitudeFactor = centerADC.abs() / 10000;
    return baseTolerance + (magnitudeFactor * 200);
  }

  /// Create MetalRange with color coding
  static MetalRange _createRange(String name, double center, double tolerance) {
    final min = center - tolerance;
    final max = center + tolerance;

    // Assign colors based on metal type
    Color color;
    if (name.contains('Gold')) {
      color = const Color(0xFFFFD700); // Gold
    } else if (name.contains('Silver')) {
      color = const Color(0xFFC0C0C0); // Silver
    } else if (name.contains('Platinum')) {
      color = const Color(0xFFE5E4E2); // Platinum
    } else if (name.contains('Copper')) {
      color = const Color(0xFFB87333); // Copper
    } else if (name.contains('Iron')) {
      color = const Color(0xFF747d8c); // Iron
    } else if (name.contains('Aluminium')) {
      color = const Color(0xFF848789); // Aluminium
    } else {
      color = const Color(0xFF2196F3); // Default blue
    }

    return MetalRange(
      metalName: name,
      expectedADC: center,
      min: min,
      max: max,
      color: color,
      description: 'Predicted using electrochemical series',
      isCustom: false,
    );
  }

  /// Get all predicted ranges for common metals
  static List<MetalRange> getAllPredictedRanges() {
    final ranges = <MetalRange>[];

    // Gold karats using proper SEP mapping (highest purity to lowest)
    ranges.add(predictRange('Gold 24k'));  // Purest gold - highest ADC
    ranges.add(predictRange('Gold 22k'));  // Your measured reference
    ranges.add(predictRange('Gold 18k'));  // Lower purity - lower ADC
    ranges.add(predictRange('Gold 14k'));  // Even lower
    ranges.add(predictRange('Gold 9k'));   // Lowest gold purity - lowest ADC

    // Other metals using standard electrode potentials
    final otherMetals = ['Platinum', 'Silver', 'Copper', 'Iron', 'Aluminium'];
    for (final metal in otherMetals) {
      ranges.add(predictRange(metal));
    }

    return ranges;
  }

  /// Update calibration anchor and recalculate all ranges
  /// Call this when user calibrates to a new anchor point
  static void updateCalibrationAnchor(double anchorADC, int anchorKarat) {
    final anchorMetalName = 'Gold $anchorKarat' + 'k';

    // Calculate the offset from the default 22k = 2000
    final default22kADC = 2000.0;
    final offset = anchorADC - default22kADC;

    // Update all measured metals to reflect the new calibration
    _measuredMetals = {
      'Gold 22k': anchorADC, // New anchor point
      'Gold 24k': _measuredMetals['Gold 24k']! + offset,
      'Gold 18k': _measuredMetals['Gold 18k']! + offset,
      'Gold 14k': _measuredMetals['Gold 14k']! + offset,
      'Gold 9k': _measuredMetals['Gold 9k']! + offset,
      'Silver': _measuredMetals['Silver']! + offset,
      'Platinum': _measuredMetals['Platinum']! + offset,
      'Copper': _measuredMetals['Copper']! + offset,
      'Iron': _measuredMetals['Iron']! + offset,
      'Aluminium': _measuredMetals['Aluminium']! + offset,
    };

    print('🔄 Calibration anchor updated: $anchorMetalName = $anchorADC ADC');
    print('   Offset from default: ${offset >= 0 ? "+" : ""}${offset.toStringAsFixed(0)}');
    print('   All electrochemical ranges recalculated');
  }

  /// Adjust prediction based on real measurement
  /// Call this when you measure an actual sample to improve future predictions
  static void addMeasurement(String metalName, double actualADC) {
    // This would update the _measuredMetals map
    // For future implementation: store in persistent storage
    _measuredMetals[metalName] = actualADC;
    print('📊 Added measurement: $metalName = $actualADC ADC');
  }
}
