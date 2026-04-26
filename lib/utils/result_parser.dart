import '../models/live_data.dart';

/// Parses all ESP32 serial output lines using regex.
/// Single source of truth for all BT data interpretation.
class ResultParser {
  // ─── Live data stream ───
  // Format: "HX711: 12.34 g | ADS: 21847"  (weight may be negative after tare)
  static final _liveDataRegex = RegExp(r'HX711:\s*(-?[\d.]+)\s*g\s*\|\s*ADS:\s*(-?[\d]+)');

  static LiveData? parseLiveData(String line) {
    final match = _liveDataRegex.firstMatch(line);
    if (match == null) return null;
    final weight = double.tryParse(match.group(1)!) ?? 0;
    final adc = int.tryParse(match.group(2)!) ?? 0;
    return LiveData(
      weightGrams: weight,
      adcValue: adc,
      timestamp: DateTime.now(),
    );
  }

  // ─── Calibration mean ───
  // Format: "Mean      : 22000"
  static final _meanRegex = RegExp(r'Mean\s*:\s*(\d+)');

  static int? parseCalibrationMean(String line) {
    final match = _meanRegex.firstMatch(line);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  // ─── Purity outcomes ───
  // Format: ">>> GOLD ✓" / ">>> NOT GOLD ✗" / ">>> ERROR: PROBE IN AIR"
  static PurityOutcome? parsePurityOutcome(String line) {
    if (line.contains('GOLD') && line.contains('✓')) return PurityOutcome.gold;
    if (line.contains('NOT GOLD') && line.contains('✗')) return PurityOutcome.notGold;
    if (line.contains('PROBE IN AIR')) return PurityOutcome.probeInAir;
    return null;
  }

  // ─── Distribution data ───
  // Format: "Gold range [X to Y]: Z"
  static final _goldRangeRegex = RegExp(r'Gold range\s*\[.*?\]:\s*(\d+)');
  static final _leftOutlierRegex = RegExp(r'Left outliers.*:\s*(\d+)');
  static final _rightOutlierRegex = RegExp(r'Right outliers.*:\s*(\d+)');

  static int? parseDistributionGold(String line) {
    final match = _goldRangeRegex.firstMatch(line);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  static int? parseDistributionLeft(String line) {
    final match = _leftOutlierRegex.firstMatch(line);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  static int? parseDistributionRight(String line) {
    final match = _rightOutlierRegex.firstMatch(line);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  // ─── Density values ───
  // Format: "W_air = 12.34 g"
  static final _wAirRegex = RegExp(r'W_air\s*=\s*([\d.]+)\s*g');
  static final _wWaterRegex = RegExp(r'W_water\s*=\s*([\d.]+)\s*g');
  static final _wSubmergedRegex = RegExp(r'W_submerged\s*=\s*([\d.]+)\s*g');
  static final _densityRegex = RegExp(r'Density\s*=\s*([\d.]+)\s*g/cm');

  static double? parseAirWeight(String line) {
    final match = _wAirRegex.firstMatch(line);
    return match != null ? double.tryParse(match.group(1)!) : null;
  }

  static double? parseWaterWeight(String line) {
    final match = _wWaterRegex.firstMatch(line);
    return match != null ? double.tryParse(match.group(1)!) : null;
  }

  static double? parseSubmergedWeight(String line) {
    final match = _wSubmergedRegex.firstMatch(line);
    return match != null ? double.tryParse(match.group(1)!) : null;
  }

  static double? parseDensityValue(String line) {
    final match = _densityRegex.firstMatch(line);
    return match != null ? double.tryParse(match.group(1)!) : null;
  }

  // ─── Density metal label ───
  // Arduino sends bare labels: "Gold", "Silver/Lead", "Steel/Iron",
  // "Copper/Brass", "Aluminum", "Floats", "Unknown"
  static const _knownDensityLabels = [
    'Gold',
    'Silver/Lead',
    'Steel/Iron',
    'Copper/Brass',
    'Aluminum',
    'Floats',
    'Unknown',
  ];

  static String? parseDensityMetalLabel(String line) {
    final trimmed = line.trim();
    // Check if the line exactly matches a known density label
    for (final label in _knownDensityLabels) {
      if (trimmed == label) return label;
    }
    // Also check with → prefix (fallback for alternative firmware)
    if (trimmed.startsWith('→')) {
      return trimmed.substring(1).trim();
    }
    return null;
  }

  // ─── Scale zeroed ───
  // Format: "Scale zeroed!"
  static bool isScaleZeroed(String line) {
    return line.contains('Scale zeroed!');
  }

  // ─── Reference update ───
  // Format: "Reference updated.*: XXXX"
  static final _refUpdateRegex = RegExp(r'Reference updated.*:\s*(\d+)');

  static int? parseReferenceUpdate(String line) {
    final match = _refUpdateRegex.firstMatch(line);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  // ─── Error messages ───
  // Format: "ERROR: ..." or "ERROR:..."
  static String? parseErrorMessage(String line) {
    if (line.startsWith('ERROR:')) {
      return line.substring(6).trim();
    }
    if (line.contains('ERROR:')) {
      final idx = line.indexOf('ERROR:');
      return line.substring(idx + 6).trim();
    }
    return null;
  }

  // ─── Samples collected ───
  // Format: "Samples collected: N"
  static final _samplesRegex = RegExp(r'Samples collected:\s*(\d+)');

  static int? parseSamplesCollected(String line) {
    final match = _samplesRegex.firstMatch(line);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  // ─── Collection started ───
  static bool isCollectionStarted(String line) {
    return line.contains('Collecting for');
  }

  // ─── Single ADS reading ───
  // Format: "ADS1115: 21847"
  static final _adsRegex = RegExp(r'ADS1115:\s*(-?\d+)');

  static int? parseADSReading(String line) {
    final match = _adsRegex.firstMatch(line);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  // ─── Single HX711 reading ───
  // Format: "HX711: 12.34 g"  (weight may be negative after tare)
  static final _hx711Regex = RegExp(r'^HX711:\s*(-?[\d.]+)\s*g$');

  static double? parseHX711Reading(String line) {
    final match = _hx711Regex.firstMatch(line.trim());
    return match != null ? double.tryParse(match.group(1)!) : null;
  }
}
