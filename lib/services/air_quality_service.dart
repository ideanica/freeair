import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/air_quality.dart';

export '../models/air_quality.dart' show AirQuality;

/// Pengambil kualitas udara dari Open-Meteo Air Quality API.
///
/// Sumbernya dipilih karena tidak butuh API key sehingga aplikasi tetap
/// tanpa konfigurasi manual. Titik koordinatnya bukan isian pengguna, melainkan
/// `lokasi` yang sudah dibalas BMKG pada prakiraan cuaca.
class AirQualityService {
  AirQualityService({http.Client? client, SharedPreferences? prefs})
    : _client = client ?? http.Client(),
      _prefsOverride = prefs;

  static const String _baseUrl =
      'https://air-quality-api.open-meteo.com/v1/air-quality';
  static const String _cacheKey = 'air_quality_v1';
  static const String _fetchedAtKey = 'air_quality_fetched_at';
  static const String _titikKey = 'air_quality_titik';

  final http.Client _client;
  final SharedPreferences? _prefsOverride;

  /// PM2.5 terbaru untuk satu koordinat; `null` bila jaringan atau API gagal.
  Future<AirQuality?> getUdara({
    required double latitude,
    required double longitude,
    bool forceRefresh = false,
  }) async {
    final titik = _kunciTitik(latitude, longitude);
    if (!forceRefresh) {
      final cached = await _getCached(titik);
      if (cached != null) return cached;
    }
    return _fetchAndCache(latitude, longitude, titik);
  }

  static String _kunciTitik(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';

  Future<AirQuality?> _getCached(String titik) async {
    try {
      final prefs = _prefsOverride ?? await SharedPreferences.getInstance();
      final fetchedAt = prefs.getInt(_fetchedAtKey);
      final raw = prefs.getString(_cacheKey);
      if (fetchedAt == null || raw == null) return null;
      if (prefs.getString(_titikKey) != titik) return null;

      final age = DateTime.now().millisecondsSinceEpoch - fetchedAt;
      if (age > AppConfig.BMKG_CACHE_TTL_MENIT * 60 * 1000) return null;

      return AirQuality.decode(raw)?.copyWith(fromCache: true);
    } catch (e, s) {
      debugPrint('Gagal membaca cache kualitas udara: $e — $s');
      return null;
    }
  }

  Future<AirQuality?> _fetchAndCache(
    double latitude,
    double longitude,
    String titik,
  ) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl?latitude=${latitude.toStringAsFixed(4)}'
        '&longitude=${longitude.toStringAsFixed(4)}'
        '&current=pm2_5,pm10,us_aqi&timezone=Asia%2FJakarta',
      );
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        debugPrint('Open-Meteo balasan ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body);
      final current = data is Map ? data['current'] : null;
      if (current is! Map) {
        debugPrint('Open-Meteo: blok "current" tidak ada.');
        return null;
      }

      final kualitas = AirQuality(
        pm25: (current['pm2_5'] as num?)?.toDouble(),
        pm10: (current['pm10'] as num?)?.toDouble(),
        usAqi: (current['us_aqi'] as num?)?.toDouble(),
        fetchedAt: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
      );
      if (!kualitas.tersedia) return null;

      await _saveCache(titik, kualitas);
      return kualitas;
    } catch (e, s) {
      debugPrint('Gagal mengambil data kualitas udara: $e — $s');
      return null;
    }
  }

  Future<void> _saveCache(String titik, AirQuality kualitas) async {
    try {
      final prefs = _prefsOverride ?? await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(kualitas.toJson()));
      await prefs.setInt(_fetchedAtKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setString(_titikKey, titik);
    } catch (e, s) {
      debugPrint('Gagal menyimpan cache kualitas udara: $e — $s');
    }
  }
}
