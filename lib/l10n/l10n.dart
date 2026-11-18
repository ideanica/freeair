import 'package:flutter/widgets.dart';

import '../models/pemicu.dart';
import 'app_settings.dart';
import 'table_core.dart';
import 'table_engine.dart';
import 'table_history.dart';
import 'table_home.dart';
import 'table_profile.dart';
import 'table_sources.dart';

/// Kamus teks aplikasi untuk satu bahasa.
///
/// Semua teks yang dilihat pengguna diambil dari sini, jadi bahasa bisa
/// diganti tanpa menyentuh logika klinis. Nilai kunci data — nama level,
/// nama kondisi, tier kalibrasi, status rujukan — TIDAK ikut diterjemahkan
/// karena dipakai sebagai kunci peta dan kolom database; yang diterjemahkan
/// hanya label tampilannya.
class L10n {
  const L10n(this.kode);

  static const L10n id = L10n('id');
  static const L10n en = L10n('en');

  /// `id` | `en`.
  final String kode;

  static const Map<String, Map<String, String>> _tabel = {
    'id': {
      ...idCore,
      ...idEngine,
      ...idHome,
      ...idHistory,
      ...idProfile,
      ...idSources,
    },
    'en': {
      ...enCore,
      ...enEngine,
      ...enHome,
      ...enHistory,
      ...enProfile,
      ...enSources,
    },
  };

  static L10n of(BuildContext context) =>
      untuk(Localizations.localeOf(context).languageCode);

  /// Instance untuk kode bahasa tertentu; bahasa tak dikenal jatuh ke id,
  /// sesuai preferensi pengguna di [AppSettings].
  static L10n untuk(String? locale) => switch (locale) {
    'en' => en,
    'id' => id,
    _ => L10n(AppSettings.locale),
  };

  /// Teks untuk [key], dengan `{nama}` diisi dari [arg].
  ///
  /// Nilai argumen yang diawali `@` dianggap nama template lain dan
  /// dirender lebih dulu — dipakai untuk frasa bersarang seperti asal ambang
  /// ("... di bawah band literatur 18.0°C").
  String t(String key, [Map<String, String> arg = const <String, String>{}]) =>
      _render(key, arg, 0);

  String _render(String key, Map<String, String> arg, int kedalaman) {
    final template = _template(key);
    if (template == null) {
      debugPrint('L10n: kunci "$key" tidak ada di kamus ${_tabel.keys}');
      return key;
    }
    var hasil = template;
    arg.forEach((nama, nilai) {
      // Hanya disubstitusi kalau placeholder-nya benar-benar ada di teks yang
      // sedang dibangun. Tanpa cek ini, argumen `status` yang menunjuk ke
      // template lain akan dirender ulang di dalam template itu sendiri dan
      // berulang tanpa akhir. Pengecekannya ke `hasil`, bukan ke template,
      // supaya placeholder yang baru muncul dari teks bersarang ikut terisi.
      if (!hasil.contains('{$nama}')) return;
      hasil = hasil.replaceAll('{$nama}', _isiNilai(nilai, arg, kedalaman));
    });
    return hasil;
  }

  /// Kalimat untuk satu pemicu hasil rule engine.
  ///
  /// [Pemicu.kode] sudah path kunci penuh (`pemicu.spo2.hipoksemia`) supaya
  /// rujukan bersarang di argumen (`@pemicu.status.beruntun`) memakai path
  /// yang sama.
  String pemicu(Pemicu p) => t(p.kode, p.arg);

  /// Daftar kalimat pemicu, untuk kartu hasil dan detail riwayat.
  List<String> pemicuSemua(List<Pemicu> daftar) => [
    for (final p in daftar) pemicu(p),
  ];

  /// Satuan yang dipakai provenance ambang.
  ///
  /// Mayoritas simbol sudah internasional (%, °C, bpm, m/s); hanya beberapa
  /// singkatan Indonesia yang perlu dipadankan. Spasi di depan dipertahankan
  /// supaya tampilan "19 °C" tetap sama.
  String satuan(String mentah) {
    if (kode == 'id') return mentah;
    final spasi = mentah.startsWith(' ') ? ' ' : '';
    return '$spasi${_satuanInggris[mentah.trim()] ?? mentah.trim()}';
  }

  static const Map<String, String> _satuanInggris = {
    'jam': 'h',
    'mnt': 'min',
    'x/mnt': '/min',
    '%poin': '% points',
    'langkah': 'steps',
    'kejadian': 'events',
    'hari': 'days',
  };

  /// Label sumber data dari service.
  ///
  /// Nama produk (Health Connect, BMKG, Open-Meteo) dibiarkan apa adanya;
  /// hanya label buatan service yang punya padanan.
  String sumberData(String mentah) {
    final key = _sumberData[mentah];
    return key == null ? mentah : t(key);
  }

  static const Map<String, String> _sumberData = {
    'Data simulasi': 'sumber.simulasi',
  };

  String? _template(String key) {
    final aktif = _tabel[kode]?[key];
    if (aktif != null) return aktif;
    final cadangan = _tabel['id']?[key];
    if (cadangan != null) {
      debugPrint('L10n: kunci "$key" belum ada di bahasa $kode, pakai id');
      return cadangan;
    }
    return null;
  }

  String _isiNilai(String nilai, Map<String, String> arg, int kedalaman) {
    if (!nilai.startsWith('@') || kedalaman >= 3) return nilai;
    return _render(nilai.substring(1), arg, kedalaman + 1);
  }
}
