import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_alert/l10n/l10n.dart';
import 'package:health_alert/models/air_quality.dart';
import 'package:health_alert/models/baseline.dart';
import 'package:health_alert/models/condition_result.dart';
import 'package:health_alert/models/health_data.dart';
import 'package:health_alert/models/health_sample.dart';
import 'package:health_alert/models/sensor_snapshot.dart';
import 'package:health_alert/models/threshold_set.dart';
import 'package:health_alert/models/weather_forecast.dart';
import 'package:health_alert/services/baseline_engine.dart';
import 'package:health_alert/services/rule_config.dart';
import 'package:health_alert/services/rule_engine.dart';
import 'package:health_alert/services/threshold_resolver.dart';

/// Acceptance test model rule-based v3 — nol input manual.
///
/// Skenario memakai [SensorSnapshot] (bacaan sensor + BMKG) dan [ThresholdSet]
/// (angka literatur yang dilebur baseline). Tidak ada lagi `stress_level` atau
/// centang "sudah dikonfirmasi": konfirmasi dihitung dari runtutan pembacaan
/// SpO2 dan ambang deviasi dihitung dari riwayat pemilik data.
///
/// Skenario 1-4 sengaja tanpa riwayat supaya skornya bisa dicocokkan persis
/// dengan angka di `assets/rule_config.json`; sisi dinamisnya diuji di
/// skenario 5 dan di `baseline_engine_test.dart`.
void main() {
  final config = RuleConfig.parse(
    File('assets/rule_config.json').readAsStringSync(),
  );
  final engine = RuleEngine(config);
  final resolver = ThresholdResolver(config, BaselineEngine(config));

  final sekarang = DateTime(2026, 11, 5, 10);

  /// Ambang murni literatur: tidak ada sampel riwayat sama sekali.
  final literatur = resolver.resolve(samples: const [], sekarang: sekarang);

  /// Enam belas hari nilai seragam: median = nilainya, MAD = 0 (terlalu
  /// seragam untuk dipakai sebagai skala), jadi ambang deviasi tetap angka
  /// jurnal sementara tier-nya sudah "personal".
  final riwayatPersonal = [
    for (var i = 1; i <= 16; i++)
      HealthSample(
        at: sekarang.subtract(Duration(days: i)),
        metrics: const {
          'resting_hr': 62.0,
          'hrv_rmssd': 45.0,
          'spo2': 96.0,
          'resp_rate': 16.0,
          'tidur_menit': 470.0,
          'tidur_efisiensi': 92.0,
          'suhu_ambient': 24.0,
          'angin_ms': 2.0,
          'pm25': 12.0,
          'hr_avg': 80.0,
          'olahraga_menit': 20.0,
        },
        levelTertinggi: AlertLevels.aman,
      ),
  ];
  final personal = resolver.resolve(
    samples: riwayatPersonal,
    sekarang: sekarang,
  );

  SensorSnapshot data({
    List<double> spo2 = const [],
    double rr = 16,
    int hrLatest = 72,
    int hrAvg = 72,
    double? rhr,
    double? hrvAvg,
    int? tidurMenit,
    int? inBedMenit,
    int? wasoMenit,
    double? olahragaMenit,
    int? cycleDay,
    double? panjangSiklus,
    double? suhu,
    double? rh,
    double? angin,
    double? pm25,
  }) => SensorSnapshot(
    at: sekarang,
    heartRate: HeartRateSummary(
      minBpm: hrAvg - 6,
      maxBpm: hrAvg + 30,
      avgBpm: hrAvg,
      latestBpm: hrLatest,
      sampleCount: 120,
      windowStart: sekarang.subtract(const Duration(hours: 12)),
      windowEnd: sekarang,
    ),
    restingHeartRate: rhr == null
        ? null
        : RestingHeartRateSummary(bpm: rhr, sampleCount: 1, at: sekarang),
    hrv: hrvAvg == null
        ? null
        : HrvSummary(
            latestMs: hrvAvg,
            avgMs: hrvAvg,
            minMs: hrvAvg * 0.8,
            sampleCount: 40,
          ),
    spo2: spo2.isEmpty
        ? null
        : Spo2Summary(
            latestPct: spo2.last,
            minPct: spo2.reduce((a, b) => a < b ? a : b),
            avgPct: spo2.fold<double>(0, (a, b) => a + b) / spo2.length,
            readings: spo2,
          ),
    respRate: RespRateSummary(
      latestPerMenit: rr,
      avgPerMenit: rr,
      maxPerMenit: rr + 3,
      sampleCount: 60,
    ),
    sleep: tidurMenit == null
        ? null
        : SleepSummary(
            startTime: sekarang.subtract(const Duration(hours: 20)),
            endTime: sekarang.subtract(const Duration(hours: 12)),
            totalSleepMinutes: tidurMenit,
            inBedMinutes: inBedMenit,
            wasoMinutes: wasoMenit,
          ),
    activity: olahragaMenit == null
        ? null
        : ActivitySummary(exerciseMinutes: olahragaMenit, sessionCount: 1),
    cycle: CycleInfo(
      cycleDay: cycleDay,
      cycleLengthDays: panjangSiklus,
      source: 'menstrualFlowInstant',
    ),
    cuaca: suhu == null
        ? null
        : WeatherForecast(
            temperature: suhu,
            humidity: rh ?? 60,
            weatherDesc: 'Berawan',
            localDatetime: '2026-11-05 10:00:00',
            windSpeedMs: angin,
          ),
    udara: pm25 == null ? null : AirQuality(pm25: pm25, fetchedAt: sekarang),
  );

  List<ConditionResult> cek(
    SensorSnapshot snapshot, {
    ThresholdSet? ambang,
    List<String>? kondisi,
  }) => engine.evaluasi(snapshot, ambang ?? literatur, kondisiAktif: kondisi);

  ConditionResult ambil(List<ConditionResult> hasil, String kondisi) =>
      hasil.firstWhere((x) => x.kondisi == kondisi);

  group('lima skenario penerimaan', () {
    test('1. Semua sensor normal — AMAN, alergi dingin tidak dinilai', () {
      final hasil = cek(
        data(
          spo2: const [98, 97, 98],
          rhr: 58,
          hrvAvg: 45,
          tidurMenit: 480,
          inBedMenit: 500,
          wasoMenit: 10,
          olahragaMenit: 45,
          cycleDay: 10,
        ),
      );

      expect(ambil(hasil, 'Bronkitis').skor, 0);
      expect(ambil(hasil, 'Bronkitis').level, AlertLevels.aman);
      expect(ambil(hasil, 'Bronkitis').intervensi, '');
      expect(ambil(hasil, 'Anxiety').skor, 0);
      expect(ambil(hasil, 'Anxiety').level, AlertLevels.aman);

      final alergi = ambil(hasil, 'Alergi Dingin');
      expect(alergi.level, AlertLevels.tidakDievaluasi);
      expect(alergi.skor, 0);
      expect(alergi.evaluated, isFalse);
      expect(alergi.butuhAlert, isFalse);
      expect(alergi.intervensi, '');
    });

    test('2. Flare bronkitis — SpO2 89 satu pembacaan belum terkonfirmasi', () {
      final hasil = cek(
        data(
          spo2: const [93, 89, 91],
          rr: 22,
          hrLatest: 108,
          hrAvg: 88,
          hrvAvg: 28,
          tidurMenit: 144,
          inBedMenit: 200,
          wasoMenit: 45,
          olahragaMenit: 0,
          cycleDay: 24,
        ),
      );

      final bronkitis = ambil(hasil, 'Bronkitis');
      // 25 hipoksemia + 12 takipnea ringan + 10 durasi + 8 efisiensi + 5 luteal
      expect(bronkitis.skor, 60);
      expect(bronkitis.level, AlertLevels.perhatian);
      expect(bronkitis.butuhAlert, isTrue);
      expect(
        bronkitis.alasanTeks(L10n.id),
        contains('SpO2 89% — hipoksemia (belum terkonfirmasi)'),
      );

      // 15 hr absolut + 15 durasi + 12 efisiensi + 8 waso + 5 minim + 10 luteal
      expect(ambil(hasil, 'Anxiety').skor, 65);
      expect(ambil(hasil, 'Anxiety').level, AlertLevels.perhatian);
      expect(ambil(hasil, 'Alergi Dingin').level, AlertLevels.tidakDievaluasi);
    });

    test(
      '3. Episode anxiety — HRV di bawah floor dan tidur terfragmentasi',
      () {
        final hasil = cek(
          data(
            spo2: const [97, 96, 97],
            hrLatest: 105,
            hrAvg: 90,
            hrvAvg: 15,
            tidurMenit: 168,
            inBedMenit: 200,
            wasoMenit: 40,
            olahragaMenit: 10,
            cycleDay: 26,
          ),
        );

        // 20 hrv floor + 15 hr absolut + 15 durasi + 12 efisiensi + 8 waso
        // + 5 olahraga minim + 10 luteal
        expect(ambil(hasil, 'Anxiety').skor, 85);
        expect(ambil(hasil, 'Anxiety').level, AlertLevels.bahaya);
        expect(ambil(hasil, 'Anxiety').butuhAlert, isTrue);
        expect(
          ambil(hasil, 'Anxiety').alasanTeks(L10n.id),
          contains('HRV 15 ms — di bawah batas 20 ms literatur'),
        );

        // 10 durasi + 8 efisiensi; gerbang luteal minta skor >= 20, tertutup
        expect(ambil(hasil, 'Bronkitis').skor, 18);
        expect(ambil(hasil, 'Bronkitis').level, AlertLevels.aman);
        expect(
          ambil(hasil, 'Alergi Dingin').level,
          AlertLevels.tidakDievaluasi,
        );
      },
    );

    test('4. Alergi dingin — suhu 5°C vs band literatur 18°C', () {
      final hasil = cek(
        data(
          spo2: const [96],
          hrLatest: 78,
          hrvAvg: 35,
          tidurMenit: 300,
          inBedMenit: 320,
          cycleDay: 22,
          suhu: 5,
          rh: 60,
          angin: 6,
          pm25: 40,
        ),
      );

      final alergi = ambil(hasil, 'Alergi Dingin');
      // 30 sangat dingin + 8 angin waspada + 10 luteal
      expect(alergi.skor, 48);
      expect(alergi.level, AlertLevels.perhatian);
      expect(alergi.evaluated, isTrue);
      expect(alergi.kalibrasi, 'literatur');
      expect(
        alergi.alasanTeks(L10n.id).first,
        'Suhu 5°C — sangat dingin, 13.0°C di bawah band literatur 18.0°C',
      );
      expect(
        alergi.intervensi,
        contains('Suhu 5C di bawah ambang personalmu 18.0C'),
      );
      expect(alergi.intervensi, isNot(contains('{')));

      // 10 durasi tidur + 8 PM2.5 waspada; gerbang luteal belum terlewati
      expect(ambil(hasil, 'Bronkitis').skor, 18);
      expect(ambil(hasil, 'Bronkitis').level, AlertLevels.aman);

      // 15 durasi tidur + 10 luteal
      expect(ambil(hasil, 'Anxiety').skor, 25);
      expect(ambil(hasil, 'Anxiety').level, AlertLevels.waspada);
    });

    test('5. Riwayat personal ikut menilai — desaturasi relatif aktif', () {
      final hasil = cek(
        data(
          spo2: const [95, 91],
          rr: 18,
          hrLatest: 95,
          hrAvg: 90,
          rhr: 70,
          hrvAvg: 30,
          tidurMenit: 216,
          inBedMenit: 260,
          olahragaMenit: 20,
          cycleDay: 25,
        ),
        ambang: personal,
      );

      final bronkitis = ambil(hasil, 'Bronkitis');
      // 18 hipoksemia ringan + 20 desaturasi + 20 HR di atas baseline
      // + 10 durasi + 8 efisiensi + 5 luteal
      expect(bronkitis.skor, 81);
      expect(bronkitis.level, AlertLevels.bahaya);
      expect(bronkitis.kalibrasi, 'personal');
      expect(
        bronkitis.alasanTeks(L10n.id),
        contains('SpO2 turun 5.0 poin dari baseline 96.0% (ambang 4.0)'),
      );

      final anxiety = ambil(hasil, 'Anxiety');
      // 35 HRV turun 33% dari baseline + 25 HR di atas baseline + 15 durasi
      // + 12 efisiensi + 10 luteal
      expect(anxiety.skor, 97);
      expect(anxiety.level, AlertLevels.bahaya);
      expect(anxiety.kalibrasi, 'personal');
      expect(
        anxiety.alasanTeks(L10n.id).first,
        startsWith('HRV 30 ms — turun 33%'),
      );

      expect(ambil(hasil, 'Alergi Dingin').level, AlertLevels.tidakDievaluasi);

      // Skenario yang sama tanpa riwayat: kedua aturan berbasis baseline mati.
      final tanpaRiwayat = cek(
        data(
          spo2: const [95, 91],
          rr: 18,
          hrLatest: 95,
          hrAvg: 90,
          rhr: 70,
          hrvAvg: 30,
          tidurMenit: 216,
          inBedMenit: 260,
          olahragaMenit: 20,
          cycleDay: 25,
        ),
      );
      // Tinggal 18 hipoksemia ringan + 10 durasi + 8 efisiensi + 5 luteal
      expect(ambil(tanpaRiwayat, 'Bronkitis').skor, 41);
      // Tinggal 15 durasi + 12 efisiensi + 10 luteal = 37
      expect(ambil(tanpaRiwayat, 'Anxiety').skor, 37);
      expect(ambil(tanpaRiwayat, 'Bronkitis').kalibrasi, 'literatur');
    });
  });

  group('kontrak keras', () {
    test('snapshot kosong total tidak melempar dan tidak memicu alert', () {
      final hasil = cek(SensorSnapshot(at: sekarang));

      expect(hasil.map((r) => r.level), [
        AlertLevels.aman,
        AlertLevels.aman,
        AlertLevels.tidakDievaluasi,
      ]);
      expect(hasil.any((r) => r.butuhAlert), isFalse);
      expect(hasil.every((r) => r.skor == 0), isTrue);
      expect(hasil.every((r) => !r.intervensi.contains('{')), isTrue);
    });

    test(
      'suhu null selalu TIDAK_DIEVALUASI meski tubuh penuh sinyal darurat',
      () {
        final alergi = ambil(
          cek(
            data(
              spo2: const [88, 87],
              rr: 26,
              hrLatest: 130,
              hrvAvg: 8,
              tidurMenit: 90,
            ),
          ),
          'Alergi Dingin',
        );

        expect(alergi.level, AlertLevels.tidakDievaluasi);
        expect(alergi.evaluated, isFalse);
        expect(alergi.alasanTeks(L10n.id), const [
          'Data suhu lingkungan tidak tersedia',
        ]);
      },
    );

    test('runtutan SpO2 mengonfirmasi hipoksemia tanpa centangan manual', () {
      List<ConditionResult> dengan(List<double> readings) =>
          cek(data(spo2: readings, hrLatest: 88));

      // Satu pembacaan di bawah 90 -> belum terkonfirmasi (25).
      expect(ambil(dengan(const [93, 89, 92]), 'Bronkitis').skor, 25);
      // Dua pembacaan beruntun -> terkonfirmasi (40).
      expect(ambil(dengan(const [93, 89, 88, 92]), 'Bronkitis').skor, 40);
    });

    test('skor dikunci ke rentang 0-100', () {
      final hasil = cek(
        data(
          spo2: const [85, 84, 83],
          rr: 32,
          hrLatest: 160,
          hrvAvg: 5,
          tidurMenit: 60,
          inBedMenit: 90,
          wasoMenit: 50,
          olahragaMenit: 0,
          cycleDay: 25,
          pm25: 200,
        ),
        ambang: personal,
      );

      expect(ambil(hasil, 'Anxiety').skor, 100);
      expect(ambil(hasil, 'Anxiety').level, AlertLevels.bahaya);
      expect(ambil(hasil, 'Bronkitis').skor, 100);
      expect(
        hasil.every((r) => r.skor >= 0 && r.skor <= 100),
        isTrue,
        reason: 'skor harus selalu di dalam rentang yang dilaporkan UI',
      );
    });

    test('hanya kondisi pada profil personal yang dinilai', () {
      final hasil = cek(
        data(suhu: 4, cycleDay: 20, hrvAvg: 10),
        kondisi: const ['Anxiety', 'Alergi Dingin'],
      );

      expect(hasil.map((r) => r.kondisi), ['Anxiety', 'Alergi Dingin']);
      expect(config.profilDefault['kondisi'], [
        'Bronkitis Kronis',
        'Anxiety',
        'Alergi Dingin',
      ]);
    });

    test(
      'fase siklus memakai panjang siklus dari data, bukan asumsi 28 hari',
      () {
        expect(RuleEngine.faseSiklus(22, panjangSiklus: 28), 'luteal');
        expect(RuleEngine.faseSiklus(15, panjangSiklus: 32), 'folikular');
        expect(RuleEngine.faseSiklus(3, panjangSiklus: 32), 'menstruasi');
        expect(RuleEngine.faseSiklus(26, panjangSiklus: 32), 'luteal');
        expect(RuleEngine.faseSiklus(null), 'tidak_diketahui');
      },
    );

    test('ambang dingin hasil belajar dipakai sebagai pembanding suhu', () {
      // Belajar dari 3 hari reaksi (laju napas 22 >= ambang reaksi 21) pada
      // suhu 19.0 / 18.0 / 17.2°C -> reaksi terpanas 19.0 + margin 1.0 = 20.0.
      final dingin = [
        for (var i = 1; i <= 12; i++)
          HealthSample(
            at: sekarang.subtract(Duration(days: i)),
            metrics: const {
              'resting_hr': 62.0,
              'resp_rate': 15.0,
              'spo2': 96.0,
              'suhu_ambient': 20.0,
            },
          ),
        for (final (hari, suhu) in const [(13, 19.0), (14, 18.0), (15, 17.2)])
          HealthSample(
            at: sekarang.subtract(Duration(days: hari)),
            metrics: {
              'resting_hr': 62.0,
              'resp_rate': 22.0,
              'spo2': 96.0,
              'suhu_ambient': suhu,
            },
          ),
      ];
      final ambang = resolver.resolve(samples: dingin, sekarang: sekarang);
      expect(ambang.tierAmbangSuhu, TierKalibrasi.personal);
      expect(ambang.ambangSuhuPersonal, 20.0);
      expect(ambang.kejadianReaksiDingin, 3);

      // 19°C kini "mendekati" ambang personal meski pada band literatur 18°C
      // suhu yang sama tidak menghasilkan poin sama sekali. RHR disamakan
      // dengan baseline (62) supaya hanya efek ambang dingin yang dinilai.
      final hasil = cek(data(suhu: 19, angin: 2, rhr: 62), ambang: ambang);
      final alergi = ambil(hasil, 'Alergi Dingin');
      expect(alergi.skor, 10);
      expect(alergi.level, AlertLevels.aman);
      expect(alergi.kalibrasi, 'personal');
      expect(
        alergi.alasanTeks(L10n.id).first,
        'Suhu 19°C — mendekati ambang personal 20.0°C (3 reaksi tercatat)',
      );

      expect(ambil(cek(data(suhu: 19, angin: 2)), 'Alergi Dingin').skor, 0);
    });
  });
}
