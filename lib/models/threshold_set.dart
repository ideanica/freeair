import '../l10n/l10n.dart';
import 'baseline.dart';

/// Satu angka ambang yang dipakai siklus ini, beserta asalnya.
///
/// [labelKey] dan [detailKey] adalah kunci kamus, bukan kalimat: layarnya yang
/// merakit teks lewat [label]/[detail] supaya bahasa bisa diganti kapan pun
/// tanpa menunggu siklus berikutnya.
class AmbangInfo {
  const AmbangInfo({
    required this.labelKey,
    required this.nilai,
    required this.satuan,
    required this.tier,
    required this.sumberKey,
    this.detailKey,
    this.detailArg = const <String, String>{},
  });

  final String labelKey;
  final double nilai;

  /// Simbol mentah ('%', '°C', ' x/mnt'); diterjemahkan oleh [L10n.satuan].
  final String satuan;
  final TierKalibrasi tier;

  /// Kunci blok kutipan di rule_config.json (`spo2`, `udara_dingin`, ...);
  /// teksnya diambil saat ditampilkan supaya ikut bahasa aktif.
  final String sumberKey;

  final String? detailKey;
  final Map<String, String> detailArg;

  String label(L10n kamus) => kamus.t(labelKey);

  String detail(L10n kamus) =>
      detailKey == null ? '' : kamus.t(detailKey!, detailArg);

  String get nilaiTeks {
    final presisi = nilai.abs() >= 100 ? 0 : (nilai.abs() >= 10 ? 0 : 1);
    return nilai.toStringAsFixed(presisi);
  }
}

/// Semua ambang yang sudah diselesaikan untuk satu siklus.
///
/// Angka literatur datang dari rule_config.json; angka personal datang dari
/// [BaselineSet]. Tidak ada satu pun yang diisi pengguna.
class ThresholdSet {
  const ThresholdSet({
    required this.literatur,
    required this.baseline,
    required this.spo2Ringan,
    required this.spo2Sedang,
    required this.spo2Hipoksemia,
    required this.spo2Kritis,
    required this.spo2KonfirmasiMinBacaan,
    required this.spo2DropPct,
    required this.rrWaspada,
    required this.rrBahaya,
    required this.hrAbsTakikardia,
    required this.hrAbsBerat,
    required this.hrDeltaWaspada,
    required this.hrDeltaBahaya,
    required this.hrvFloor,
    required this.hrvDropWaspadaPct,
    required this.hrvDropPerhatianPct,
    required this.tidurDurasiJam,
    required this.tidurEfisiensiMin,
    required this.tidurWasoMin,
    required this.suhuWaspada,
    required this.suhuPerhatian,
    required this.suhuBahaya,
    required this.ambangSuhuPersonal,
    required this.tierAmbangSuhu,
    required this.kejadianReaksiDingin,
    required this.rhKering,
    required this.rhSangatKering,
    required this.anginWaspada,
    required this.anginBahaya,
    required this.pm25Waspada,
    required this.pm25Perhatian,
    required this.pm25Bahaya,
    required this.siklusHrNaikPct,
    required this.siklusHrvTurunPct,
    required this.provenance,
  });

  final Map<String, dynamic> literatur;

  /// Baseline personal yang mendasari angka di atas.
  final BaselineSet baseline;

  final double spo2Ringan;
  final double spo2Sedang;
  final double spo2Hipoksemia;
  final double spo2Kritis;
  final int spo2KonfirmasiMinBacaan;

  /// Turun berapa % dari median pribadi yang dianggap desaturasi bermakna.
  final double spo2DropPct;

  final double rrWaspada;
  final double rrBahaya;

  final double hrAbsTakikardia;
  final double hrAbsBerat;
  final double hrDeltaWaspada;
  final double hrDeltaBahaya;

  final double hrvFloor;
  final double hrvDropWaspadaPct;
  final double hrvDropPerhatianPct;

  final double tidurDurasiJam;
  final double tidurEfisiensiMin;
  final double tidurWasoMin;

  final double suhuWaspada;
  final double suhuPerhatian;
  final double suhuBahaya;

  /// Ambang dingin personal hasil pembelajaran dari riwayat reaksi fisiologis.
  final double ambangSuhuPersonal;
  final TierKalibrasi tierAmbangSuhu;
  final int kejadianReaksiDingin;

  final double rhKering;
  final double rhSangatKering;
  final double anginWaspada;
  final double anginBahaya;

  final double pm25Waspada;
  final double pm25Perhatian;
  final double pm25Bahaya;

  final double siklusHrNaikPct;
  final double siklusHrvTurunPct;

  final List<AmbangInfo> provenance;

  /// Median suhu lingkungan pribadi; selisih terhadap nilai ini memicu
  /// aturan "penurunan suhu mendadak" (Graudenz 2006).
  double? get baselineSuhu => baseline['suhu_ambient'].median;

  double? get baselineRestingHr => baseline['resting_hr'].median;
  double? get baselineHrv => baseline['hrv_rmssd'].median;
  double? get baselineSpo2 => baseline['spo2'].median;
  double? get baselineRespRate => baseline['resp_rate'].median;
}
