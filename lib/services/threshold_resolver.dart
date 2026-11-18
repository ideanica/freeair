import 'dart:math' as math;

import '../models/baseline.dart';
import '../models/health_sample.dart';
import '../models/threshold_set.dart';
import 'baseline_engine.dart';
import 'rule_config.dart';

/// Menggabungkan angka literatur dengan baseline personal menjadi satu set
/// ambang untuk satu siklus.
///
/// Di sinilah "dinamis" terjadi. Setiap ambang deviasi dipilih antara tiga
/// kemungkinan: murni literatur (belum ada data), campuran (data mulai
/// terkumpul), atau personal (median/MAD pemilik data). Ambang deviasi juga
/// dilebarkan mengikuti variabilitas harian pribadi supaya orang yang
/// fluktuatif tidak kebanjiran alert palsu.
class ThresholdResolver {
  ThresholdResolver(this.config, this.baselineEngine);

  final RuleConfig config;
  final BaselineEngine baselineEngine;

  ThresholdSet resolve({
    List<HealthSample> samples = const [],
    DateTime? sekarang,
  }) {
    final baseline = baselineEngine.hitung(samples, sekarang: sekarang);
    final dingin = baselineEngine.belajarAmbangDingin(
      samples,
      baseline,
      suhuLiteratur: config.lit('udara_dingin', 'suhu_perhatian'),
      sekarang: sekarang,
    );

    final spo2 = config.litSpo2;
    final hr = config.litDetakJantung;
    final hrv = config.litHrv;
    final tidur = config.litTidur;
    final dinginLit = config.litDingin;
    final partikulat = config.litPartikulat;
    final siklus = config.litSiklus;

    final dropSpo2 = deviasiUnit(
      'spo2',
      baseline,
      config.lit('desaturasi_personal', 'drop_pct_min'),
    );
    final hrDeltaWaspada = deviasiUnit(
      'resting_hr',
      baseline,
      (hr['delta_baseline_waspada_bpm'] as num).toDouble(),
    );
    final hrDeltaBahaya = math.max(
      deviasiUnit(
        'resting_hr',
        baseline,
        (hr['delta_baseline_bahaya_bpm'] as num).toDouble(),
      ),
      hrDeltaWaspada,
    );
    final hrvDropWaspada = deviasiPersen(
      'hrv_rmssd',
      baseline,
      (hrv['drop_pct_waspada'] as num).toDouble(),
    );
    final hrvDropPerhatian = math.max(
      deviasiPersen(
        'hrv_rmssd',
        baseline,
        (hrv['drop_pct_perhatian'] as num).toDouble(),
      ),
      hrvDropWaspada,
    );

    return ThresholdSet(
      literatur: Map<String, dynamic>.from(config.rawLiteratur),
      baseline: baseline,
      spo2Ringan: (spo2['ringan'] as num).toDouble(),
      spo2Sedang: (spo2['sedang'] as num).toDouble(),
      spo2Hipoksemia: (spo2['hipoksemia'] as num).toDouble(),
      spo2Kritis: (spo2['kritis'] as num).toDouble(),
      spo2KonfirmasiMinBacaan: (spo2['konfirmasi_min_bacaan'] as num).toInt(),
      spo2DropPct: dropSpo2,
      rrWaspada: config.lit('laju_napas', 'takipnea_ringan'),
      rrBahaya: config.lit('laju_napas', 'takipnea'),
      hrAbsTakikardia: (hr['takikardia_abs'] as num).toDouble(),
      hrAbsBerat: (hr['takikardia_berat_abs'] as num).toDouble(),
      hrDeltaWaspada: hrDeltaWaspada,
      hrDeltaBahaya: hrDeltaBahaya,
      hrvFloor: (hrv['floor_ms'] as num).toDouble(),
      hrvDropWaspadaPct: hrvDropWaspada,
      hrvDropPerhatianPct: hrvDropPerhatian,
      tidurDurasiJam: (tidur['durasi_jam_min'] as num).toDouble(),
      tidurEfisiensiMin: (tidur['efisiensi_pct_min'] as num).toDouble(),
      tidurWasoMin: (tidur['waso_menit_min'] as num).toDouble(),
      suhuWaspada: (dinginLit['suhu_waspada'] as num).toDouble(),
      suhuPerhatian: (dinginLit['suhu_perhatian'] as num).toDouble(),
      suhuBahaya: (dinginLit['suhu_bahaya'] as num).toDouble(),
      ambangSuhuPersonal: dingin.ambang,
      tierAmbangSuhu: dingin.tier,
      kejadianReaksiDingin: dingin.kejadian,
      rhKering: (dinginLit['kelembapan_kering_pct'] as num).toDouble(),
      rhSangatKering: (dinginLit['kelembapan_sangat_kering_pct'] as num)
          .toDouble(),
      anginWaspada: (dinginLit['angin_waspada_ms'] as num).toDouble(),
      anginBahaya: (dinginLit['angin_bahaya_ms'] as num).toDouble(),
      pm25Waspada: (partikulat['pm25_waspada'] as num).toDouble(),
      pm25Perhatian: (partikulat['pm25_perhatian'] as num).toDouble(),
      pm25Bahaya: (partikulat['pm25_bahaya'] as num).toDouble(),
      siklusHrNaikPct: (siklus['hr_naik_pct'] as num).toDouble(),
      siklusHrvTurunPct: (siklus['hrv_turun_pct'] as num).toDouble(),
      provenance: _provenance(
        baseline: baseline,
        dingin: dingin,
        dropSpo2: dropSpo2,
        hrDeltaBahaya: hrDeltaBahaya,
        hrvDropPerhatian: hrvDropPerhatian,
      ),
    );
  }

  /// Ambang deviasi dalam SATUAN yang sama dengan metriknya (bpm, %poin).
  ///
  /// `max(literatur, faktor x MAD)` — MAD pribadi hanya bisa MELONGGARKAN
  /// ambang, never memperketatnya di bawah angka jurnal.
  double deviasiUnit(String metrik, BaselineSet baseline, double literatur) {
    final s = baseline[metrik];
    if (!s.tersedia || s.mad == null) return literatur;
    if (s.jumlahHari < config.minimumHariSebagian) return literatur;
    return math.max(literatur, config.faktorVariabilitas * s.mad!);
  }

  /// Ambang deviasi dalam persen terhadap median pribadi (HRV, laju napas).
  double deviasiPersen(String metrik, BaselineSet baseline, double literatur) {
    final s = baseline[metrik];
    final m = s.median;
    if (!s.tersedia || s.mad == null || m == null || m == 0) return literatur;
    if (s.jumlahHari < config.minimumHariSebagian) return literatur;
    final madPct = s.mad! / m * 100;
    return math.max(literatur, config.faktorVariabilitas * madPct);
  }

  List<AmbangInfo> _provenance({
    required BaselineSet baseline,
    required AmbangDinginHasil dingin,
    required double dropSpo2,
    required double hrDeltaBahaya,
    required double hrvDropPerhatian,
  }) {
    final minPersonal = config.minimumHariPersonal;
    final minSebagian = config.minimumHariSebagian;

    TierKalibrasi tier(String metrik) => baseline.tier(
      metrik,
      minimumPersonal: minPersonal,
      minimumSebagian: minSebagian,
    );

    // Nilai numerik keterangan dihitung di sini, kalimatnya dirakit kamus.
    Map<String, String> ket(String metrik, String satuan) {
      final s = baseline[metrik];
      if (!s.tersedia) return {'k': '@baseline.tidak_ada'};
      final m = s.median!.toStringAsFixed(s.median! >= 100 ? 0 : 1);
      return {
        'k': '@baseline.keterangan',
        'm': m,
        'satuan': satuan,
        'hari': '${s.jumlahHari}',
      };
    }

    return [
      AmbangInfo(
        labelKey: 'ambang.spo2',
        nilai: config.lit('spo2', 'hipoksemia'),
        satuan: '%',
        tier: TierKalibrasi.literatur,
        sumberKey: 'spo2',
        detailKey: 'ambang.detail.spo2',
      ),
      AmbangInfo(
        labelKey: 'ambang.desaturasi',
        nilai: dropSpo2,
        satuan: ' %poin',
        tier: tier('spo2'),
        sumberKey: 'desaturasi_personal',
        detailKey: 'ambang.detail.desaturasi',
        detailArg: ket('spo2', '%'),
      ),
      AmbangInfo(
        labelKey: 'ambang.takipnea',
        nilai: config.lit('laju_napas', 'takipnea'),
        satuan: ' x/mnt',
        tier: TierKalibrasi.literatur,
        sumberKey: 'laju_napas',
      ),
      AmbangInfo(
        labelKey: 'ambang.hr_delta',
        nilai: hrDeltaBahaya,
        satuan: ' bpm',
        tier: tier('resting_hr'),
        sumberKey: 'detak_jantung',
        detailKey: 'ambang.detail.hr',
        detailArg: ket('resting_hr', ' bpm'),
      ),
      AmbangInfo(
        labelKey: 'ambang.hrv_drop',
        nilai: hrvDropPerhatian,
        satuan: '%',
        tier: tier('hrv_rmssd'),
        sumberKey: 'hrv_rmssd',
        detailKey: 'ambang.detail.hrv',
        detailArg: ket('hrv_rmssd', ' ms'),
      ),
      AmbangInfo(
        labelKey: 'ambang.tidur_durasi',
        nilai: config.lit('tidur', 'durasi_jam_min'),
        satuan: ' jam',
        tier: TierKalibrasi.literatur,
        sumberKey: 'tidur',
      ),
      AmbangInfo(
        labelKey: 'ambang.tidur_efisiensi',
        nilai: config.lit('tidur', 'efisiensi_pct_min'),
        satuan: '%',
        tier: tier('tidur_efisiensi'),
        sumberKey: 'tidur',
        detailKey: 'ambang.detail.efisiensi',
        detailArg: ket('tidur_efisiensi', '%'),
      ),
      AmbangInfo(
        labelKey: 'ambang.suhu_dingin',
        nilai: dingin.ambang,
        satuan: '°C',
        tier: dingin.tier,
        sumberKey: 'pembelajaran_ambang_dingin',
        detailKey: dingin.suhuReaksiTerpanas == null
            ? 'ambang.detail.dingin_belum'
            : 'ambang.detail.dingin_ada',
        detailArg: dingin.suhuReaksiTerpanas == null
            ? {
                'm': config
                    .lit('udara_dingin', 'suhu_perhatian')
                    .toStringAsFixed(1),
              }
            : {
                'm': dingin.suhuReaksiTerpanas!.toStringAsFixed(1),
                'n': '${dingin.kejadian}',
              },
      ),
      AmbangInfo(
        labelKey: 'ambang.rh_kering',
        nilai: config.lit('udara_dingin', 'kelembapan_kering_pct'),
        satuan: '% RH',
        tier: TierKalibrasi.literatur,
        sumberKey: 'udara_dingin',
      ),
      AmbangInfo(
        labelKey: 'ambang.angin',
        nilai: config.lit('udara_dingin', 'angin_bahaya_ms'),
        satuan: ' m/s',
        tier: tier('angin_ms'),
        sumberKey: 'udara_dingin',
      ),
      AmbangInfo(
        labelKey: 'ambang.pm25',
        nilai: config.lit('partikulat', 'pm25_waspada'),
        satuan: ' µg/m³',
        tier: TierKalibrasi.literatur,
        sumberKey: 'partikulat',
      ),
      AmbangInfo(
        labelKey: 'ambang.siklus',
        nilai: config.lit('siklus', 'hr_naik_pct'),
        satuan: '%',
        tier: TierKalibrasi.literatur,
        sumberKey: 'siklus',
        detailKey: 'ambang.detail.siklus',
      ),
    ];
  }
}
