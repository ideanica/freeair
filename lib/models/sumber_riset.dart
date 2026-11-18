/// Satu rujukan yang bisa dibuka dari layar Sumber.
///
/// Dipakai untuk menunjukkan dari mana setiap angka ambang datang, jadi
/// isinya sengaja lebih ketat daripada kutipan pendek di blok `literatur`:
/// setiap entri membawa tautan dan angka yang dia tetapkan.
class SumberRiset {
  const SumberRiset({
    required this.judul,
    required this.penulis,
    required this.tahun,
    required this.terbitan,
    required this.tipe,
    required this.url,
    required this.menetapkan,
    required this.status,
    this.catatan,
    this.menetapkanEn = const [],
    this.catatanEn,
  });

  factory SumberRiset.fromJson(Map<String, dynamic> json) => SumberRiset(
    judul: json['judul'] as String? ?? '-',
    penulis: json['penulis'] as String? ?? '-',
    tahun: (json['tahun'] ?? '').toString(),
    terbitan: json['terbitan'] as String? ?? '-',
    tipe: json['tipe'] as String? ?? 'rujukan',
    url: json['url'] as String? ?? '',
    menetapkan: _daftar(json['menetapkan']),
    status: json['status'] as String? ?? 'terverifikasi',
    catatan: json['catatan'] as String?,
    menetapkanEn: _daftar(json['menetapkan_en']),
    catatanEn: json['catatan_en'] as String?,
  );

  final String judul;
  final String penulis;
  final String tahun;
  final String terbitan;

  /// `jurnal` | `pedoman` | `standar` | `buku` | `api` | `dataset` | `paket`.
  final String tipe;
  final String url;

  /// Angka/ambang yang bersandar pada rujukan ini.
  final List<String> menetapkan;

  /// `terverifikasi` | `perlu_cek` | `tidak_ditemukan`.
  final String status;
  final String? catatan;

  /// Varian English (opsional) dari catatan dan angka yang ditetapkan;
  /// tanpa keduanya layar Sumber jatuh ke teks Indonesia.
  final List<String> menetapkanEn;
  final String? catatanEn;

  bool get punyaTautan => url.trim().isNotEmpty;

  List<String> menetapkanDalam(String locale) =>
      locale == 'id' || menetapkanEn.isEmpty ? menetapkan : menetapkanEn;

  String? catatanDalam(String locale) =>
      locale == 'id' || catatanEn == null ? catatan : catatanEn;

  /// Baris "penulis · tahun · terbitan" untuk di bawah judul.
  String get kredit {
    final parts = [
      penulis,
      if (tahun.isNotEmpty) tahun,
      terbitan,
    ].where((p) => p.trim().isNotEmpty && p != '-').toList();
    return parts.join(' · ');
  }

  static List<String> _daftar(dynamic value) => switch (value) {
    final List<Object?> list => [for (final item in list) item.toString()],
    null => const [],
    _ => [value.toString()],
  };
}

/// Sekumpulan rujukan dengan satu topik, mis. "Oksigen & napas".
class KelompokSumber {
  const KelompokSumber({
    required this.judul,
    required this.deskripsi,
    required this.sumber,
    this.judulEn,
    this.deskripsiEn,
  });

  factory KelompokSumber.fromJson(Map<String, dynamic> json) => KelompokSumber(
    judul: json['judul'] as String? ?? '-',
    deskripsi: json['deskripsi'] as String? ?? '',
    judulEn: _teks(json['judul_en']),
    deskripsiEn: _teks(json['deskripsi_en']),
    sumber: [
      for (final item in (json['sumber'] as List? ?? const []))
        if (item is Map) SumberRiset.fromJson(Map<String, dynamic>.from(item)),
    ],
  );

  final String judul;
  final String deskripsi;
  final List<SumberRiset> sumber;

  /// Varian English grup; `[judulAsli]` tetap dipakai untuk mencocokkan ikon
  /// topik karena kata kuncinya berbahasa Indonesia.
  final String? judulEn;
  final String? deskripsiEn;

  int get jumlah => sumber.length;

  String judulDalam(String locale) =>
      locale == 'id' || judulEn == null ? judul : judulEn!;

  String deskripsiDalam(String locale) =>
      locale == 'id' || deskripsiEn == null ? deskripsi : deskripsiEn!;

  static String? _teks(dynamic value) {
    final teks = value as String?;
    return teks == null || teks.trim().isEmpty ? null : teks;
  }
}
