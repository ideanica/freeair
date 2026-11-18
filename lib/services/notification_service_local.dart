import 'dart:io' show Platform;
import 'dart:typed_data' show Int64List;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../config/app_config.dart';
import '../l10n/app_settings.dart';
import '../l10n/l10n.dart';
import '../models/condition_result.dart';
import 'notification_service.dart';
import 'notification_service_noop.dart' show NoopNotificationService;

export 'notification_service.dart';

const _channelId = 'health_alert_channel';

/// Notifikasi "siklus berikutnya" memakai id sendiri supaya tidak pernah
/// menimpa alert klinis dan selalu bisa dibatalkan saat aplikasi hidup lagi.
const _pengingatId = 4711;

/// Nama kanal dipakai Android sekali dan disimpan sistem, jadi bahasanya
/// mengikuti pengaturan saat aplikasi pertama kali membuat kanal.
NotificationDetails _details(L10n kamus) => NotificationDetails(
  android: AndroidNotificationDetails(
    _channelId,
    kamus.t('notif.nama_kanal'),
    channelDescription: kamus.t('notif.deskripsi_kanal'),
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList(<int>[0, 400, 200, 500]),
    // Alert kesehatan tidak boleh menggantung berhari-hari di status bar.
    timeoutAfter: Duration(hours: 3).inMilliseconds,
  ),
  iOS: const DarwinNotificationDetails(
    presentAlert: true,
    presentSound: true,
    presentBadge: true,
  ),
);

class LocalNotificationService implements NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> init() async {
    final kamus = L10n.untuk(AppSettings.locale);
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      await _android?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId,
          kamus.t('notif.nama_kanal'),
          description: kamus.t('notif.deskripsi_kanal'),
          importance: Importance.high,
        ),
      );
      await _android?.requestNotificationsPermission();
    } catch (e, s) {
      debugPrint('Gagal menyiapkan notifikasi: $e — $s');
    }
  }

  @override
  Future<void> showAlert(ConditionResult result) async {
    try {
      if (!await _sudahDiizinkan()) return;
      final kamus = L10n.untuk(AppSettings.locale);
      await _plugin.show(
        // id stabil per kondisi: alert baru menggantikan alert lama
        result.kondisi.hashCode & 0x7fffffff,
        kamus.t('notif.judul', {
          'kondisi': result.kondisi,
          'level': result.level,
        }),
        result.intervensi,
        _details(kamus),
      );
    } catch (e, s) {
      debugPrint('Gagal menampilkan notifikasi: $e — $s');
    }
  }

  /// Pengingat satu siklus ke depan.
  ///
  /// Timer siklus hanya hidup selama aplikasi jalan. Kalau HP ditutup sebelum
  /// siklus berikutnya, inilah yang masih sempat berbunyi — jadi begitu siklus
  /// baru selesai, pengingat lama dibatalkan lalu dijadwalkan ulang.
  @override
  Future<void> jadwalkanPengingat(Duration jendela) async {
    try {
      if (!AppConfig.ENABLE_NOTIFICATIONS || !_adaPlatform) return;
      if (!await _sudahDiizinkan()) return;
      final kamus = L10n.untuk(AppSettings.locale);
      await _plugin.zonedSchedule(
        _pengingatId,
        kamus.t('notif.pengingat_judul'),
        kamus.t('notif.pengingat_pesan'),
        tz.TZDateTime.from(DateTime.now().add(jendela), tz.local),
        _details(kamus),
        // Inexact: tidak butuh izin SCHEDULE_EXACT_ALARM dan tetap aman kalau
        // sistem menunda beberapa menit.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // Hanya dibaca iOS < 10; absoluteTime = waktu absolut, sama seperti
        // yang dihitung di atas.
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, s) {
      debugPrint('Gagal menjadwalkan pengingat: $e — $s');
    }
  }

  @override
  Future<void> batalkanPengingat() async {
    try {
      await _plugin.cancel(_pengingatId);
    } catch (e, s) {
      debugPrint('Gagal membatalkan pengingat: $e — $s');
    }
  }

  bool get _adaPlatform => Platform.isAndroid || Platform.isIOS;

  /// False hanya kalau pengguna menolak izin; kalau belum pernah ditanya,
  /// izin diminta sekali di sini lalu alert tetap dikirim (Android menolak
  /// diam-diam, dan kegagalan itu tercatat di log, bukan menjatuhkan siklus).
  Future<bool> _sudahDiizinkan() async {
    try {
      if (Platform.isAndroid) {
        final diizinkan = await _android?.areNotificationsEnabled();
        if (diizinkan == true) return true;
        await _android?.requestNotificationsPermission();
        final setelah = await _android?.areNotificationsEnabled();
        if (setelah != true) {
          debugPrint(
            'Notifikasi masih tidak diizinkan; alert hanya tampil di aplikasi.',
          );
        }
        return setelah ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Gagal memeriksa izin notifikasi: $e');
      return true;
    }
  }
}

NotificationService createNotificationService() {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return NoopNotificationService();
  }
  return LocalNotificationService();
}
