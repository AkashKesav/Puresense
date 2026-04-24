# PureSense

Precision metal analysis Android application for gold purity testing and metal identification using ESP32 with ADS1115 electrochemical sensor and HX711 load cell.

## Features

- **Full Analysis**: Combined density (Archimedes) + purity (electrochemical) testing
- **Density Test**: Step-by-step density wizard with 4-step measurement process
- **Purity Test**: Real-time ADC monitoring with karat range ladder and live charts
- **Metal Identification Lab**: Live metal matching against 14+ reference metals
- **Calibration**: User-adjustable anchor-based calibration system
- **History**: SQLite-backed test history with CSV export
- **Bluetooth**: Classic serial communication with ESP32
- **Sound Effects**: Audio feedback for test results and state changes

## Hardware Requirements

- ESP32 DevKit
- ADS1115 ADC Module (differential mode)
- HX711 Load Cell Amplifier
- Load Cell (for density measurement)
- Electrochemical probe (for purity measurement)

## ESP32 Arduino Code

The ESP32 should run the provided Arduino code that:
- Reads HX711 weight data every 500ms
- Reads ADS1115 differential ADC value
- Streams data via Bluetooth Serial: `HX711: X.XX g | ADS: YYYY`
- Responds to commands: `T` (test), `A` (air weight), `W` (water), `S` (submerged), `C` (calculate), `Z` (zero), `R` (read/calibrate)

## Build Instructions

1. Install Flutter SDK (>=3.0.0)
2. Connect Android device or start emulator
3. Ensure `local.properties` points to your Flutter SDK
4. Run:

```bash
flutter pub get
flutter run
```

## Android Permissions

The app requires the following permissions:
- BLUETOOTH
- BLUETOOTH_ADMIN
- BLUETOOTH_CONNECT
- BLUETOOTH_SCAN
- ACCESS_FINE_LOCATION

## Project Structure

```
lib/
  main.dart                 - App entry point with theme
  app_router.dart           - GoRouter navigation
  models/
    live_data.dart          - All data models
  utils/
    range_calculator.dart   - Karat/metal range computation
    result_parser.dart      - ESP32 output parsing
    adc_normalizer.dart     - External data normalization
  services/
    bluetooth_service.dart  - Bluetooth Classic Serial
    sound_service.dart      - Audio feedback
    metal_reference_service.dart - Online metal data
  providers/
    *.dart                  - Riverpod state management
  widgets/
    *.dart                  - Reusable UI components
  screens/
    *.dart                  - App screens
```

## Color Scheme

- Primary: Amber `#FFB300`
- Background: `#0D0D0D`
- Surface: `#1A1A1A`
- Card: `#222222`

## License

MIT
