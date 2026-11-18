import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/condition_result.dart';
import '../models/sumber_riset.dart';

/// Konfigurasi aturan v3.
///
/// Semua angka ambang hidup di `assets/rule_config.json` dan setiap
/// kelompok angka membawa kunci `sumber` berisi kutipan jurnal/guideline.
/// Dart tidak boleh memuat satu pun angka klinis.
class RuleConfig {
  RuleConfig._(this._raw);

  static const String assetPath = 'assets/rule_config.json';

  final Map<String, dynamic> _raw;

  String get versi => _raw['versi'] as String? ?? '0';

  Map<String, dynamic> get profilDefault =>
      Map<String, dynamic>.from(_raw['profil_default'] as Map);

  // ---------------------------------------------------------------- level

  int get batasWaspada => _levelValue(AlertLevels.waspada);
  int get batasPerhatian => _levelValue(AlertLevels.perhatian);
  int get batasBahaya => _levelValue(AlertLevels.bahaya);

  int _levelValue(String level) =>
      (_raw['level_threshold'] as Map)[level] as int;

  // ------------------------------------------------------------- literatur

  Map<String, dynamic> _literatur(String blok) =>
      Map<String, dynamic>.from((_raw['literatur'] as Map)[blok] as Map);

  double lit(String blok, String kunci) =>
      (_literatur(blok)[kunci] as num).toDouble();

  /// Kutipan blok literatur; varian English ada di `sumber_en`.
  String litSumber(String blok, {String locale = 'id'}) {
    if (locale != 'id') {
      final inggris = _literatur(blok)['sumber_en'] as String?;
      if (inggris != null && inggris.trim().isNotEmpty) return inggris;
    }
    return _literatur(blok)['sumber'] as String? ?? '-';
  }

  /// Nama metrik dinamis untuk laporan kecukupan data; varian English ada di
  /// `label_en` dan jatuh ke `label` kalau belum diisi.
  String metrikLabel(String metrik, {String locale = 'id'}) {
    final m = metrikDinamis[metrik];
    if (m is Map && locale != 'id') {
      final inggris = m['label_en'] as String?;
      if (inggris != null && inggris.trim().isNotEmpty) return inggris;
    }
    return (m is Map ? m['label'] as String? : null) ?? metrik;
  }

  /// Kutipan untuk satu kunci provenance; `pembelajaran_ambang_dingin`
  /// menunjuk blok sendiri, sisanya blok literatur.
  String sumberTeks(String kunci, {String locale = 'id'}) {
    if (kunci == 'pembelajaran_ambang_dingin') {
      if (locale != 'id') {
        final inggris = _pembelajaranDingin['sumber_en'] as String?;
        if (inggris != null && inggris.trim().isNotEmpty) return inggris;
      }
      return pembelajaranDinginSumber;
    }
    return litSumber(kunci, locale: locale);
  }

  Map<String, dynamic> get litSpo2 => _literatur('spo2');
  Map<String, dynamic> get litDetakJantung => _literatur('detak_jantung');
  Map<String, dynamic> get litHrv => _literatur('hrv_rmssd');
  Map<String, dynamic> get litTidur => _literatur('tidur');
  Map<String, dynamic> get litDingin => _literatur('udara_dingin');
  Map<String, dynamic> get litPartikulat => _literatur('partikulat');
  Map<String, dynamic> get litSiklus => _literatur('siklus');

  // -------------------------------------------------------- bobot per sinyal

  WeightTable get bronkitis => WeightTable(_bobot('Bronkitis'));
  WeightTable get anxiety => WeightTable(_bobot('Anxiety'));
  WeightTable get alergiDingin => WeightTable(_bobot('Alergi Dingin'));

  Map<String, dynamic> _bobot(String kondisi) =>
      Map<String, dynamic>.from((_raw['bobot'] as Map)[kondisi] as Map);

  // ------------------------------------------------------------- dinamis

  Map<String, dynamic> get _dinamis =>
      Map<String, dynamic>.from(_raw['dinamis'] as Map);

  int get jendelaHari => (_dinamis['jendela_hari'] as num).toInt();
  int get minimumHariPersonal =>
      (_dinamis['minimum_hari_personal'] as num).toInt();
  int get minimumHariSebagian =>
      (_dinamis['minimum_hari_sebagian'] as num).toInt();
  double get bobotCampurPersonal =>
      (_dinamis['bobot_campur_personal'] as num).toDouble();
  double get outlierMadScore =>
      (_dinamis['outlier_mad_score'] as num).toDouble();

  /// Berapa besar ambang deviasi personal dilebarkan mengikuti variabilitas
  /// harian pemilik data (MAD). Tidak ada gunanya membunyikan alert pada
  /// orang yang hariannya memang berayun 6 bpm memakai delta 5 bpm.
  double get faktorVariabilitas =>
      (_dinamis['faktor_variabilitas_pribadi'] as num).toDouble();

  String get dinamisSumber => _dinamis['sumber'] as String? ?? '-';

  Map<String, dynamic> get rawLiteratur =>
      Map<String, dynamic>.from(_raw['literatur'] as Map);

  // ---------------------------------------------------------- sumber riset

  /// Daftar rujukan yang dipakai layar "Sumber".
  ///
  /// Hilang atau cacat bentuknya tidak boleh menjatuhkan aplikasi — layar
  /// tinggal menampilkan keadaan kosong yang jujur.
  List<KelompokSumber> get sumberRiset {
    final blok = _raw['sumber_riset'];
    if (blok is! Map) return const [];
    final kelompok = blok['kelompok'];
    if (kelompok is! List) return const [];
    return [
      for (final item in kelompok)
        if (item is Map)
          KelompokSumber.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  /// Catatan verifikasi di bawah daftar sumber; varian English hidup di
  /// `catatan_en` dan jatuh ke teks Indonesia kalau belum diisi.
  String sumberRisetCatatan({String locale = 'id'}) {
    final blok = _raw['sumber_riset'] as Map?;
    if (locale != 'id') {
      final inggris = blok?['catatan_en'] as String?;
      if (inggris != null && inggris.trim().isNotEmpty) return inggris;
    }
    return blok?['catatan'] as String? ?? '';
  }

  Map<String, dynamic> get metrikDinamis =>
      Map<String, dynamic>.from(_dinamis['metrik'] as Map);

  Map<String, dynamic> get _pembelajaranDingin =>
      Map<String, dynamic>.from(_raw['pembelajaran_ambang_dingin'] as Map);

  double get reaksiHrDelta =>
      (_pembelajaranDingin['reaksi_hr_delta_bpm'] as num).toDouble();
  double get reaksiRrMin =>
      (_pembelajaranDingin['reaksi_rr_min'] as num).toDouble();
  double get reaksiRrDelta =>
      (_pembelajaranDingin['reaksi_rr_delta'] as num?)?.toDouble() ?? 4.0;
  double get reaksiSpo2Drop =>
      (_pembelajaranDingin['reaksi_spo2_drop_pct'] as num).toDouble();
  int get minimumKejadianDingin =>
      (_pembelajaranDingin['minimum_kejadian'] as num).toInt();
  double get marginAmanDingin =>
      (_pembelajaranDingin['margin_aman_c'] as num).toDouble();
  String get pembelajaranDinginSumber =>
      _pembelajaranDingin['sumber'] as String? ?? '-';

  // ------------------------------------------------------------- lainnya

  /// Saran tindakan untuk satu kondisi + level, dalam bahasa [locale].
  ///
  /// Varian English hidup di `intervensi_en`; kalau belum diisi, fallback ke
  /// template Indonesia supaya pengguna tidak pernah melihat saran kosong.
  String intervensi(String kondisi, String level, {String locale = 'id'}) {
    if (locale != 'id') {
      final inggris =
          (((_raw['intervensi_en'] as Map?)?[kondisi] as Map?)?[level])
              as String?;
      if (inggris != null && inggris.trim().isNotEmpty) return inggris;
    }
    return (((_raw['intervensi'] as Map)[kondisi] as Map?)?[level] ?? '')
        as String;
  }

  int get dedupMenit =>
      ((_raw['deduplikasi'] as Map)['kirim_ulang_setelah_menit'] as num)
          .toInt();

  bool get dedupJikaLevelBerubah =>
      (_raw['deduplikasi'] as Map)['kirim_ulang_jika_level_berubah'] as bool? ??
      true;

  static Future<RuleConfig> load() async {
    final json = await rootBundle.loadString(assetPath);
    return RuleConfig._(jsonDecode(json) as Map<String, dynamic>);
  }

  /// Untuk test: muat konfigurasi dari string JSON tanpa asset bundle.
  static RuleConfig parse(String source) =>
      RuleConfig._(jsonDecode(source) as Map<String, dynamic>);
}

/// Satu aturan: kunci asli, angka yang tertulis di kunci, dan bobotnya.
class WeightRule {
  const WeightRule(this.key, this.numbers, this.weight);

  final String key;
  final List<double> numbers;
  final int weight;

  double get threshold => numbers.isEmpty ? 0 : numbers.first;
  double get secondaryThreshold => numbers.length > 1 ? numbers[1] : 0;
}

/// Kumpulan bobot satu bagian rule_config.json.
class WeightTable {
  WeightTable(Map<String, dynamic> raw)
    : _groups = {
        for (final entry in raw.entries) entry.key: _toRules(entry.value),
      };

  final Map<String, List<WeightRule>> _groups;

  static List<WeightRule> _toRules(dynamic value) {
    if (value is Map) {
      return [
        for (final e in value.entries)
          WeightRule(
            e.key.toString(),
            RegExp(r'\d+(?:\.\d+)?')
                .allMatches(e.key.toString())
                .map((m) => double.parse(m.group(0)!))
                .toList(),
            (e.value as num).toInt(),
          ),
      ];
    }
    if (value is num) return [WeightRule('value', [], value.toInt())];
    return const [];
  }

  List<WeightRule> rules(String group) => _groups[group] ?? const [];

  bool punyaGrup(String group) => _groups.containsKey(group);

  WeightRule rule(String group, String key) => rules(group).firstWhere(
    (r) => r.key == key,
    orElse: () =>
        throw StateError('rule_config.json tidak punya kunci "$group.$key"'),
  );

  int weight(String group, String key) => rule(group, key).weight;

  double threshold(String group, String key) => rule(group, key).threshold;

  /// Bobot pada grup yang nilainya angka langsung, contoh `luteal: 10`.
  int single(String group) => rules(group).first.weight;

  /// Aturan bertingkat diurutkan dari ambang tertinggi, meniru if/elif.
  List<WeightRule> tiersDescending(String group) =>
      _groups[group]!.toList()
        ..sort((a, b) => b.threshold.compareTo(a.threshold));
}
