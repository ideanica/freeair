/// Satu titik prakiraan cuaca yang paling dekat dengan waktu sekarang.
///
/// [latitude]/[longitude] diambil dari blok `lokasi` respons BMKG sehingga
/// sumber kualitas udara bisa ikut ditentukan otomatis tanpa isian manual.
class WeatherForecast {
  const WeatherForecast({
    required this.temperature,
    required this.humidity,
    required this.weatherDesc,
    required this.localDatetime,
    this.windSpeedMs,
    this.windDirection,
    this.latitude,
    this.longitude,
    this.fromCache = false,
  });

  final double temperature;

  /// Kelembapan relatif dalam persen.
  final double humidity;
  final String weatherDesc;
  final String localDatetime;

  /// Kecepatan angin m/s (lapangan BMKG memakai kunci `ws`).
  final double? windSpeedMs;
  final String? windDirection;
  final double? latitude;
  final double? longitude;
  final bool fromCache;

  WeatherForecast copyWith({bool? fromCache}) => WeatherForecast(
    temperature: temperature,
    humidity: humidity,
    weatherDesc: weatherDesc,
    localDatetime: localDatetime,
    windSpeedMs: windSpeedMs,
    windDirection: windDirection,
    latitude: latitude,
    longitude: longitude,
    fromCache: fromCache ?? this.fromCache,
  );

  Map<String, dynamic> toJson() => {
    't': temperature,
    'hu': humidity,
    'weather_desc': weatherDesc,
    'local_datetime': localDatetime,
    if (windSpeedMs != null) 'ws': windSpeedMs,
    if (windDirection != null) 'wd': windDirection,
    if (latitude != null) 'lat': latitude,
    if (longitude != null) 'lon': longitude,
  };

  factory WeatherForecast.fromJson(Map<String, dynamic> json) =>
      WeatherForecast(
        temperature: (json['t'] as num).toDouble(),
        humidity: (json['hu'] as num?)?.toDouble() ?? 0.0,
        weatherDesc: json['weather_desc'] as String? ?? '-',
        localDatetime: json['local_datetime'] as String? ?? '',
        windSpeedMs: (json['ws'] as num?)?.toDouble(),
        windDirection: json['wd'] as String?,
        latitude: (json['lat'] as num?)?.toDouble(),
        longitude: (json['lon'] as num?)?.toDouble(),
      );
}
