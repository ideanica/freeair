import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// MaterialApp dengan locale Indonesia untuk widget test.
///
/// Lingkungan test default ke en-US, sementara semua assertion di bawah
/// mengutip teks layar bahasa Indonesia. `AppSettings` sendiri tidak ikut
/// dipakai di sini supaya test tidak bergantung ke SharedPreferences.
MaterialApp ujiApp(
  Widget home, {
  ThemeData? theme,
  Map<String, WidgetBuilder>? routes,
}) => MaterialApp(
  theme: theme,
  routes: routes ?? const <String, WidgetBuilder>{},
  locale: const Locale('id'),
  supportedLocales: const [Locale('id'), Locale('en')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);
