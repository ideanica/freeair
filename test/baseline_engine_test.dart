import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:health_alert/l10n/l10n.dart';
import 'package:health_alert/models/baseline.dart';
import 'package:health_alert/models/condition_result.dart';
import 'package:health_alert/models/health_sample.dart';
import 'package:health_alert/services/baseline_engine.dart';
import 'package:health_alert/services/rule_config.dart';
import 'package:health_alert/services/threshold_resolver.dart';

/// Uji sisi "dinamis": ambang yang sama sekali tidak diketik pengguna,
/// melainkan dihitung dari riwayat sampel siklus pemilik data.
void main() {
  final config = RuleConfig.parse(
    File('assets/rule_config.json').readAsStringSync(),
  );
  final baselineEngine = BaselineEngine(config);
  final resolver = ThresholdResolver(config, baselineEngine);

  final sekarang = DateTime(2026, 11, 5, 10);

  /// Satu sampel per hari (median harian = nilainya sendiri).
  List<HealthSample> harian(
    Map<String, List<double>> metrik, {
    String level = AlertLevels.aman,
    int mulaiDari = 1,
  }) {
    final panjang = metrik.values
        .map((v) => v.length)
        .reduce((a, b) => a > b ? a : b);
    return [
      for (var i = 0; i < panjang; i++)
        HealthSample(
          at: sekarang.subtract(Duration(days: mulaiDari + i)),
          metrics: {
            for (final entry in metrik.entries)
              if (i < entry.value.length) entry.key: entry.value[i],
          },
          levelTertinggi: level,
        ),
    ];
  }

  BaselineSet baseline(List<HealthSample> samples) =>
      baselineEngine.hitung(samples, sekarang: sekarang);

  group('statistik robust', () {
    test(
      'median harian, bukan rata-rata: satu hari liar tidak menggoyahkan',
      () {
        final b = baseline(
          harian({
            'resting_hr': [72, 62, 62, 62, 62, 62, 62, 62, 62],
          }),
        );
        final s = b['resting_hr'];

        expect(s.jumlahHari, 9);
        expect(s.median, 62);
        // Deviasi: 10, lalu 8 nol -> median = 0 -> MAD dianggap tidak berguna.
        expect(s.mad, isNull);
        expect(s.tersedia, isTrue);
      },
    );

    test('MAD terisi ketika hariannya benar-benar berayun', () {
      final b = baseline(
        harian({
          'resting_hr': [56, 68, 56, 68, 56, 68, 56, 68, 56, 68],
        }),
      );
      final s = b['resting_hr'];

      expect(s.median, 62);
      expect(s.mad, 6);
      // modifikasi z-score Iglewicz-Hoaglin: 0.6745 * (100 - 62) / 6
      expect(s.zSkor(100), closeTo(4.27, 0.01));
      expect(baselineEngine.isOutlier('resting_hr', b, 100), isTrue);
      expect(baselineEngine.isOutlier('resting_hr', b, 90), isFalse);
      // MAD nol -> tidak ada skala -> tidak ada outlier yang bisa dinyatakan
      expect(baselineEngine.isOutlier('tidur_menit', b, 1), isFalse);
    });

    test('hari sakit (PERHATIAN/BAHAYA) dikeluarkan dari baseline', () {
      final samples = [
        ...harian({
          'resting_hr': [60, 60, 60],
        }),
        ...harian(
          {
            'resting_hr': [92],
          },
          level: AlertLevels.perhatian,
          mulaiDari: 4,
        ),
        ...harian(
          {
            'resting_hr': [96],
          },
          level: AlertLevels.bahaya,
          mulaiDari: 5,
        ),
      ];
      final b = baseline(samples);

      expect(b['resting_hr'].jumlahHari, 3);
      expect(b['resting_hr'].median, 60);
    });

    test('sampel di luar jendela 28 hari diabaikan', () {
      final b = baseline(
        harian({
          'resting_hr': [60, 60, 60, 60, 60, 60, 60, 99],
        }, mulaiDari: 35),
      );

      expect(b['resting_hr'].jumlahHari, 0);
      expect(b['resting_hr'].tersedia, isFalse);
      expect(b.jendelaHari, config.jendelaHari);
    });

    test('kecukupan data dilaporkan per metrik untuk UI', () {
      final laporan = baselineEngine.laporanKecukupanData(
        baseline(
          harian({
            'resting_hr': [60, 61, 62, 63, 64, 65, 66],
          }),
        ),
      );

      expect(laporan.first, 'Detak jantung istirahat: 7/14 hari');
      expect(laporan.length, config.metrikDinamis.length);
      expect(laporan.last, contains('0/14 hari'));
    });
  });

  group('tier kalibrasi', () {
    TierKalibrasi tierDari(int hari) {
      final b = baseline(
        harian({
          'resting_hr': [for (var i = 0; i < hari; i++) 60.0 + (i % 3)],
        }),
      );
      return b.tier(
        'resting_hr',
        minimumPersonal: config.minimumHariPersonal,
        minimumSebagian: config.minimumHariSebagian,
      );
    }

    test('cold-start: belum ada data -> murni literatur', () {
      expect(tierDari(0), TierKalibrasi.literatur);
      expect(baseline(const [])['resting_hr'].median, isNull);
    });

    test('6 hari belum cukup, 7 hari sebagian, 14 hari personal', () {
      expect(tierDari(6), TierKalibrasi.literatur);
      expect(tierDari(7), TierKalibrasi.sebagian);
      expect(tierDari(13), TierKalibrasi.sebagian);
      expect(tierDari(14), TierKalibrasi.personal);
    });

    test(
      'tier SEBAGIAN mencampur, belum sepenuhnya percaya median pribadi',
      () {
        final b = baseline(
          harian({
            'resting_hr': [60, 60, 60, 60, 60, 60, 60],
          }),
        );
        final nilai = b.nilaiEfektif(
          'resting_hr',
          literatur: 100,
          minimumPersonal: config.minimumHariPersonal,
          minimumSebagian: config.minimumHariSebagian,
          bobotPersonal: config.bobotCampurPersonal,
        );

        // w = 0.6 * (7/14) = 0.30 -> 100*0.7 + 60*0.3
        expect(nilai, 88);
        expect(
          b.nilaiEfektif(
            'pm25',
            literatur: 35.4,
            minimumPersonal: 14,
            minimumSebagian: 7,
            bobotPersonal: 0.6,
          ),
          35.4,
          reason: 'metrik tanpa data harus tetap angka jurnal',
        );
      },
    );
  });

  group('pelebaran ambang mengikuti variabilitas pribadi', () {
    test(
      'MAD besar melonggarkan ambang delta HR (tidak pernah mengetatkan)',
      () {
        // median 62, MAD 3 -> 2.0 * 3 = 6 bpm, lebih longgar dari 5 bpm jurnal
        final longgar = resolver.resolve(
          samples: harian({
            'resting_hr': [62, 59, 65, 62, 59, 65, 62],
          }),
          sekarang: sekarang,
        );
        expect(longgar.baseline['resting_hr'].mad, 3);
        expect(longgar.hrDeltaWaspada, 6);
        expect(longgar.hrDeltaBahaya, 8);

        // median 62, MAD 1 -> 2.0 * 1 = 2 bpm, TIDAK boleh di bawah 5 bpm
        final ketat = resolver.resolve(
          samples: harian({
            'resting_hr': [61, 63, 61, 63, 61, 63, 61, 63],
          }),
          sekarang: sekarang,
        );
        expect(ketat.baseline['resting_hr'].mad, 1);
        expect(ketat.hrDeltaWaspada, 5);
      },
    );

    test('HRV yang secara alami fluktuatif memakai ambang persen pribadi', () {
      // median 40 ms, MAD 6 ms -> 15% -> 2.0 * 15 = 30% (jurnal: 10% dan 25%)
      final ambang = resolver.resolve(
        samples: harian({
          'hrv_rmssd': [34, 46, 34, 46, 34, 46, 34, 46],
        }),
        sekarang: sekarang,
      );

      expect(ambang.baseline['hrv_rmssd'].median, 40);
      expect(ambang.baseline['hrv_rmssd'].mad, 6);
      expect(ambang.hrvDropWaspadaPct, 30);
      expect(ambang.hrvDropPerhatianPct, 30);
      // floor absolut tetap angka literatur
      expect(ambang.hrvFloor, 20);
    });

    test('belum ada riwayat -> semua ambang deviasi = angka literatur', () {
      final ambang = resolver.resolve(samples: const [], sekarang: sekarang);

      expect(ambang.spo2Ringan, 94);
      expect(ambang.spo2Hipoksemia, 90);
      expect(ambang.spo2KonfirmasiMinBacaan, 2);
      expect(ambang.spo2DropPct, 4);
      expect(ambang.rrWaspada, 21);
      expect(ambang.rrBahaya, 24);
      expect(ambang.hrDeltaWaspada, 5);
      expect(ambang.hrvDropPerhatianPct, 25);
      expect(ambang.tidurDurasiJam, 7);
      expect(ambang.tidurEfisiensiMin, 85);
      expect(ambang.tidurWasoMin, 31);
      expect(ambang.pm25Waspada, 35.4);
      expect(ambang.baselineSpo2, isNull);
      expect(ambang.baselineRestingHr, isNull);
      expect(
        ambang.provenance.every((p) => p.tier == TierKalibrasi.literatur),
        isTrue,
      );
    });

    test('setiap ambang punya kutipan jurnal', () {
      final sumber = resolver
          .resolve(samples: const [], sekarang: sekarang)
          .provenance;

      expect(sumber.every((p) => p.sumberKey.trim().isNotEmpty), isTrue);
      expect(
        config.sumberTeks(
          sumber.firstWhere((p) => p.labelKey == 'ambang.spo2').sumberKey,
        ),
        contains('GOLD 2024'),
      );
      expect(
        config.sumberTeks(
          sumber
              .firstWhere((p) => p.labelKey == 'ambang.tidur_durasi')
              .sumberKey,
        ),
        contains('AASM'),
      );
    });
  });

  group('pembelajaran ambang suhu dingin', () {
    const tenang = {
      'resting_hr': 62.0,
      'resp_rate': 15.0,
      'spo2': 96.0,
      'suhu_ambient': 24.0,
    };

    test('belum ada reaksi -> memakai band literatur', () {
      final hasil = baselineEngine.belajarAmbangDingin(
        harian({
          'resting_hr': [for (var i = 0; i < 10; i++) 62.0],
          'resp_rate': [for (var i = 0; i < 10; i++) 15.0],
          'spo2': [for (var i = 0; i < 10; i++) 96.0],
          'suhu_ambient': [for (var i = 0; i < 10; i++) 24.0],
        }),
        baseline(
          harian({
            'resting_hr': [for (var i = 0; i < 10; i++) 62.0],
          }),
        ),
        suhuLiteratur: 18,
        sekarang: sekarang,
      );

      expect(hasil.ambang, 18);
      expect(hasil.tier, TierKalibrasi.literatur);
      expect(hasil.kejadian, 0);
      expect(hasil.suhuReaksiTerpanas, isNull);
    });

    test('1-2 kejadian dicampur dengan literatur (tier sebagian)', () {
      final samples = [
        ...harian({
          'resting_hr': [for (var i = 0; i < 10; i++) 62.0],
          'resp_rate': [for (var i = 0; i < 10; i++) 15.0],
          'spo2': [for (var i = 0; i < 10; i++) 96.0],
          'suhu_ambient': [for (var i = 0; i < 10; i++) 24.0],
        }),
        ...harian({
          'resting_hr': [62.0],
          'resp_rate': [23.0],
          'spo2': [96.0],
          'suhu_ambient': [19.0],
        }, mulaiDari: 11),
      ];
      final hasil = baselineEngine.belajarAmbangDingin(
        samples,
        baseline(samples),
        suhuLiteratur: 18,
        sekarang: sekarang,
      );

      // (19 + 18) / 2 + margin aman 1.0
      expect(hasil.ambang, 19.5);
      expect(hasil.tier, TierKalibrasi.sebagian);
      expect(hasil.kejadian, 1);
      expect(hasil.suhuReaksiTerpanas, 19.0);
    });

    test('>=3 kejadian: ambang = reaksi TERPANAS + margin aman', () {
      final samples = [
        for (var i = 1; i <= 10; i++)
          HealthSample(
            at: sekarang.subtract(Duration(days: i)),
            metrics: tenang,
          ),
        for (final (hari, suhu) in const [(11, 19.0), (12, 18.0), (13, 17.2)])
          HealthSample(
            at: sekarang.subtract(Duration(days: hari)),
            metrics: {...tenang, 'resp_rate': 22.0, 'suhu_ambient': suhu},
          ),
      ];
      final hasil = baselineEngine.belajarAmbangDingin(
        samples,
        baseline(samples),
        suhuLiteratur: 18,
        sekarang: sekarang,
      );

      expect(hasil.kejadian, 3);
      expect(hasil.suhuReaksiTerpanas, 19.0);
      expect(hasil.ambang, 20.0);
      expect(hasil.tier, TierKalibrasi.personal);
    });

    test('reakasi dikenali dari HR, laju napas, ATAU desaturasi SpO2', () {
      AmbangDinginHasil hitung(Map<String, double> reaksi) {
        final samples = [
          for (var i = 1; i <= 10; i++)
            HealthSample(
              at: sekarang.subtract(Duration(days: i)),
              metrics: tenang,
            ),
          HealthSample(
            at: sekarang.subtract(const Duration(days: 11)),
            metrics: {...tenang, ...reaksi, 'suhu_ambient': 21.0},
          ),
        ];
        return baselineEngine.belajarAmbangDingin(
          samples,
          baseline(samples),
          suhuLiteratur: 18,
          sekarang: sekarang,
        );
      }

      // HR 70 vs baseline 62 = delta 8 bpm = ambang reaksi
      expect(hitung({'resting_hr': 70.0}).kejadian, 1);
      // Laju napas 21 melewati ambang reaksi
      expect(hitung({'resp_rate': 21.0}).kejadian, 1);
      // SpO2 92 vs baseline 96 = turun 4.17%
      expect(hitung({'spo2': 92.0}).kejadian, 1);
      // Tidak ada reaksi sama sekali
      expect(hitung({'resting_hr': 63.0, 'resp_rate': 16.0}).kejadian, 0);
      // Hari tanpa suhu lingkungan tidak bisa jadi bukti
      expect(
        hitung({'resting_hr': 70.0, 'suhu_ambient': 21.0}).suhuReaksiTerpanas,
        21.0,
      );
    });

    test('resolver memaparkan hasil belajar di provenance', () {
      final samples = [
        for (var i = 1; i <= 10; i++)
          HealthSample(
            at: sekarang.subtract(Duration(days: i)),
            metrics: tenang,
          ),
        for (final (hari, suhu) in const [(11, 19.0), (12, 18.5), (13, 17.0)])
          HealthSample(
            at: sekarang.subtract(Duration(days: hari)),
            metrics: {...tenang, 'resp_rate': 22.0, 'suhu_ambient': suhu},
          ),
      ];
      final info = resolver
          .resolve(samples: samples, sekarang: sekarang)
          .provenance
          .firstWhere((p) => p.labelKey == 'ambang.suhu_dingin');

      expect(info.tier, TierKalibrasi.personal);
      expect(info.nilai, 20.0);
      expect(
        info.detail(L10n.id),
        contains('reaksi terpanas tercatat pada 19.0°C'),
      );
      expect(info.detail(L10n.id), contains('3 kejadian'));
      expect(config.sumberTeks(info.sumberKey), contains('Van Gerven 2012'));
    });
  });
}
