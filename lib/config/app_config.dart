// Nama konstanta mengikuti spesifikasi integrasi (UPPER_CASE), jadi linter
// penamaan Dart sengaja dimatikan di file konfigurasi ini.
// ignore_for_file: constant_identifier_names

/// Konfigurasi perilaku aplikasi.
///
/// Notifikasi aktif: hasil WASPADA ke atas dikirim sebagai alert lokal.
/// Mode observasi (false) tetap bisa dinyalakan kembali saat kalibrasi
/// ulang, dan spanduk penjelasannya di beranda mengikuti flag ini.
class AppConfig {
  static const bool ENABLE_NOTIFICATIONS = true;

  static const int CYCLE_INTERVAL_MINUTES = 15;

  /// Kode wilayah BMKG tingkat kelurahan (ADM-4). Bisa diubah di halaman Profil.
  static const String BMKG_KODE_WILAYAH = '35.10.07.2008';

  static const int BMKG_CACHE_TTL_MENIT = 180;
}
