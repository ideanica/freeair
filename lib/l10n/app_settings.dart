import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferensi tampilan yang dipilih pengguna: bahasa dan tema.
///
/// Disimpan sekali di awal (sebelum runApp) supaya bahasa dan tema sudah
/// benar sejak frame pertama, lalu diubah lewat kartu Tampilan di Profil.
/// Ini satu-satunya tempat preferensi UI disimpan; angka klinis tetap berada
/// di rule_config.json dan riwayatnya di database.
class AppSettings {
  const AppSettings._();

  static const String keyLocale = 'ui.locale';
  static const String keyTema = 'ui.theme';

  static const String localeDefault = 'id';
  static const List<String> localeYangDidukung = <String>['id', 'en'];
  static const List<String> temaYangDidukung = <String>[
    'system',
    'light',
    'dark',
  ];

  static String _locale = localeDefault;
  static String _tema = 'system';

  /// Naik setiap preferensi berubah; widget root mendengarkannya supaya
  /// bahasa dan tema langsung ganti tanpa restart aplikasi.
  static final ValueNotifier<int> perubahan = ValueNotifier<int>(0);

  static String get locale => _locale;
  static String get tema => _tema;

  static Locale get localeMaterial => Locale(_locale);
  static ThemeMode get themeMode => switch (_tema) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  /// Dimuat sebelum runApp supaya tidak ada kedipan bahasa/tema salah.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final locale = prefs.getString(keyLocale);
    final tema = prefs.getString(keyTema);
    _locale = localeYangDidukung.contains(locale)
        ? locale!
        : _localePerangkat();
    _tema = temaYangDidukung.contains(tema) ? tema! : 'system';
  }

  static Future<void> setLocale(String kode) async {
    final dipilih = localeYangDidukung.contains(kode) ? kode : localeDefault;
    _locale = dipilih;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyLocale, dipilih);
    perubahan.value++;
  }

  static Future<void> setTema(String kode) async {
    final dipilih = temaYangDidukung.contains(kode) ? kode : 'system';
    _tema = dipilih;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyTema, dipilih);
    perubahan.value++;
  }

  /// Bahasa perangkat dipakai selama pengguna belum memilih sendiri; kalau
  /// locale HP bukan id/en, jatuh ke Indonesia karena pengguna aplikasi ini
  /// berbahasa Indonesia.
  static String _localePerangkat() {
    final kode = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return localeYangDidukung.contains(kode) ? kode : localeDefault;
  }
}
