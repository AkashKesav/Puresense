import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/live_data.dart';

class MetalReferenceService {
  static final MetalReferenceService _instance = MetalReferenceService._internal();
  factory MetalReferenceService() => _instance;
  MetalReferenceService._internal();

  // Simulated online data since no real API is specified
  Future<List<MetalRange>> fetchOnlineData(double anchorADC) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Fallback: return local computed ranges with slightly adjusted tolerances
      final baseRanges = _getBaseRanges(anchorADC);
      return baseRanges.map((r) => MetalRange(
        metalName: r.metalName,
        expectedADC: r.expectedADC,
        min: r.min,
        max: r.max,
        color: r.color,
        description: r.description,
        densityGcm3: r.densityGcm3,
      )).toList();
    } catch (e) {
      return _getBaseRanges(anchorADC);
    }
  }

  List<MetalRange> _getBaseRanges(double goldReferenceADC) {
    final references = [
      {'name': 'Platinum', 'expected': 26000.0, 'color': 0xFFE5E4E2, 'density': 21.45, 'desc': 'Noble metal, highly corrosion resistant'},
      {'name': 'Gold 24k', 'expected': 22000.0, 'color': 0xFFFFD700, 'density': 19.32, 'desc': 'Pure gold (99.9%)'},
      {'name': 'Gold 22k', 'expected': 20167.0, 'color': 0xFFFFB300, 'density': 17.8, 'desc': '91.7% gold content'},
      {'name': 'Gold 18k', 'expected': 16500.0, 'color': 0xFFFFA000, 'density': 15.6, 'desc': '75.0% gold content'},
      {'name': 'Gold 14k', 'expected': 12833.0, 'color': 0xFFFF8F00, 'density': 13.0, 'desc': '58.3% gold content'},
      {'name': 'Gold 10k', 'expected': 9167.0, 'color': 0xFFFFE082, 'density': 11.6, 'desc': '41.7% gold content'},
      {'name': 'Gold 9k', 'expected': 8250.0, 'color': 0xFFFFF9C4, 'density': 11.1, 'desc': '37.5% gold content'},
      {'name': 'Silver', 'expected': 8500.0, 'color': 0xFFC0C0C0, 'density': 10.5, 'desc': 'High conductivity metal'},
      {'name': 'Copper', 'expected': 5500.0, 'color': 0xFFB87333, 'density': 8.96, 'desc': 'Excellent conductor'},
      {'name': 'Brass', 'expected': 5000.0, 'color': 0xFFC9AE5D, 'density': 8.5, 'desc': 'Copper-zinc alloy'},
      {'name': 'Bronze', 'expected': 4500.0, 'color': 0xFFCD7F32, 'density': 8.8, 'desc': 'Copper-tin alloy'},
      {'name': 'Steel', 'expected': 3000.0, 'color': 0xFF8C8C8C, 'density': 7.85, 'desc': 'Iron-carbon alloy'},
      {'name': 'Iron', 'expected': 2500.0, 'color': 0xFF555555, 'density': 7.87, 'desc': 'Ferrous metal'},
      {'name': 'Aluminium', 'expected': 1500.0, 'color': 0xFFA8A9AD, 'density': 2.7, 'desc': 'Lightweight metal'},
    ];

    final tolerance = max(400, goldReferenceADC * 0.036);
    return references.map((ref) {
      final expected = ref['expected'] as double;
      final scaled = expected * (goldReferenceADC / 22000.0);
      return MetalRange(
        metalName: ref['name'] as String,
        expectedADC: scaled,
        min: scaled - tolerance,
        max: scaled + tolerance,
        color: Color(ref['color'] as int),
        description: ref['desc'] as String,
        densityGcm3: ref['density'] as double,
      );
    }).toList();
  }
}