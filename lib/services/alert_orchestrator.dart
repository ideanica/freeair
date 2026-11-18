import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;

import '../config/app_config.dart';
import '../models/alert_record.dart';
import '../models/condition_result.dart';
import '../models/health_data.dart';
import '../models/health_profile.dart';
import '../models/health_sample.dart';
import '../models/sensor_snapshot.dart';
import '../models/threshold_set.dart';
import 'air_quality_service.dart';
import 'baseline_engine.dart';
import 'database_helpers.dart';
import 'health_services.dart';
import 'notification_services.dart';
import 'rule_config.dart';
import 'rule_engine.dart';
import 'threshold_resolver.dart';
import 'weather_service.dart';

/// Hasil satu siklus pemeriksaan, dipakai UI untuk menampilkan angka.
class CycleOutcome {
  CycleOutcome({
    required this.at,
    required this.results,
    required this.snapshot,
    required this.ambang,
    required this.notified,
    required this.notificationsEnabled,
  });

  final DateTime at;
  final List<ConditionResult> results;

  /// Semua data sensor + lingkungan yang dinilai pada siklus ini.
  final SensorSnapshot snapshot;

  /// Ambang yang terpakai, beserta asal setiap angkanya.
  final ThresholdSet ambang;

  /// Kondisi yang benar-benar dikirim sebagai notifikasi pada siklus ini.
  final List<ConditionResult> notified;

  /// Mode observasi: notifikasi mati, hasil hanya dicatat.
  final bool notificationsEnabled;

  double? get suhu => snapshot.suhu;
  HeartRateSummary? get heartRate => snapshot.heartRate;
  SleepSummary? get sleep => snapshot.sleep;
  Spo2Summary? get spo2 => snapshot.spo2;
  HrvSummary? get hrv => snapshot.hrv;
  WeatherForecast? get cuaca => snapshot.cuaca;
  AirQuality? get udara => snapshot.udara;

  /// Rekam jejak ambang untuk layar Kalibrasi.
  List<AmbangInfo> get provenance => ambang.provenance;

  ConditionResult? resultUntuk(String kondisi) {
    for (final r in results) {
      if (r.kondisi == kondisi) return r;
    }
    return null;
  }

  String get levelTertinggi => ConditionResult.levelTertinggi(results);
}

/// Sensor → baseline → ambang → rule engine → riwayat → notifikasi.
///
/// Ini juga [ChangeNotifier]: siklus awal dan siklus berkala 15 menit tidak
/// dipicu UI, jadi layar berlangganan ke sini supaya hasil terbaru langsung
/// tampil tanpa pengguna menekan tombol apa pun.
class AlertOrchestrator extends ChangeNotifier {
  AlertOrchestrator({
    required this.ruleEngine,
    HealthService? healthService,
    WeatherService? weatherService,
    AirQualityService? airQualityService,
    NotificationService? notificationService,
    DatabaseHelper? databaseHelper,
  }) : healthService = healthService ?? createHealthService(),
       weatherService = weatherService ?? WeatherService(),
       airQualityService = airQualityService ?? AirQualityService(),
       notificationService = notificationService ?? createNotificationService(),
       databaseHelper = databaseHelper ?? createDatabaseHelper();

  final RuleEngine ruleEngine;
  final HealthService healthService;
  final WeatherService weatherService;
  final AirQualityService airQualityService;
  final NotificationService notificationService;
  final DatabaseHelper databaseHelper;

  Timer? _timer;

  late final ThresholdResolver _resolver = ThresholdResolver(
    config,
    BaselineEngine(config),
  );

  CycleOutcome? _hasilTerakhir;

  /// Hasil siklus terakhir; null sebelum siklus pertama selesai.
  CycleOutcome? get hasilTerakhir => _hasilTerakhir;

  RuleConfig get config => ruleEngine.config;

  /// Membaca semua sensor, menghitung ambang dari riwayat pemilik data,
  /// menilai kondisi, mencatat riwayat, lalu (bila diizinkan) mengirim
  /// notifikasi dengan deduplikasi.
  Future<CycleOutcome> runCycle({
    HealthProfile? profil,
    bool forceRefreshCuaca = false,
  }) async {
    final now = DateTime.now();
    final activeProfile = profil ?? await HealthProfile.load();

    final mentah = await healthService.bacaSnapshot();
    final cuaca = await _bacaCuaca(activeProfile, forceRefreshCuaca);
    final udara = await _bacaUdara(cuaca);
    final data = mentah.copyWith(cuaca: cuaca, udara: udara);

    final samples = await _sampelKalibrasi();
    final ambang = _resolver.resolve(samples: samples, sekarang: now);

    final results = ruleEngine.evaluasi(
      data,
      ambang,
      kondisiAktif: activeProfile?.kondisi,
    );

    await databaseHelper.insertSample(
      HealthSample(
        at: now,
        metrics: data.metrikSampel,
        levelTertinggi: ConditionResult.levelTertinggi(results),
      ),
    );

    // Snapshot sebelum menulis: dedup butuh level siklus sebelumnya.
    final sebelumnya = <String, AlertRecord?>{
      for (final r in results)
        r.kondisi: await databaseHelper.getLastAlert(r.kondisi),
    };

    for (final r in results) {
      await databaseHelper.insertAlert(r, _audit(r, ambang, data));
    }

    final notified = <ConditionResult>[];
    if (AppConfig.ENABLE_NOTIFICATIONS) {
      for (final r in results.where((x) => x.butuhAlert)) {
        if (_bolehKirim(r, sebelumnya[r.kondisi], now: now)) {
          await notificationService.showAlert(r);
          notified.add(r);
        }
      }
    }

    final outcome = CycleOutcome(
      at: now,
      results: results,
      snapshot: data,
      ambang: ambang,
      notified: notified,
      notificationsEnabled: AppConfig.ENABLE_NOTIFICATIONS,
    );
    _hasilTerakhir = outcome;
    notifyListeners();

    // Timer siklus hanya hidup selama aplikasi jalan. Pengingat berjendela
    // sedikit lebih panjang dari intervalnya, jadi ia baru berbunyi kalau
    // HP benar-benar ditutup sebelum siklus berikutnya.
    if (AppConfig.ENABLE_NOTIFICATIONS) {
      await notificationService.batalkanPengingat();
      await notificationService.jadwalkanPengingat(
        Duration(minutes: AppConfig.CYCLE_INTERVAL_MINUTES + 3),
      );
    }
    return outcome;
  }

  Future<WeatherForecast?> _bacaCuaca(
    HealthProfile? profil,
    bool forceRefresh,
  ) async {
    try {
      return await weatherService.getForecast(
        kodeWilayah: profil?.bmkgKodeWilayah ?? AppConfig.BMKG_KODE_WILAYAH,
        forceRefresh: forceRefresh,
      );
    } catch (e, s) {
      debugPrint('Cuaca gagal diambil: $e — $s');
      return null;
    }
  }

  /// Koordinatnya dari blok `lokasi` BMKG, jadi tidak ada pengaturan tambahan.
  Future<AirQuality?> _bacaUdara(WeatherForecast? cuaca) async {
    final lat = cuaca?.latitude;
    final lon = cuaca?.longitude;
    if (lat == null || lon == null) return null;
    try {
      return await airQualityService.getUdara(latitude: lat, longitude: lon);
    } catch (e, s) {
      debugPrint('Kualitas udara gagal diambil: $e — $s');
      return null;
    }
  }

  /// Riwayat yang dipakai menghitung baseline.
  ///
  /// Pada platform tanpa sensor nyata penyimpanan masih kosong di siklus
  /// pertama, jadi riwayat benih simulasi dimasukkan sekali agar kalibrasi
  /// bisa didemokan dan diuji. Di Android riwayatnya murni rekaman perangkat.
  Future<List<HealthSample>> _sampelKalibrasi() async {
    final jendela = config.jendelaHari;
    var samples = await databaseHelper.getSamples(days: jendela);
    if (samples.isEmpty) {
      final benih = await healthService.benihRiwayat();
      if (benih.isNotEmpty) {
        for (final s in benih) {
          await databaseHelper.insertSample(s);
        }
        samples = await databaseHelper.getSamples(days: jendela);
      }
    }
    return samples;
  }

  /// Jejak audit untuk riwayat: angka sensor + ambang yang dipakai + tier.
  Map<String, dynamic> _audit(
    ConditionResult r,
    ThresholdSet ambang,
    SensorSnapshot data,
  ) => {
    ...data.metrikSampel,
    'kalibrasi': r.kalibrasi,
    'confidence': data.confidence,
    'ambang': {
      for (final p in ambang.provenance)
        p.labelKey: '${p.nilaiTeks}${p.satuan}',
    },
  };

  /// Deduplikasi: alert kondisi yang sama tidak dikirim ulang dalam
  /// `deduplikasi.kirim_ulang_setelah_menit`, kecuali levelnya berubah
  /// (`kirim_ulang_jika_level_berubah`). Level AMAN sudah tersaring di
  /// `butuhAlert`, jadi tidak perlu diperiksa lagi.
  bool _bolehKirim(
    ConditionResult r,
    AlertRecord? sebelumnya, {
    required DateTime now,
  }) {
    if (sebelumnya == null) return true;

    if (config.dedupJikaLevelBerubah && sebelumnya.level != r.level) {
      return true;
    }
    final umur = now.difference(sebelumnya.timestamp);
    return umur.inMinutes >= config.dedupMenit;
  }

  /// Membersihkan penyimpanan lama — cukup sekali saat aplikasi dibuka.
  Future<void> bereskan() async {
    await databaseHelper.clearOldAlerts();
    await databaseHelper.clearOldSamples(days: config.jendelaHari + 7);
  }

  void startPeriodic({int minutes = AppConfig.CYCLE_INTERVAL_MINUTES}) {
    stopPeriodic();
    _timer = Timer.periodic(Duration(minutes: minutes), (_) async {
      try {
        await runCycle();
      } catch (e, s) {
        debugPrint('Siklus berkala gagal: $e — $s');
      }
    });
  }

  void stopPeriodic() => _timer?.cancel();
}
