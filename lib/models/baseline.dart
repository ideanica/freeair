/// Seberapa jauh sebuah ambang sudah bisa disebut "personal".
enum TierKalibrasi {
  /// Belum ada data sendiri yang cukup; angka murni dari literatur.
  literatur,

  /// Data mulai terkumpul; angka literatur dicampur dengan median pribadi.
  sebagian,

  /// Data cukup; median/MAD pribadi yang dipakai.
  personal;

  String get label => switch (this) {
    TierKalibrasi.literatur => 'LITERATUR',
    TierKalibrasi.sebagian => 'SEBAGIAN',
    TierKalibrasi.personal => 'PERSONAL',
  };

  bool get sudahTerkalibrasi => this != TierKalibrasi.literatur;
}

/// Statistik robust satu metrik dari riwayat sampel siklus.
class Statistik {
  const Statistik({
    required this.key,
    required this.jumlahHari,
    this.median,
    this.mad,
    this.terakhir,
    this.nilai = const [],
  });

  static const Statistik kosong = Statistik(key: '', jumlahHari: 0);

  final String key;

  /// Jumlah hari berbeda yang menyumbang nilai (bukan jumlah baris mentah).
  final int jumlahHari;
  final double? median;

  /// Median Absolute Deviation; `null` bila MAD = 0 atau data kurang.
  final double? mad;

  /// Nilai paling baru tercatat.
  final double? terakhir;

  /// Semua nilai harian yang dipakai (untuk debug dan UI kalibrasi).
  final List<double> nilai;

  bool get tersedia => median != null && jumlahHari > 0;

  /// Modified z-score Iglewicz-Hoaglin: 0.6745 * (x - median) / MAD.
  double? zSkor(double x) {
    final m = median;
    final d = mad;
    if (m == null || d == null || d == 0) return null;
    return 0.6745 * (x - m) / d;
  }

  /// Persentase selisih [x] terhadap median pribadi (bisa negatif).
  double? deviasiPct(double x) {
    final m = median;
    if (m == null || m == 0) return null;
    return (x - m) / m * 100;
  }

  double? deltaAbsolut(double x) {
    final m = median;
    if (m == null) return null;
    return x - m;
  }

  Statistik salin({int? jumlahHari, double? median, double? mad}) => Statistik(
    key: key,
    jumlahHari: jumlahHari ?? this.jumlahHari,
    median: median ?? this.median,
    mad: mad ?? this.mad,
    terakhir: terakhir,
    nilai: nilai,
  );
}

/// Kumpulan baseline personal untuk satu siklus pemeriksaan.
class BaselineSet {
  const BaselineSet({required this.metrik, required this.jendelaHari});

  static const BaselineSet kosong = BaselineSet(metrik: {}, jendelaHari: 0);

  final Map<String, Statistik> metrik;

  /// Panjang jendela trailing yang dipakai (hari), dari rule_config.json.
  final int jendelaHari;

  Statistik operator [](String key) => metrik[key] ?? Statistik.kosong;

  bool get punyaData => metrik.values.any((s) => s.tersedia);

  /// Tier sebuah metrik berdasar jumlah hari yang mendasarinya.
  TierKalibrasi tier(
    String key, {
    required int minimumPersonal,
    required int minimumSebagian,
  }) {
    final s = this[key];
    if (!s.tersedia) return TierKalibrasi.literatur;
    if (s.jumlahHari >= minimumPersonal) return TierKalibrasi.personal;
    if (s.jumlahHari >= minimumSebagian) return TierKalibrasi.sebagian;
    return TierKalibrasi.literatur;
  }

  /// Nilai efektif: literatur, campuran, atau murni personal.
  ///
  /// Pada tier SEBAGIAN angka literatur tetap dipakai sebagian supaya
  /// cold-start tidak langsung melompat ke median pribadi yang masih liar.
  double nilaiEfektif(
    String key, {
    required double literatur,
    required int minimumPersonal,
    required int minimumSebagian,
    required double bobotPersonal,
  }) {
    final s = this[key];
    final m = s.median;
    final t = tier(
      key,
      minimumPersonal: minimumPersonal,
      minimumSebagian: minimumSebagian,
    );
    switch (t) {
      case TierKalibrasi.personal:
        return m!;
      case TierKalibrasi.sebagian:
        final w = (bobotPersonal * (s.jumlahHari / minimumPersonal)).clamp(
          0.0,
          bobotPersonal,
        );
        return literatur * (1 - w) + m! * w;
      case TierKalibrasi.literatur:
        return literatur;
    }
  }

  /// Ambang personal yang lebih ketat dari literatur tidak boleh membuat
  /// alert palsu: untuk metrik "semakin rendah semakin buruk" kita ambil
  /// nilai TERKECIL yang masuk akal, sebaliknya untuk "semakin tinggi
  /// semakin buruk".
  double batasEfektif(
    String key, {
    required double literatur,
    required int minimumPersonal,
    required int minimumSebagian,
    required double bobotPersonal,
    required double margin,
    bool lebihBurukJikaTurun = true,
  }) {
    final e = nilaiEfektif(
      key,
      literatur: literatur,
      minimumPersonal: minimumPersonal,
      minimumSebagian: minimumSebagian,
      bobotPersonal: bobotPersonal,
    );
    return lebihBurukJikaTurun ? e - margin : e + margin;
  }

  String keterangan(String key, {String satuan = ''}) {
    final s = this[key];
    if (!s.tersedia) return 'belum ada data';
    final m = s.median!.toStringAsFixed(s.median! >= 100 ? 0 : 1);
    return '$m$satuan dari ${s.jumlahHari} hari';
  }
}
