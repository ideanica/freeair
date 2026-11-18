import '../l10n/app_settings.dart';
import '../l10n/l10n.dart';
import '../models/baseline.dart';
import '../models/condition_result.dart';
import '../models/pemeriksaan.dart';
import '../models/pemicu.dart';
import '../models/sensor_snapshot.dart';
import '../models/threshold_set.dart';
import 'rule_config.dart';

/// Rule engine v3 — tanpa input manual.
///
/// Semua nilai masuk lewat [SensorSnapshot] (Health Connect + BMKG +
/// Open-Meteo) dan semua pembanding lewat [ThresholdSet] (angka literatur
/// yang sudah dicampur baseline personal). Fungsi ini hanya menyusun logika;
/// tidak ada satu pun angka klinis yang ditulis di file ini.
///
/// Engine tidak merakit kalimat. Setiap pemicu dicatat sebagai [Pemicu]
/// (kode + angka yang sudah diformat) supaya kalimatnya dirakit saat
/// ditampilkan, dalam bahasa apa pun — termasuk untuk baris riwayat lama.
class RuleEngine {
  RuleEngine(this.config);

  final RuleConfig config;

  String levelDariSkor(int score) {
    if (score >= config.batasBahaya) return AlertLevels.bahaya;
    if (score >= config.batasPerhatian) return AlertLevels.perhatian;
    if (score >= config.batasWaspada) return AlertLevels.waspada;
    return AlertLevels.aman;
  }

  /// Fase siklus dari hari siklus. Panjang siklus ikut dipakai karena
  /// diturunkan dari catatan menstruasi, bukan asumsi 28 hari.
  static String faseSiklus(int? cycleDay, {double? panjangSiklus}) {
    if (cycleDay == null) return 'tidak_diketahui';
    final panjang = (panjangSiklus ?? 28).clamp(20.0, 40.0).round();
    final hari = cycleDay.clamp(1, panjang);
    if (hari <= 5) return 'menstruasi';
    if (hari >= panjang - 14) return 'luteal';
    if (hari == (panjang / 2).round()) return 'ovulasi';
    return 'folikular';
  }

  // ================================================================ entry

  /// Nilai semua kondisi aktif pada satu siklus.
  ///
  /// [locale] hanya memilih bahasa template saran di rule_config.json; angka
  /// dan logika penilaian tidak berubah.
  List<ConditionResult> evaluasi(
    SensorSnapshot data,
    ThresholdSet ambang, {
    List<String>? kondisiAktif,
    String? locale,
  }) {
    final aktif =
        kondisiAktif ?? const ['Bronkitis Kronis', 'Anxiety', 'Alergi Dingin'];
    final hasil = <ConditionResult>[];
    final bahasa = locale ?? AppSettings.locale;

    if (aktif.contains('Bronkitis Kronis') || aktif.contains('Bronkitis')) {
      hasil.add(_bronkitis(data, ambang));
    }
    if (aktif.contains('Anxiety')) {
      hasil.add(_anxiety(data, ambang));
    }
    if (aktif.contains('Alergi Dingin')) {
      hasil.add(_alergiDingin(data, ambang));
    }

    final nilaiTeks = _placeholder(data, ambang);
    final kamus = L10n.untuk(bahasa);
    for (final r in hasil) {
      r.intervensi = r.level == AlertLevels.tidakDievaluasi
          ? ''
          : _isiTemplate(
              config.intervensi(r.kondisi, r.level, locale: bahasa),
              nilaiTeks,
              kamus,
            );
      r.butuhAlert = AlertLevels.levelButuhAlert(r.level);
    }
    return hasil;
  }

  // ============================================================== bronkitis

  ConditionResult _bronkitis(SensorSnapshot data, ThresholdSet ambang) {
    final w = config.bronkitis;
    final p = _Penilaian();
    final spo2 = data.spo2;
    final rr = data.respRate;
    final tidur = data.sleep;

    if (spo2 != null) {
      final v = spo2.minPct;
      if (v < ambang.spo2Hipoksemia) {
        final n = spo2.runtuhanTerpanjangDiBawah(ambang.spo2Hipoksemia);
        p.tambah(
          w.weight(
            'spo2_absolut',
            n >= ambang.spo2KonfirmasiMinBacaan
                ? 'hipoksemia_dikonfirmasi'
                : 'hipoksemia_tidak_dikonfirmasi',
          ),
          'pemicu.spo2.hipoksemia',
          _statusSpo2(v.toStringAsFixed(0), n, ambang.spo2KonfirmasiMinBacaan),
        );
      } else if (v < ambang.spo2Sedang) {
        final n = spo2.runtuhanTerpanjangDiBawah(ambang.spo2Sedang);
        p.tambah(
          w.weight(
            'spo2_absolut',
            n >= ambang.spo2KonfirmasiMinBacaan
                ? 'sedang_dikonfirmasi'
                : 'sedang_tidak_dikonfirmasi',
          ),
          'pemicu.spo2.ringan',
          _statusSpo2(v.toStringAsFixed(0), n, ambang.spo2KonfirmasiMinBacaan),
        );
      } else if (v < ambang.spo2Ringan) {
        p.tambah(w.weight('spo2_absolut', 'ringan'), 'pemicu.spo2.borderline', {
          'spo2': v.toStringAsFixed(0),
        });
      }

      final baselineSpo2 = ambang.baselineSpo2;
      if (baselineSpo2 != null && baselineSpo2 > 0) {
        final drop = baselineSpo2 - v;
        if (drop >= ambang.spo2DropPct) {
          p.tambah(
            w.single('spo2_desaturasi_personal'),
            'pemicu.spo2.desaturasi_personal',
            {
              'drop': drop.toStringAsFixed(1),
              'baseline': baselineSpo2.toStringAsFixed(1),
              'ambang': ambang.spo2DropPct.toStringAsFixed(1),
            },
          );
        }
      }
    }

    if (rr != null) {
      final v = rr.avgPerMenit;
      if (v >= ambang.rrBahaya) {
        p.tambah(w.weight('laju_napas', 'takipnea'), 'pemicu.rr.takipnea', {
          'rr': v.toStringAsFixed(0),
        });
      } else if (v >= ambang.rrWaspada) {
        p.tambah(
          w.weight('laju_napas', 'takipnea_ringan'),
          'pemicu.rr.di_atas_normal',
          {'rr': v.toStringAsFixed(0)},
        );
      }
    }

    _hrDeviasi(p, w, data, ambang);

    if (tidur != null) {
      final jam = tidur.durationMinutes / 60.0;
      if (jam < ambang.tidurDurasiJam) {
        p.tambah(w.weight('tidur_durasi', 'min'), 'pemicu.tidur.durasi', {
          'jam': jam.toStringAsFixed(1),
          'ambang': _bersih(ambang.tidurDurasiJam),
        });
      }
      final eff = tidur.efficiencyPct;
      if (eff != null && eff < ambang.tidurEfisiensiMin) {
        p.tambah(w.weight('tidur_efisiensi', 'min'), 'pemicu.tidur.efisiensi', {
          'eff': eff.toStringAsFixed(0),
          'ambang': _bersih(ambang.tidurEfisiensiMin),
        });
      }
    }

    final pm = data.pm25;
    if (pm != null) {
      if (pm >= ambang.pm25Bahaya) {
        p.tambah(w.weight('pm25', 'bahaya'), 'pemicu.pm25.bahaya', {
          'pm': _bersih(pm),
        });
      } else if (pm >= ambang.pm25Perhatian) {
        p.tambah(w.weight('pm25', 'perhatian'), 'pemicu.pm25.sensitif', {
          'pm': _bersih(pm),
        });
      } else if (pm >= ambang.pm25Waspada) {
        p.tambah(w.weight('pm25', 'waspada'), 'pemicu.pm25.who', {
          'pm': _bersih(pm),
        });
      }
    }

    if (_fase(data) == 'luteal' &&
        p.skor >= w.weight('luteal', 'syarat_skor')) {
      p.tambah(w.weight('luteal', 'bobot'), 'pemicu.fase.luteal_bronk');
    }

    _periksaBronkitis(p, data, ambang);

    return p.hasil(
      kondisi: 'Bronkitis',
      engine: this,
      data: data,
      ambang: ambang,
      metrikKalibrasi: const ['spo2', 'resting_hr', 'resp_rate'],
    );
  }

  // ================================================================ anxiety

  ConditionResult _anxiety(SensorSnapshot data, ThresholdSet ambang) {
    final w = config.anxiety;
    final p = _Penilaian();
    final hrv = data.hrv;
    final tidur = data.sleep;

    if (hrv != null) {
      final baseline = ambang.baselineHrv;
      if (baseline != null && baseline > 0) {
        final dropPct = (baseline - hrv.avgMs) / baseline * 100;
        if (dropPct >= ambang.hrvDropPerhatianPct) {
          p.tambah(
            w.weight('hrv_deviasi_baseline', 'perhatian'),
            'pemicu.hrv.deviasi_perhatian',
            {
              'hrv': hrv.avgMs.toStringAsFixed(0),
              'pct': dropPct.toStringAsFixed(0),
              'baseline': baseline.toStringAsFixed(0),
            },
          );
        } else if (dropPct >= ambang.hrvDropWaspadaPct) {
          p.tambah(
            w.weight('hrv_deviasi_baseline', 'waspada'),
            'pemicu.hrv.deviasi_waspada',
            {
              'hrv': hrv.avgMs.toStringAsFixed(0),
              'pct': dropPct.toStringAsFixed(0),
            },
          );
        }
      }
      if (hrv.avgMs < ambang.hrvFloor) {
        p.tambah(w.weight('hrv_floor', 'floor'), 'pemicu.hrv.floor', {
          'hrv': hrv.avgMs.toStringAsFixed(0),
          'ambang': _bersih(ambang.hrvFloor),
        });
      }
    }

    _hrDeviasi(p, w, data, ambang);

    final hr = data.heartRate;
    if (hr != null) {
      if (hr.latestBpm > ambang.hrAbsBerat) {
        p.tambah(w.weight('hr_absolut', 'berat'), 'pemicu.hr.berat', {
          'hr': '${hr.latestBpm}',
        });
      } else if (hr.latestBpm > ambang.hrAbsTakikardia) {
        p.tambah(w.weight('hr_absolut', 'takikardia'), 'pemicu.hr.takikardia', {
          'hr': '${hr.latestBpm}',
        });
      }
    }

    if (tidur != null) {
      final jam = tidur.durationMinutes / 60.0;
      if (jam < ambang.tidurDurasiJam) {
        p.tambah(w.weight('tidur_durasi', 'min'), 'pemicu.tidur.durasi', {
          'jam': jam.toStringAsFixed(1),
          'ambang': _bersih(ambang.tidurDurasiJam),
        });
      }
      final eff = tidur.efficiencyPct;
      if (eff != null && eff < ambang.tidurEfisiensiMin) {
        p.tambah(w.weight('tidur_efisiensi', 'min'), 'pemicu.tidur.efisiensi', {
          'eff': eff.toStringAsFixed(0),
          'ambang': _bersih(ambang.tidurEfisiensiMin),
        });
      }
      final waso = tidur.wasoMinutes;
      if (waso != null && waso >= ambang.tidurWasoMin) {
        p.tambah(w.weight('tidur_waso', 'min'), 'pemicu.tidur.waso', {
          'waso': '$waso',
          'ambang': _bersih(ambang.tidurWasoMin),
        });
      }
    }

    final olahraga = data.activity;
    if (olahraga != null) {
      final menit = olahraga.exerciseMinutes;
      if (menit >= config.lit('aktivitas', 'olahraga_protektif_menit') &&
          p.skor > 0) {
        p.tambah(
          w.weight('olahraga', 'protektif'),
          'pemicu.olahraga.protektif',
          {'menit': menit.toStringAsFixed(0)},
        );
      } else if (menit < config.lit('aktivitas', 'olahraga_minim_menit')) {
        p.tambah(w.weight('olahraga', 'minim'), 'pemicu.olahraga.minim');
      }
    }

    final fase = _fase(data);
    if (fase == 'luteal') {
      p.tambah(w.single('luteal'), 'pemicu.fase.luteal_anxiety');
    } else if (fase == 'menstruasi') {
      p.tambah(w.single('menstruasi'), 'pemicu.fase.menstruasi');
    }

    _periksaAnxiety(p, data, ambang);

    return p.hasil(
      kondisi: 'Anxiety',
      engine: this,
      data: data,
      ambang: ambang,
      metrikKalibrasi: const ['hrv_rmssd', 'resting_hr', 'tidur_menit'],
    );
  }

  // ========================================================== alergi dingin

  ConditionResult _alergiDingin(SensorSnapshot data, ThresholdSet ambang) {
    final suhu = data.suhu;

    // Kontrak keras: tanpa suhu lingkungan, jangan pernah menyimpulkan AMAN.
    if (suhu == null) {
      return ConditionResult(
        kondisi: 'Alergi Dingin',
        skor: 0,
        level: AlertLevels.tidakDievaluasi,
        pemicu: const [Pemicu('pemicu.dingin.tidak_ada_suhu')],
        confidence: 'LOW',
        evaluated: false,
        kalibrasi: 'literatur',
        pemeriksaan: [
          Pemeriksaan(
            labelKey: 'periksa.suhu',
            satuan: '°C',
            ambang: ambang.ambangSuhuPersonal,
            arah: 'bawah',
            terpicu: false,
          ),
        ],
      );
    }

    final w = config.alergiDingin;
    final p = _Penilaian();
    final ambangPersonal = ambang.ambangSuhuPersonal;

    final sangat = config.lit('offset_suhu_personal', 'sangat_dingin');
    final dingin = config.lit('offset_suhu_personal', 'dingin');
    final mendekati = config.lit('offset_suhu_personal', 'mendekati');

    // Asal ambang disisipkan bersarang: argumen `sumber` berisi rujukan ke
    // template lain, bukan kalimat yang sudah jadi.
    final sumber = switch (ambang.tierAmbangSuhu) {
      TierKalibrasi.personal => '@pemicu.ambang.personal',
      TierKalibrasi.sebagian => '@pemicu.ambang.sebagian',
      TierKalibrasi.literatur => '@pemicu.ambang.literatur',
    };
    final argSumber = {
      'v': ambangPersonal.toStringAsFixed(1),
      'n': '${ambang.kejadianReaksiDingin}',
    };

    if (suhu <= ambangPersonal - sangat) {
      p.tambah(
        w.weight('suhu_terhadap_ambang_personal', 'sangat_dingin'),
        'pemicu.dingin.sangat',
        {
          'suhu': suhu.toStringAsFixed(0),
          'delta': (ambangPersonal - suhu).toStringAsFixed(1),
          'sumber': sumber,
          ...argSumber,
        },
      );
    } else if (suhu <= ambangPersonal - dingin) {
      p.tambah(
        w.weight('suhu_terhadap_ambang_personal', 'dingin'),
        'pemicu.dingin.dingin',
        {'suhu': suhu.toStringAsFixed(0), 'sumber': sumber, ...argSumber},
      );
    } else if (suhu <= ambangPersonal - mendekati) {
      p.tambah(
        w.weight('suhu_terhadap_ambang_personal', 'mendekati'),
        'pemicu.dingin.mendekati',
        {'suhu': suhu.toStringAsFixed(0), 'sumber': sumber, ...argSumber},
      );
    }

    final baselineSuhu = ambang.baselineSuhu;
    if (baselineSuhu != null) {
      final drop = baselineSuhu - suhu;
      if (drop >= config.lit('udara_dingin', 'drop_baseline_bahaya_c')) {
        p.tambah(
          w.weight('suhu_drop_baseline', 'bahaya'),
          'pemicu.dingin.drop_bahaya',
          {
            'drop': drop.toStringAsFixed(1),
            'baseline': baselineSuhu.toStringAsFixed(1),
          },
        );
      } else if (drop >=
          config.lit('udara_dingin', 'drop_baseline_waspada_c')) {
        p.tambah(
          w.weight('suhu_drop_baseline', 'waspada'),
          'pemicu.dingin.drop_waspada',
          {'drop': drop.toStringAsFixed(1)},
        );
      }
    }

    final rh = data.kelembapan;
    if (rh != null) {
      if (rh <= ambang.rhSangatKering) {
        p.tambah(
          w.weight('kelembapan', 'sangat_kering'),
          'pemicu.rh.sangat_kering',
          {'rh': rh.toStringAsFixed(0)},
        );
      } else if (rh <= ambang.rhKering) {
        p.tambah(w.weight('kelembapan', 'kering'), 'pemicu.rh.kering', {
          'rh': rh.toStringAsFixed(0),
        });
      }
    }

    final angin = data.angin;
    if (angin != null) {
      if (angin >= ambang.anginBahaya) {
        p.tambah(w.weight('angin', 'bahaya'), 'pemicu.angin.bahaya', {
          'angin': angin.toStringAsFixed(1),
        });
      } else if (angin >= ambang.anginWaspada) {
        p.tambah(w.weight('angin', 'waspada'), 'pemicu.angin.waspada', {
          'angin': angin.toStringAsFixed(1),
        });
      }
    }

    _hrDeviasi(p, w, data, ambang);

    final olahraga = data.activity;
    if (olahraga != null &&
        olahraga.exerciseMinutes >
            config.lit('aktivitas', 'olahraga_berat_menit')) {
      p.tambah(
        w.weight('olahraga', 'berat'),
        'pemicu.olahraga.bronkokonstriksi',
        {'menit': olahraga.exerciseMinutes.toStringAsFixed(0)},
      );
    }

    if (_fase(data) == 'luteal') {
      p.tambah(w.single('luteal'), 'pemicu.fase.luteal_dingin');
    }

    _periksaAlergi(p, data, ambang);

    return p.hasil(
      kondisi: 'Alergi Dingin',
      engine: this,
      data: data,
      ambang: ambang,
      metrikKalibrasi: const ['suhu_ambient', 'resting_hr'],
    );
  }


  // ============================================================ pemeriksaan

  /// Sinyal yang benar-benar dilihat Bronkitis, termasuk yang tidak tersedia.
  void _periksaBronkitis(
    _Penilaian p,
    SensorSnapshot data,
    ThresholdSet ambang,
  ) {
    final spo2 = data.spo2;
    final rr = data.respRate;
    final tidur = data.sleep;
    final hr = data.restingHeartRate?.bpm ?? data.heartRate?.avgBpm.toDouble();
    final baselineHr = ambang.baselineRestingHr;
    final hrAmbang = baselineHr == null
        ? null
        : baselineHr + ambang.hrDeltaWaspada;

    p.periksa(
      Pemeriksaan(
        labelKey: 'periksa.spo2',
        nilai: spo2?.minPct,
        satuan: '%',
        ambang: ambang.spo2Ringan,
        arah: 'bawah',
        terpicu: p.sudahMemicu('pemicu.spo2'),
      ),
    );
    p.periksa(
      Pemeriksaan(
        labelKey: 'periksa.laju_napas',
        nilai: rr?.avgPerMenit,
        satuan: ' x/mnt',
        ambang: ambang.rrWaspada,
        arah: 'atas',
        terpicu: p.sudahMemicu('pemicu.rr'),
      ),
    );
    p.periksa(
      Pemeriksaan(
        labelKey: 'periksa.hr',
        nilai: hr,
        satuan: 'bpm',
        ambang: hrAmbang,
        arah: 'atas',
        terpicu: p.sudahMemicu('pemicu.hr'),
      ),
    );
    p.periksa(
      Pemeriksaan(
        labelKey: 'periksa.tidur_durasi',
        nilai: tidur == null ? null : tidur.durationMinutes / 60,
        satuan: 'jam',
        ambang: ambang.tidurDurasiJam,
        arah: 'bawah',
        terpicu: p.sudahMemicu('pemicu.tidur.durasi'),
      ),
    );
    p.periksa(
      Pemeriksaan(
        labelKey: 'periksa.tidur_efisiensi',
        nilai: tidur?.efficiencyPct,
        satuan: '%',
        ambang: ambang.tidurEfisiensiMin,
        arah: 'bawah',
        terpicu: p.sudahMemicu('pemicu.tidur.efisiensi'),
      ),
    );
    p.periksa(
      Pemeriksaan(
        labelKey: 'periksa.pm25',
        nilai: data.pm25,
        satuan: 'µg/m³',
        ambang: ambang.pm25Waspada,
        arah: 'atas',
        terpicu: p.sudahMemicu('pemicu.pm25'),
      ),
    );
    _periksaFase(p, data);
  }

  /// Sinyal yang dilihat Anxiety.
  void _periksaAnxiety(_Penilaian p, SensorSnapshot data, ThresholdSet ambang) {
    final hrv = data.hrv;
    final tidur = data.sleep;
    final hr = data.restingHeartRate?.bpm ?? data.heartRate?.avgBpm.toDouble();
    final baselineHr = ambang.baselineRestingHr;
    final baselineHrv = ambang.baselineHrv;
    final hrvAmbang = baselineHrv == null
        ? ambang.hrvFloor
        : baselineHrv * (1 - ambang.hrvDropWaspadaPct / 100);
    final hrAmbang = baselineHr == null
        ? null
        : baselineHr + ambang.hrDeltaWaspada;
    final olahraga = data.activity;

    p.periksa(
      Pemeriksaan(
        labelKey: 'periksa.hrv',
        nilai: hrv?.avgMs,
        satuan: 'ms',
        ambang: hrvAmbang,
        arah: 'bawah',
        terpicu: p.sudahMemicu('pemicu.hrv'),
      ),
    );
    p.periksa(
      Pemeriksaan(
        labelKey: 'periksa.hr',
        nilai: hr,
        satuan: 'bpm',
        ambang: hrAmbang,
        arah: 'atas',
        terpicu: p.sudahMemicu('pemicu.hr'),
      ),
    );
    p.periksa(
      Pemeriksaan(
        labelKey: 'periksa.hr_absolut',
        nilai: data.heartRate?.latestBpm.toDouble(),
        satuan: 'bpm',
        ambang: ambang.hrAbsTakikardia,
        arah: 'atas',
        terpicu:
            p.sudahMemicu('pemicu.hr.takikardia') ||
            p.sudahMemicu('pemicu.hr.berat'),
      ),
    );
    p.periksa(
      Pemeriksaan(
        labelKey: 'periksa.tidur_durasi',
        nilai: tidur == null ? null : tidur.durationMinutes / 60,
        satuan: 'jam',
        ambang: ambang.tidurDurasiJam,
        arah: 'bawah',
        terpicu: p.sudahMemicu('pemicu.tidur.durasi'),
      ),
    );
    p.periksa(
      Pemeriksaan(
        labelKey: 'periksa.tidur_efisiensi',
        nilai: tidur?.efficiencyPct,
        satuan: '%',
        ambang: ambang.tidurEfisiensiMin,
        arah: 'bawah',
        terpicu: p.sudahMemicu('pemicu.tidur.efisiensi'),
      ),
    );
    p.periksa(
      Pemeriksaan(
        labelKey: 'periksa.tidur_waso',
        nilai: tidur?.wasoMinutes?.toDouble(),
        satuan: 'mnt',
        ambang: ambang.tidurWasoMin,
        arah: 'atas',
        terpicu: p.sudahMemicu('pemicu.tidur.waso'),
      ),
    );
    p.periksa(
      Pemeriksaan(
        labelKey: 'periksa.olahraga',
        nilai: olahraga?.exerciseMinutes,
        satuan: 'mnt',
        ambang: config.lit('aktivitas', 'olahraga_protektif_menit'),
        arah: 'atas',
        terpicu: p.sudahMemicu('pemicu.olahraga.minim'),
      ),
    );
    _periksaFase(p, data);
  }

  /// Sinyal yang dilihat Alergi Dingin.
  void _periksaAlergi(_Penilaian p, SensorSnapshot data, ThresholdSet ambang) {
    final hr = data.restingHeartRate?.bpm ?? data.heartRate?.avgBpm.toDouble();
    final baselineHr = ambang.baselineRestingHr;
    final hrAmbang = baselineHr == null
        ? null
        : baselineHr + ambang.hrDeltaWaspada;
    final olahraga = data.activity;

    p.periksa(
      Pemeriksaan(
        labelKey: 'periksa.suhu',
        nilai: data.suhu,
        satuan: '°C',
        ambang: ambang.ambangSuhuPersonal,
        arah: 'bawah',
        terpicu: p.sudahMemicu('pemicu.dingin'),
      ),
    );
    p.periksa(
      Pemeriksaan(
        labelKey: 'periksa.kelembapan',
        nilai: data.kelembapan,
        satuan: '%',
        ambang: ambang.rhKering,
        arah: 'bawah',
        terpicu: p.sudahMemicu('pemicu.rh'),
      ),
    );
    p.periksa(
      Pemeriksaan(
        labelKey: 'periksa.angin',
        nilai: data.angin,
        satuan: 'm/s',
        ambang: ambang.anginWaspada,
        arah: 'atas',
        terpicu: p.sudahMemicu('pemicu.angin'),
      ),
    );
    p.periksa(
      Pemeriksaan(
        labelKey: 'periksa.hr',
        nilai: hr,
        satuan: 'bpm',
        ambang: hrAmbang,
        arah: 'atas',
        terpicu: p.sudahMemicu('pemicu.hr'),
      ),
    );
    p.periksa(
      Pemeriksaan(
        labelKey: 'periksa.olahraga',
        nilai: olahraga?.exerciseMinutes,
        satuan: 'mnt',
        ambang: config.lit('aktivitas', 'olahraga_berat_menit'),
        arah: 'atas',
        terpicu: p.sudahMemicu('pemicu.olahraga'),
      ),
    );
    _periksaFase(p, data);
  }

  void _periksaFase(_Penilaian p, SensorSnapshot data) {
    final fase = _fase(data);
    p.periksa(
      Pemeriksaan(
        labelKey: 'periksa.fase',
        nilaiTeks: fase,
        arah: 'info',
        terpicu: p.sudahMemicu('pemicu.fase'),
      ),
    );
  }

  // ================================================================ helpers


  String _fase(SensorSnapshot data) => faseSiklus(
    data.cycle.cycleDay,
    panjangSiklus: data.cycle.cycleLengthDays,
  );

  /// Argumen SpO2: nilai, panjang runtuhan, dan status konfirmasinya.
  static Map<String, String> _statusSpo2(String nilai, int n, int minimum) => {
    'spo2': nilai,
    'n': '$n',
    'status': n >= minimum ? '@pemicu.status.beruntun' : '@pemicu.status.belum',
  };

  /// Kenaikan detak jantung terhadap baseline RHR pribadi — bukan ambang isian.
  void _hrDeviasi(
    _Penilaian p,
    WeightTable w,
    SensorSnapshot data,
    ThresholdSet ambang,
  ) {
    final hr = data.restingHeartRate?.bpm ?? data.heartRate?.avgBpm.toDouble();
    final baseline = ambang.baselineRestingHr;
    if (hr == null || baseline == null || baseline <= 0) return;
    final delta = hr - baseline;
    if (delta >= ambang.hrDeltaBahaya) {
      p.tambah(
        w.weight('hr_deviasi_baseline', 'bahaya'),
        'pemicu.hr.deviasi_bahaya',
        {
          'hr': hr.toStringAsFixed(0),
          'delta': delta.toStringAsFixed(0),
          'baseline': baseline.toStringAsFixed(0),
        },
      );
    } else if (delta >= ambang.hrDeltaWaspada) {
      p.tambah(
        w.weight('hr_deviasi_baseline', 'waspada'),
        'pemicu.hr.deviasi_waspada',
        {'hr': hr.toStringAsFixed(0), 'delta': delta.toStringAsFixed(0)},
      );
    }
  }

  /// Tier terlemah di antara metrik kunci: satu metrik tanpa baseline berarti
  /// ambangnya masih murni angka literatur.
  String kalibrasiUntuk(ThresholdSet ambang, List<String> metrik) {
    var terlemah = TierKalibrasi.personal;
    for (final m in metrik) {
      final t = ambang.baseline.tier(
        m,
        minimumPersonal: config.minimumHariPersonal,
        minimumSebagian: config.minimumHariSebagian,
      );
      if (t.index < terlemah.index) terlemah = t;
    }
    return terlemah.name;
  }

  Map<String, String> _placeholder(SensorSnapshot data, ThresholdSet ambang) {
    final nilai = <String, String?>{
      'suhu': data.suhu?.toStringAsFixed(0),
      'pm25': data.pm25?.toStringAsFixed(0),
      'spo2': data.spo2?.minPct.toStringAsFixed(0),
      'spo2_baseline': ambang.baselineSpo2?.toStringAsFixed(1),
      'hrv': data.hrv?.avgMs.toStringAsFixed(0),
      'hr': data.heartRate?.latestBpm.toString(),
      'hr_baseline': ambang.baselineRestingHr?.toStringAsFixed(0),
      'tidur_jam': data.sleep == null
          ? null
          : (data.sleep!.durationMinutes / 60).toStringAsFixed(1),
      'angin': data.angin?.toStringAsFixed(1),
      'rh': data.kelembapan?.toStringAsFixed(0),
      'ambang_dingin': ambang.ambangSuhuPersonal.toStringAsFixed(1),
    };
    nilai.removeWhere((_, v) => v == null);
    return nilai.cast<String, String>();
  }

  /// Placeholder tanpa data diganti "belum tercatat" supaya teks intervensi
  /// tidak pernah menampilkan kurung kurawal.
  static String _isiTemplate(
    String template,
    Map<String, String> nilai,
    L10n kamus,
  ) {
    var hasil = template;
    nilai.forEach((k, v) => hasil = hasil.replaceAll('{$k}', v));
    return hasil.replaceAllMapped(
      RegExp(r'\{[a-z_]+\}'),
      (_) => kamus.t('umum.belum_dicatat'),
    );
  }

  static String _bersih(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// Akumulator skor + pemicu satu kondisi.
class _Penilaian {
  int skor = 0;
  final List<Pemicu> pemicu = <Pemicu>[];
  final List<Pemeriksaan> pemeriksaan = <Pemeriksaan>[];

  void tambah(int bobot, String kode, [Map<String, String> arg = const {}]) {
    skor += bobot;
    pemicu.add(Pemicu(kode, arg, bobot));
  }

  void periksa(Pemeriksaan p) => pemeriksaan.add(p);

  /// Apakah sudah ada pemicu dengan awalan kode tertentu. Dipakai agar daftar
  /// pemeriksaan tidak menduplikasi logika ambang: status "terpicu" selalu
  /// berasal dari pemicu yang benar-benar ditambahkan.
  bool sudahMemicu(String awalan) =>
      pemicu.any((p) => p.kode.startsWith(awalan));

  ConditionResult hasil({
    required String kondisi,
    required RuleEngine engine,
    required SensorSnapshot data,
    required ThresholdSet ambang,
    required List<String> metrikKalibrasi,
  }) {
    final nilai = skor.clamp(0, 100).toInt();
    return ConditionResult(
      kondisi: kondisi,
      skor: nilai,
      level: engine.levelDariSkor(nilai),
      pemicu: List<Pemicu>.unmodifiable(pemicu),
      pemeriksaan: List<Pemeriksaan>.unmodifiable(pemeriksaan),
      confidence: data.confidence,
      evaluated: true,
      kalibrasi: engine.kalibrasiUntuk(ambang, metrikKalibrasi),
    );
  }
}
