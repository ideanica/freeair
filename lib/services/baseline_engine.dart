import 'dart:math' as math;

import '../l10n/l10n.dart';
import '../models/baseline.dart';
import '../models/condition_result.dart';
import '../models/health_sample.dart';
import 'rule_config.dart';

/// Hasil pembelajaran ambang suhu dingin dari riwayat reaksi fisiologis.
class AmbangDinginHasil {
  const AmbangDinginHasil({
    required this.ambang,
    required this.tier,
    required this.kejadian,
    this.suhuReaksiTerpanas,
  });

  final double ambang;
  final TierKalibrasi tier;

  /// Berapa kejadian reaksi yang mendasari.
  final int kejadian;

  /// Suhu terpanas di mana tubuh masih bereaksi — inti ambang personal.
  final double? suhuReaksiTerpanas;
}

/// Mengubah tumpukan sampel siklus menjadi baseline personal yang robust.
///
/// Metode: median harian (bukan rata-rata) lalu median + MAD lintas hari,
/// dengan hari-hari sakit dikeluarkan agar episode tidak menaikkan/menurunkan
/// baseline pemakainya sendiri. Angka jendela dan ambang hari minimum semuanya
/// dari rule_config.json.
class BaselineEngine {
  BaselineEngine(this.config);

  final RuleConfig config;

  static const List<String> _levelHariSakit = [
    AlertLevels.perhatian,
    AlertLevels.bahaya,
  ];

  BaselineSet hitung(List<HealthSample> samples, {DateTime? sekarang}) {
    final jendela = config.jendelaHari;
    final awal = (sekarang ?? DateTime.now()).subtract(Duration(days: jendela));

    // Median per hari per metrik, hari sakit dibuang.
    final harian = <String, Map<String, List<double>>>{};
    for (final s in samples) {
      if (s.at.isBefore(awal)) continue;
      if (_levelHariSakit.contains(s.levelTertinggi)) continue;
      final hari = harian.putIfAbsent(
        s.tanggal,
        () => <String, List<double>>{},
      );
      s.metrics.forEach((key, nilai) {
        hari.putIfAbsent(key, () => <double>[]).add(nilai);
      });
    }

    final metrik = <String, Statistik>{};

    for (final key in config.metrikDinamis.keys) {
      final nilaiHarian = <double>[];
      for (final hari in harian.entries) {
        final deret = hari.value[key];
        if (deret != null && deret.isNotEmpty) {
          nilaiHarian.add(median(deret));
        }
      }
      metrik[key] = statistikUntuk(key, nilaiHarian);
    }

    return BaselineSet(metrik: metrik, jendelaHari: jendela);
  }

  Statistik statistikUntuk(String key, List<double> nilaiHarian) {
    if (nilaiHarian.isEmpty) return Statistik(key: key, jumlahHari: 0);
    final m = median(nilaiHarian);
    final deviasi = nilaiHarian.map((v) => (v - m).abs()).toList();
    final madDeviasi = deviasi.isEmpty ? null : median(deviasi);
    return Statistik(
      key: key,
      jumlahHari: nilaiHarian.length,
      median: m,
      // MAD nol berarti data terlalu seragam untuk dipakai sebagai skala.
      mad: (madDeviasi == null || madDeviasi == 0) ? null : madDeviasi,
      terakhir: nilaiHarian.last,
      nilai: List<double>.unmodifiable(nilaiHarian),
    );
  }

  static double median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = values.toList()..sort();
    final n = sorted.length;
    final tengah = n ~/ 2;
    return n.isOdd ? sorted[tengah] : (sorted[tengah - 1] + sorted[tengah]) / 2;
  }

  /// Modified z-score Iglewicz-Hoaglin; `null` bila MAD belum tersedia.
  double? zSkor(String key, BaselineSet baseline, double nilai) =>
      baseline[key].zSkor(nilai);

  bool isOutlier(String key, BaselineSet baseline, double nilai) {
    final z = zSkor(key, baseline, nilai);
    if (z == null) return false;
    return z.abs() > config.outlierMadScore;
  }

  /// Belajar ambang suhu dingin dari suhu terpanas saat tubuh bereaksi.
  ///
  /// Reaksi = HR naik >= delta dari baseline RHR pribadi, ATAU laju napas
  /// melewati batas takipnea ringan, ATAU SpO2 turun >= ambang desaturasi.
  /// Semua ambang reaksi dari `pembelajaran_ambang_dingin` di config.
  AmbangDinginHasil belajarAmbangDingin(
    List<HealthSample> samples,
    BaselineSet baseline, {
    required double suhuLiteratur,
    DateTime? sekarang,
  }) {
    final awal = (sekarang ?? DateTime.now()).subtract(
      Duration(days: config.jendelaHari),
    );

    final hrBaseline = baseline['resting_hr'].median;
    final rrBaseline = baseline['resp_rate'].median;
    final spo2Baseline = baseline['spo2'].median;
    final dropMinimal = config.lit('desaturasi_personal', 'drop_pct_min');

    final suhuReaksi = <double>[];
    for (final s in samples) {
      if (s.at.isBefore(awal)) continue;
      final suhu = s.nilai('suhu_ambient');
      if (suhu == null) continue;

      var bereaksi = false;
      final hr = s.nilai('resting_hr') ?? s.nilai('hr_avg');
      if (hr != null && hrBaseline != null) {
        bereaksi = bereaksi || (hr - hrBaseline) >= config.reaksiHrDelta;
      }
      final rr = s.nilai('resp_rate');
      if (rr != null) {
        bereaksi =
            bereaksi ||
            rr >= config.reaksiRrMin ||
            (rrBaseline != null && rr - rrBaseline >= config.reaksiRrDelta);
      }
      final spo2 = s.nilai('spo2');
      if (spo2 != null && spo2Baseline != null && spo2Baseline > 0) {
        final drop = (spo2Baseline - spo2) / spo2Baseline * 100;
        bereaksi =
            bereaksi || drop >= math.max(config.reaksiSpo2Drop, dropMinimal);
      }

      if (bereaksi) suhuReaksi.add(suhu);
    }

    final jumlah = suhuReaksi.length;
    if (jumlah == 0) {
      return AmbangDinginHasil(
        ambang: suhuLiteratur,
        tier: TierKalibrasi.literatur,
        kejadian: 0,
      );
    }

    final terpanas = suhuReaksi.reduce(math.max);

    if (jumlah < config.minimumKejadianDingin) {
      // Baru ada satu-dua kejadian: campur separuh dengan literatur supaya
      // satu hari aneh tidak langsung mengubah ambang.
      final campuran = (terpanas + suhuLiteratur) / 2 + config.marginAmanDingin;
      return AmbangDinginHasil(
        ambang: campuran,
        tier: TierKalibrasi.sebagian,
        kejadian: jumlah,
        suhuReaksiTerpanas: terpanas,
      );
    }

    return AmbangDinginHasil(
      ambang: terpanas + config.marginAmanDingin,
      tier: TierKalibrasi.personal,
      kejadian: jumlah,
      suhuReaksiTerpanas: terpanas,
    );
  }

  /// Ringkasan untuk UI: metrik mana sudah cukup hari untuk dipakai personal.
  List<String> laporanKecukupanData(
    BaselineSet baseline, {
    String locale = 'id',
  }) {
    final kamus = L10n.untuk(locale);
    return [
      for (final key in config.metrikDinamis.keys)
        kamus.t('baseline.kecukupan', {
          'label': config.metrikLabel(key, locale: locale),
          'hari': '${baseline[key].jumlahHari}',
          'target': '${config.minimumHariPersonal}',
        }),
    ];
  }
}
