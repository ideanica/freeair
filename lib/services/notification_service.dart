import '../models/condition_result.dart';

/// Pengirim peringatan ke luar aplikasi (status bar).
///
/// Di web implementasinya no-op; peringatan tetap tampil sebagai kartu
/// di dalam aplikasi.
abstract class NotificationService {
  Future<void> init();

  Future<void> showAlert(ConditionResult result);

  /// Menjaga agar satu siklus berikutnya tetap punya kesempatan mengingatkan
  /// pengguna walaupun aplikasi ditutup sebelum timer berikutnya jalan.
  Future<void> jadwalkanPengingat(Duration jendela);

  Future<void> batalkanPengingat();
}
