import '../models/alert_record.dart';
import '../models/condition_result.dart';
import '../models/health_sample.dart';

/// Penyimpanan riwayat hasil cek dan sampel siklus.
///
/// Android memakai SQLite (sqflite). Web/desktop memakai fallback
/// SharedPreferences karena sqflite tidak punya implementasi JavaScript —
/// riwayat dan kalibrasi tetap bisa dilihat saat pengembangan UI di Chrome.
abstract class DatabaseHelper {
  /// Membuka / menyiapkan penyimpanan.
  Future<void> init();

  Future<int> insertAlert(ConditionResult result, Map<String, dynamic> input);

  Future<List<AlertRecord>> getRecentAlerts({int limit});

  /// Alert terakhir untuk satu kondisi, tanpa peduli levelnya. Dedup butuh
  /// level sebelumnya untuk memutuskan "level berubah".
  Future<AlertRecord?> getLastAlert(String kondisi);

  Future<void> clearOldAlerts({int days});

  /// Mencatat nilai mentah satu siklus sebagai bahan kalibrasi.
  Future<void> insertSample(HealthSample sample);

  /// Sampel dalam [hari] terakhir, terbaru dulu.
  Future<List<HealthSample>> getSamples({int days});

  Future<void> clearOldSamples({int days});
}
