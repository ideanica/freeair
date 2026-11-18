/// Satu pemicu skor, disimpan sebagai kode + angka, bukan kalimat jadi.
///
/// Dulu rule engine merakit kalimat Indonesia lengkap ("Suhu 5°C — sangat
/// dingin, 13.0°C di bawah band literatur 18.0°C") lalu menyimpannya ke
/// database, sehingga teks itu tidak bisa dialihbahasakan setelah tersimpan.
/// Dengan kode + argumen, kalimatnya dirakit saat ditampilkan, jadi baris
/// riwayat yang sama bisa dibaca dalam bahasa mana pun.
class Pemicu {
  const Pemicu(
    this.kode, [
    this.arg = const <String, String>{},
    this.bobot,
  ]);

  /// Kunci template di kamus bahasa, mis. `dingin.sangat_dingin`.
  final String kode;

  /// Nilai yang sudah diformat (angka, satuan) untuk disisipkan ke template.
  /// Nilai yang diawali `@` adalah rujukan ke template lain, dipakai untuk
  /// frasa bersarang seperti asal ambang.
  final Map<String, String> arg;

  /// Berapa poin yang disumbangkan pemicu ini ke skor. `null` untuk baris
  /// lama yang belum menyimpan bobot.
  final int? bobot;

  Map<String, dynamic> toJson() => {
    'kode': kode,
    if (arg.isNotEmpty) 'arg': arg,
    if (bobot != null) 'bobot': bobot,
  };

  static Pemicu fromJson(Object? value) {
    if (value is! Map) return const Pemicu('pemicu.tidak_dikenal');
    final arg = value['arg'];
    final bobot = value['bobot'];
    return Pemicu(
      value['kode'] as String? ?? 'pemicu.tidak_dikenal',
      arg is Map
          ? {for (final e in arg.entries) e.key.toString(): '${e.value}'}
          : const <String, String>{},
      bobot is num ? bobot.toInt() : null,
    );
  }

  static List<Pemicu> dariJson(Object? value) => value is List
      ? [for (final item in value) Pemicu.fromJson(item)]
      : const <Pemicu>[];

  static List<Map<String, dynamic>> keJson(List<Pemicu> pemicu) => [
    for (final p in pemicu) p.toJson(),
  ];
}
