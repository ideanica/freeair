import '../models/condition_result.dart';
import 'notification_service.dart';

export 'notification_service.dart';

/// Dipakai di web dan di platform yang tidak mendukung notifikasi sistem.
///
/// Jadwal pengingat tetap diterima tanpa melakukan apa pun: siklus aplikasi
/// berjalan di timer, jadi tanpa notifikasi sistem memang tidak ada yang
/// perlu dijanjikan ke pengguna.
class NoopNotificationService implements NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<void> showAlert(ConditionResult result) async {}

  @override
  Future<void> jadwalkanPengingat(Duration jendela) async {}

  @override
  Future<void> batalkanPengingat() async {}
}

NotificationService createNotificationService() => NoopNotificationService();
