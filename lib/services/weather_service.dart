import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/weather_forecast.dart';

export '../models/weather_forecast.dart' show WeatherForecast;

/// Pengambil prakiraan cuaca dari API publik BMKG, dengan cache lokal.
///
/// Cache diperlukan karena siklus cek berjalan tiap 15 menit sedangkan BMKG
/// memperbarui prakiraan tiap jam; tanpa cache suhu bisa berubah-ubah tanpa
/// alasan dan memicu alert berulang.
class WeatherService {
  WeatherService({http.Client? client, SharedPreferences? prefs})
    : _client = client ?? http.Client(),
      _prefsOverride = prefs;

  static const String _baseUrl =
      'https://api.bmkg.go.id/publik/prakiraan-cuaca';
  static const String _cacheKey = 'weather_forecast';
  static const String _fetchedAtKey = 'weather_fetched_at';

  final http.Client _client;
  final SharedPreferences? _prefsOverride;

  /// Prakiraan terkini untuk satu kode wilayah adm4. Nilai cache dipakai
  /// selama umurnya belum lewat [`AppConfig.BMKG_CACHE_TTL_MENIT`].
  Future<WeatherForecast?> getForecast({
    String kodeWilayah = AppConfig.BMKG_KODE_WILAYAH,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await getCachedForecast(kodeWilayah);
      if (cached != null) return cached;
    }
    return _fetchAndCache(kodeWilayah);
  }

  /// Suhu dari cache saja, atau `null` bila belum ada / sudah kedaluwarsa.
  Future<double?> getCachedTemperature({
    String kodeWilayah = AppConfig.BMKG_KODE_WILAYAH,
  }) async => (await getCachedForecast(kodeWilayah))?.temperature;

  Future<WeatherForecast?> getCachedForecast(String kodeWilayah) async {
    try {
      final prefs = _prefsOverride ?? await SharedPreferences.getInstance();
      final fetchedAt = prefs.getInt(_fetchedAtKey);
      final raw = prefs.getString(_cacheKey);
      if (fetchedAt == null || raw == null) return null;

      final age = DateTime.now().millisecondsSinceEpoch - fetchedAt;
      if (age > AppConfig.BMKG_CACHE_TTL_MENIT * 60 * 1000) return null;

      final stored = WeatherForecast.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      // Wilayah berubah → cache bukan untuk profil ini.
      if (prefs.getString('weather_wilayah') != kodeWilayah) return null;
      return stored.copyWith(fromCache: true);
    } catch (e, s) {
      debugPrint('Gagal membaca cache cuaca: $e — $s');
      return null;
    }
  }

  Future<WeatherForecast?> _fetchAndCache(String kodeWilayah) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl?adm4=$kodeWilayah'),
      );
      if (response.statusCode != 200) {
        debugPrint('BMKG balasan ${response.statusCode}');
        return null;
      }

      final forecast = _parseForecast(jsonDecode(response.body));
      if (forecast == null) return null;
      await _saveCache(kodeWilayah, forecast);
      return forecast;
    } catch (e, s) {
      debugPrint('Gagal mengambil data cuaca: $e — $s');
      return null;
    }
  }

  Future<void> _saveCache(String kodeWilayah, WeatherForecast forecast) async {
    try {
      final prefs = _prefsOverride ?? await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(forecast.toJson()));
      await prefs.setInt(_fetchedAtKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setString('weather_wilayah', kodeWilayah);
    } catch (e, s) {
      debugPrint('Gagal menyimpan cache cuaca: $e — $s');
    }
  }

  /// Struktur BMKG: `data[0].cuaca` adalah daftar per hari, dan tiap hari
  /// berisi daftar prakiraan 3-jamuan. Semua entri diratakan lalu diambil yang
  /// paling dekat dengan waktu sekarang.
  WeatherForecast? _parseForecast(dynamic data) {
    try {
      final days = (data as Map)['data'];
      if (days is! List || days.isEmpty) return null;
      final wilayah = days.first as Map;
      final list = wilayah['cuaca'];
      if (list is! List) return null;

      final entries = <Map<String, dynamic>>[];
      for (final day in list) {
        for (final item in day is List ? day : [day]) {
          if (item is Map<String, dynamic>) entries.add(item);
        }
      }
      if (entries.isEmpty) return null;

      final now = DateTime.now();
      entries.sort((a, b) => _timeGap(a, now).compareTo(_timeGap(b, now)));

      final nearest = entries.first;
      final temperature = _angka(nearest['t']);
      if (temperature == null) {
        debugPrint('BMKG: field suhu ("t") tidak ada di respons.');
        return null;
      }

      // Blok `lokasi` dipakai layanan kualitas udara untuk menentukan titik
      // sampling — jadi koordinat ikut diambil, bukan diabaikan.
      final lokasi = wilayah['lokasi'];
      final titik = lokasi is Map ? lokasi : const <String, dynamic>{};
      final lat = _angka(titik['lat'] ?? titik['latitude']);
      final lon = _angka(titik['lon'] ?? titik['longitude']);

      return WeatherForecast(
        temperature: temperature,
        humidity: _angka(nearest['hu']) ?? 0,
        weatherDesc: nearest['weather_desc']?.toString() ?? '-',
        localDatetime: nearest['local_datetime']?.toString() ?? '',
        windSpeedMs: _angka(nearest['ws']),
        windDirection: nearest['wd']?.toString(),
        latitude: lat,
        longitude: lon,
      );
    } catch (e, s) {
      debugPrint('Gagal mem-parsing data cuaca: $e — $s');
      return null;
    }
  }

  /// BMKG membalas angka untuk sebagian besar field, tetapi koordinatnya bisa
  /// berupa string. Keduanya harus tetap terpakai — koordinat yang gagal
  /// dibaca berarti kualitas udara tidak pernah ikut dinilai.
  static double? _angka(Object? nilai) => switch (nilai) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s),
    _ => null,
  };

  static Duration _timeGap(Map<String, dynamic> entry, DateTime now) {
    final parsed = DateTime.tryParse(
      (entry['local_datetime'] as String? ?? '').replaceFirst(' ', 'T'),
    );
    if (parsed == null) return const Duration(days: 365);
    return parsed.difference(now).abs();
  }
}
