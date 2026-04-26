import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0D0D0D),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const ProviderScope(child: PureSenseApp()));
}

class PureSenseApp extends StatelessWidget {
  const PureSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    );

    return MaterialApp.router(
      title: 'PureSense',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        textTheme: textTheme,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFB300),
          secondary: Color(0xFFFFB300),
          surface: Color(0xFF1A1A1A),
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: Colors.white,
          error: Color(0xFFCF6679),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF0D0D0D),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF222222),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB300),
            foregroundColor: Colors.black,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFFB300),
            side: BorderSide(color: const Color(0xFFFFB300).withAlpha(100)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFFFB300),
            textStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withAlpha(30)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withAlpha(30)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFFFB300), width: 1.5),
          ),
          labelStyle: TextStyle(color: Colors.white.withAlpha(150)),
          hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
        ),
        dividerTheme: DividerThemeData(
          color: Colors.white.withAlpha(20),
          thickness: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF333333),
          contentTextStyle:
              GoogleFonts.inter(color: Colors.white, fontSize: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF222222),
          selectedColor: const Color(0xFFFFB300),
          labelStyle: GoogleFonts.inter(fontSize: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFFFFB300),
          inactiveTrackColor: Color(0xFF333333),
          thumbColor: Color(0xFFFFB300),
          overlayColor: Color(0x33FFB300),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected))
              return const Color(0xFFFFB300);
            return const Color(0xFF666666);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected))
              return const Color(0xFFFFB300).withAlpha(80);
            return const Color(0xFF333333);
          }),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color(0xFFFFB300),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF2A2A2A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titleTextStyle: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          contentTextStyle: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
