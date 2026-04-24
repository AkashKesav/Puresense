import '../models/live_data.dart';

class ResultParser {
  static LiveData? parseLiveData(String line) {
    final regex = RegExp(r'HX711:\s*([0-9.]+)\s*g\s*\|\s*ADS:\s*(-?\d+)');
    final match = regex.firstMatch(line);
    if (match != null) {
      final weight = double.tryParse(match.group(1)!) ?? 0.0;
      final adc = int.tryParse(match.group(2)!) ?? 0;
      return LiveData(
        weightGrams: weight,
        adcValue: adc,
        timestamp: DateTime.now(),
      );
    }
    return null;
  }

  static int? parseMeanADC(String line) {
    final regex = RegExp(r'Mean\s*:\s*(\d+)');
    final match = regex.firstMatch(line);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  static PurityOutcome? parsePurityOutcome(String line) {
    if (line.contains('>>> GOLD')) return PurityOutcome.gold;
    if (line.contains('>>> NOT GOLD')) return PurityOutcome.notGold;
    if (line.contains('>>> ERROR: PROBE IN AIR')) return PurityOutcome.probeInAir;
    return null;
  }

  static int? parseGoldDistribution(String line) {
    final regex = RegExp(r'Gold range.*:\s*(\d+)');
    final match = regex.firstMatch(line);
    if (match != null) return int.tryParse(match.group(1)!);
    return null;
  }

  static int? parseLeftOutliers(String line) {
    final regex = RegExp(r'Left outliers.*:\s*(\d+)');
    final match = regex.firstMatch(line);
    if (match != null) return int.tryParse(match.group(1)!);
    return null;
  }

  static int? parseRightOutliers(String line) {
    final regex = RegExp(r'Right outliers.*:\s*(\d+)');
    final match = regex.firstMatch(line);
    if (match != null) return int.tryParse(match.group(1)!);
    return null;
  }

  static int? parseReferenceUpdated(String line) {
    final regex = RegExp(r'Reference updated.*:\s*(\d+)');
    final match = regex.firstMatch(line);
    if (match != null) return int.tryParse(match.group(1)!);
    return null;
  }

  static double? parseAirWeight(String line) {
    final regex = RegExp(r'W_air\s*=\s*([0-9.]+)\s*g');
    final match = regex.firstMatch(line);
    if (match != null) return double.tryParse(match.group(1)!);
    return null;
  }

  static double? parseWaterWeight(String line) {
    final regex = RegExp(r'W_water\s*=\s*([0-9.]+)\s*g');
    final match = regex.firstMatch(line);
    if (match != null) return double.tryParse(match.group(1)!);
    return null;
  }

  static double? parseSubmergedWeight(String line) {
    final regex = RegExp(r'W_submerged\s*=\s*([0-9.]+)\s*g');
    final match = regex.firstMatch(line);
    if (match != null) return double.tryParse(match.group(1)!);
    return null;
  }

  static double? parseDensity(String line) {
    final regex = RegExp(r'Density\s*=\s*([0-9.]+)\s*g/cm3');
    final match = regex.firstMatch(line);
    if (match != null) return double.tryParse(match.group(1)!);
    return null;
  }

  static String? parseDensityMetalLabel(String line) {
    final regex = RegExp(r'→\s*(.+)');
    final match = regex.firstMatch(line);
    if (match != null) return match.group(1)!.trim();
    return null;
  }

  static String? parseErrorMessage(String line) {
    final regex = RegExp(r'ERROR:\s*(.+)');
    final match = regex.firstMatch(line);
    if (match != null) return match.group(1)!.trim();
    return null;
  }

  static int? parseSamplesCollected(String line) {
    final regex = RegExp(r'Samples collected:\s*(\d+)');
    final match = regex.firstMatch(line);
    if (match != null) return int.tryParse(match.group(1)!);
    return null;
  }

  static bool parseCollectionStarted(String line) {
    return line.contains('Collecting for 5 seconds');
  }

  static bool parseScaleZeroed(String line) {
    return line.contains('Scale zeroed!');
  }
}
