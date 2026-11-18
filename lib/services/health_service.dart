import '../models/health_sample.dart';
import '../models/sensor_snapshot.dart';

/// Sumber data kesehatan yang dipakai rule engine.
///
/// Implementasi dipilih per platform di `health_services.dart`: Health Connect
/// pada Android/iOS, dan data simulasi pada web/desktop supaya UI serta
/// kalibrasi dinamis tetap bisa dijalankan dan diuji.
///
/// Kontrak: TIDAK ADA input manual. Semua angka datang dari sensor.
/// Semua metode null-safe — sensor yang tidak mengembalikan data menghasilkan
/// `null` (bukan exception) sehingga satu data yang hilang tidak menghentikan
/// siklus pemeriksaan.
abstract class HealthService {
  /// Label sumber data, ditampilkan di UI agar pengguna tahu datanya asli
  /// atau simulasi.
  String get sourceLabel;

  /// Meminta izin akses data. Mengembalikan `true` bila izin diberikan.
  Future<bool> requestPermissions();

  /// Membaca semua sinyal fisiologis pada [jendela] terakhir.
  ///
  /// Hasilnya hanya berisi data tubuh; cuaca dan kualitas udara ditambahkan
  /// orchestrator lewat [SensorSnapshot.copyWith].
  Future<SensorSnapshot> bacaSnapshot({Duration jendela});

  /// Riwayat benih untuk platform tanpa sensor nyata (web/desktop), supaya
  /// baseline personal dan pembelajaran ambang dingin punya bahan hitungan
  /// sejak siklus pertama. Implementasi native mengembalikan list kosong —
  /// riwayat di sana benar-benar hasil rekaman perangkat sendiri.
  Future<List<HealthSample>> benihRiwayat();
}
