import 'dart:convert';

/// Kualitas udara pada satu titik koordinat.
///
/// Sumber: Open-Meteo Air Quality API (tanpa API key). Setiap komponen bisa
/// `null` bila API tidak mengirimkannya — rule engine wajib menangani null.
class AirQuality {
  const AirQuality({
    this.pm25,
    this.pm10,
    this.usAqi,
    required this.fetchedAt,
    this.latitude,
    this.longitude,
    this.fromCache = false,
  });

  final double? pm25;
  final double? pm10;

  /// US AQI yang dibalas API; dipakai hanya sebagai label, skoring memakai
  /// band PM2.5 dari rule_config.json.
  final double? usAqi;
  final DateTime fetchedAt;
  final double? latitude;
  final double? longitude;
  final bool fromCache;

  bool get tersedia => pm25 != null || pm10 != null || usAqi != null;

  AirQuality copyWith({bool? fromCache}) => AirQuality(
    pm25: pm25,
    pm10: pm10,
    usAqi: usAqi,
    fetchedAt: fetchedAt,
    latitude: latitude,
    longitude: longitude,
    fromCache: fromCache ?? this.fromCache,
  );

  Map<String, dynamic> toJson() => {
    'pm25': pm25,
    'pm10': pm10,
    'us_aqi': usAqi,
    'fetched_at': fetchedAt.toIso8601String(),
    'lat': latitude,
    'lon': longitude,
  };

  factory AirQuality.fromJson(Map<String, dynamic> json) => AirQuality(
    pm25: (json['pm25'] as num?)?.toDouble(),
    pm10: (json['pm10'] as num?)?.toDouble(),
    usAqi: (json['us_aqi'] as num?)?.toDouble(),
    fetchedAt:
        DateTime.tryParse(json['fetched_at'] as String? ?? '') ??
        DateTime.now(),
    latitude: (json['lat'] as num?)?.toDouble(),
    longitude: (json['lon'] as num?)?.toDouble(),
  );

  static AirQuality? decode(String raw) {
    try {
      return AirQuality.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }
}
