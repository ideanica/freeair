import '../l10n/l10n.dart';
import 'pemeriksaan.dart';
import 'pemicu.dart';

/// Nama level yang dipakai sistem, sama persis dengan kunci di
/// `assets/rule_config.json`.
class AlertLevels {
  static const String aman = 'AMAN';
  static const String waspada = 'WASPADA';
  static const String perhatian = 'PERHATIAN';
  static const String bahaya = 'BAHAYA';

  /// Suhu lingkungan tidak tersedia → jangan menyimpulkan "AMAN" palsu.
  static const String tidakDievaluasi = 'TIDAK_DIEVALUASI';

  static const List<String> urutan = [aman, waspada, perhatian, bahaya];

  static bool levelButuhAlert(String level) =>
      level == waspada || level == perhatian || level == bahaya;
}

/// Hasil evaluasi satu kondisi (Bronkitis / Anxiety / Alergi Dingin).
class ConditionResult {
  ConditionResult({
    required this.kondisi,
    required this.skor,
    required this.level,
    required this.pemicu,
    required this.confidence,
    required this.evaluated,
    this.intervensi = '',
    this.butuhAlert = false,
    this.kalibrasi = 'literatur',
    this.pemeriksaan = const <Pemeriksaan>[],
  });

  final String kondisi;
  final int skor;
  final String level;

  /// Pemicu dalam bentuk kode + angka, bukan kalimat — lihat [Pemicu].
  final List<Pemicu> pemicu;

  /// Semua sinyal yang benar-benar diperiksa kondisi ini, termasuk yang
  /// datanya tidak tersedia. [pemicu] menjawab "apa yang menaikkan skor",
  /// [pemeriksaan] menjawab "kenapa skornya 0" dan "sinyal apa saja yang
  /// dilihat".
  final List<Pemeriksaan> pemeriksaan;

  final String confidence;
  final bool evaluated;

  /// Dari mana ambang yang dipakai kondisi ini berasal: `literatur`,
  /// `sebagian`, atau `personal` (baseline riwayat pengguna).
  final String kalibrasi;

  String intervensi;
  bool butuhAlert;

  /// Kalimat pemicu dalam bahasa [kamus].
  List<String> alasanTeks(L10n kamus) => kamus.pemicuSemua(pemicu);

  /// Level paling tinggi antar hasil, dipakai sebagai headline di Home.
  static String levelTertinggi(List<ConditionResult> hasil) {
    var indeks = -1;
    for (final r in hasil) {
      final i = AlertLevels.urutan.indexOf(r.level);
      if (i > indeks) indeks = i;
    }
    return indeks < 0
        ? AlertLevels.tidakDievaluasi
        : AlertLevels.urutan[indeks];
  }

  @override
  String toString() => '$kondisi: $skor ($level)';
}
