import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_alert/services/weather_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  String bmkgBody(
    List<Map<String, dynamic>> day0,
    List<Map<String, dynamic>> day1,
  ) {
    return jsonEncode({
      'data': [
        {
          'lokasi': {'desa': 'Yosomulyo'},
          'cuaca': [day0, day1],
        },
      ],
    });
  }

  Map<String, dynamic> entry(
    String localDatetime,
    double t,
    double hu,
    String desc,
  ) {
    return {
      'datetime': '2026-11-04T16:00:00Z',
      't': t,
      'hu': hu,
      'weather_desc': desc,
      'local_datetime': localDatetime,
    };
  }

  test('mengambil entri yang paling dekat dengan waktu sekarang', () async {
    final now = DateTime.now();
    final nearby = now.subtract(const Duration(minutes: 10));
    final farFuture = now.add(const Duration(hours: 20));

    String stamp(DateTime time) =>
        '${time.year}-${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:00';

    final service = WeatherService(
      client: MockClient(
        (request) async => http.Response(
          bmkgBody(
            [entry(stamp(farFuture), 18.0, 90.0, 'Hujan Ringan')],
            [
              entry(stamp(nearby), 25.5, 96.0, 'Berawan'),
              entry(stamp(farFuture), 18.0, 90.0, 'Hujan Ringan'),
            ],
          ),
          200,
        ),
      ),
    );

    final forecast = await service.getForecast();

    expect(forecast, isNotNull);
    expect(forecast!.temperature, 25.5);
    expect(forecast.humidity, 96.0);
    expect(forecast.weatherDesc, 'Berawan');
  });

  test('mengembalikan null saat respons tidak sesuai struktur', () async {
    final service = WeatherService(
      client: MockClient((_) async => http.Response('{"data":[]}', 200)),
    );

    expect(await service.getForecast(), isNull);
  });

  String jamSekarang() {
    final t = DateTime.now();
    String dua(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${dua(t.month)}-${dua(t.day)} ${dua(t.hour)}:00:00';
  }

  WeatherService serviceSekarang({
    required Map<String, dynamic> lokasi,
    required Map<String, dynamic> entry,
  }) => WeatherService(
    client: MockClient(
      (_) async => http.Response(
        jsonEncode({
          'data': [
            {
              'lokasi': lokasi,
              'cuaca': [
                [entry],
              ],
            },
          ],
        }),
        200,
      ),
    ),
  );

  test('angin dan koordinat lokasi ikut dibaca', () async {
    // Bentuk balasan BMKG sungguhan: lat/lon numerik di blok `lokasi`.
    final forecast = await serviceSekarang(
      lokasi: {'lat': -8.4041531021, 'lon': 114.170236537},
      entry: {
        't': 21.0,
        'hu': 70.0,
        'ws': 6.4,
        'wd': 'WNW',
        'weather_desc': 'Berawan',
        'local_datetime': jamSekarang(),
      },
    ).getForecast();

    expect(forecast!.windSpeedMs, 6.4);
    expect(forecast.windDirection, 'WNW');
    // Koordinat inilah yang membuat kualitas udara bisa diambil tanpa API key.
    expect(forecast.latitude, closeTo(-8.40415, 0.0001));
    expect(forecast.longitude, closeTo(114.17023, 0.0001));
  });

  test('koordinat dan angka berbasis string tetap terbaca', () async {
    final forecast = await serviceSekarang(
      lokasi: {'latitude': '-8.40', 'longitude': '114.17'},
      entry: {
        't': '19.5',
        'hu': '65',
        'weather_desc': 'Cerah',
        'local_datetime': jamSekarang(),
      },
    ).getForecast();

    expect(forecast!.temperature, 19.5);
    expect(forecast.humidity, 65.0);
    expect(forecast.latitude, closeTo(-8.40, 0.001));
    expect(forecast.longitude, closeTo(114.17, 0.001));
  });

  test('prakiraan dipakai ulang dari cache tanpa memanggil API', () async {
    var panggilan = 0;
    final service = WeatherService(
      client: MockClient((_) async {
        panggilan++;
        return http.Response(
          jsonEncode({
            'data': [
              {
                'lokasi': {'lat': -8.4041531021, 'lon': 114.170236537},
                'cuaca': [
                  [
                    {
                      't': 19.0,
                      'hu': 65.0,
                      'weather_desc': 'Cerah',
                      'local_datetime': jamSekarang(),
                    },
                  ],
                ],
              },
            ],
          }),
          200,
        );
      }),
    );

    final pertama = await service.getForecast();
    final kedua = await service.getForecast();

    expect(pertama!.temperature, 19.0);
    expect(kedua!.temperature, 19.0);
    expect(kedua.fromCache, isTrue);
    expect(panggilan, 1);

    // Paksa refresh tetap menyentuh API — dipakai tombol sinkron di beranda.
    await service.getForecast(forceRefresh: true);
    expect(panggilan, 2);
  });
}
