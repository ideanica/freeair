/// Satu sinyal yang diperiksa sebuah kondisi, beserta ambang yang berlaku.
///
/// Pemicu saja tidak cukup untuk menjelaskan hasil: ketika skornya 0 dan
/// levelnya AMAN, tidak ada satu pun pemicu yang tersisa untuk dibaca. Daftar
/// ini mencatat sinyal yang DILIHAT kondisi tersebut — nilainya, ambang yang
/// sedang berlaku, dan apakah ambangnya terlampaui — jadi "kenapa 0/100"
/// selalu punya jawaban, termasuk saat datanya memang tidak terkirim.
class Pemeriksaan {
  const Pemeriksaan({
    required this.labelKey,
    this.nilai,
    this.nilaiTeks,
    this.satuan = '',
    this.ambang,
    this.arah = 'bawah',
    required this.terpicu,
  });

  /// Kunci kamus nama sinyalnya, mis. `periksa.suhu`.
  final String labelKey;

  /// Angka yang terbaca. `null` berarti sumber datanya tidak mengirim apa pun.
  final double? nilai;

  /// Pengganti [nilai] untuk sinyal yang bukan angka, mis. fase siklus.
  final String? nilaiTeks;

  /// Simbol satuan mentah ('%', '°C', 'bpm'); diterjemahkan [L10n.satuan].
  final String satuan;

  /// Ambang yang dipakai siklus ini sebagai pembanding.
  final double? ambang;

  /// Arah aturan: `bawah` berarti skor bertambah kalau nilai turun di bawah
  /// ambang (SpO2, tidur), `atas` berarti sebaliknya (PM2.5, laju napas).
  final String arah;

  final bool terpicu;

  bool get tersedia => nilai != null || nilaiTeks != null;
}
