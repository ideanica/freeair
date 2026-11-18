import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:health_connector/health_connector.dart';

import '../models/health_data.dart';
import '../models/health_sample.dart';
import '../models/nilai_fisiologis.dart';
import '../models/sensor_snapshot.dart';
import 'health_service.dart';
import 'health_service_demo.dart' show DemoHealthService;

export 'health_service.dart';

/// Membaca data dari Health Connect (Android) / HealthKit (iOS).
///
/// Tidak ada satu pun angka yang diminta ke pengguna. Semua sinyal diambil
/// dari rentang waktu berjalan dan setiap kegagalan (plugin unavailable, izin
/// ditolak, record kosong) dikembalikan sebagai `null` agar siklus cek tetap
/// jalan dan rule engine tetap menilai dengan data yang ada.
class HealthConnectService implements HealthService {
  /// Batas halaman saat menelusuri riwayat, agar satu siklus tidak menggantung
  /// kalau perangkat mengirim ribuan record.
  static const int _maksHalaman = 6;

  /// `pageSize` bawaan plugin hanya 100 record; wearable mengirim SpO2 dan
  /// HRV jauh lebih sering dari itu dalam sehari.
  static const int _ukuranHalaman = 400;

  static const int _maksBacaanSpo2 = 120;
  static const Duration _jendelaTidur = Duration(hours: 36);
  static const Duration _jendelaSiklus = Duration(days: 365);

  HealthConnector? _connector;

  Future<HealthConnector?> _getConnector() async {
    final existing = _connector;
    if (existing != null) return existing;
    try {
      final created = await HealthConnector.create();
      _connector = created;
      return created;
    } on HealthConnectorException catch (e, s) {
      debugPrint('Health Connector tidak tersedia: ${e.code} — $s');
    } catch (e, s) {
      debugPrint('Gagal menyiapkan Health Connector: $e — $s');
    }
    return null;
  }

  @override
  String get sourceLabel => Platform.isIOS ? 'Apple Health' : 'Health Connect';

  @override
  Future<bool> requestPermissions() async {
    final connector = await _getConnector();
    if (connector == null) return false;
    try {
      final hasil = await connector.requestPermissions([
        HealthDataType.heartRateSeriesRecord.readPermission,
        HealthDataType.restingHeartRate.readPermission,
        HealthDataType.heartRateVariabilityRMSSD.readPermission,
        HealthDataType.oxygenSaturation.readPermission,
        HealthDataType.respiratoryRate.readPermission,
        HealthDataType.sleepSession.readPermission,
        HealthDataType.exerciseSession.readPermission,
        HealthDataType.steps.readPermission,
        HealthDataType.menstrualFlowInstant.readPermission,
        HealthPlatformFeature.readHealthDataHistory.permission,
        HealthPlatformFeature.readHealthDataInBackground.permission,
      ]);
      final diberikan = hasil
          .where((r) => r.status != PermissionStatus.denied)
          .length;
      debugPrint('Izin Health Connect: $diberikan/${hasil.length} diberikan.');
      return diberikan > 0;
    } catch (e, s) {
      debugPrint('Gagal meminta izin Health Connect: $e — $s');
      return false;
    }
  }

  @override
  Future<SensorSnapshot> bacaSnapshot({
    Duration jendela = const Duration(hours: 24),
  }) async {
    final sekarang = DateTime.now();
    final connector = await _getConnector();
    if (connector == null) {
      debugPrint('Health Connector tidak tersedia — siklus tanpa data sensor.');
      return SensorSnapshot(
        at: sekarang,
        statusSinyal: const {
          'heart_rate': 'gagal',
          'resting_hr': 'gagal',
          'hrv': 'gagal',
          'spo2': 'gagal',
          'resp_rate': 'gagal',
          'sleep': 'gagal',
          'exercise': 'gagal',
          'steps': 'gagal',
          'menstrual': 'gagal',
        },
      );
    }
    final awal = sekarang.subtract(jendela);
    final jumlah = <String, int>{};
    final status = <String, String>{};

    return SensorSnapshot(
      at: sekarang,
      heartRate: await _detakJantung(connector, awal, sekarang, jumlah, status),
      restingHeartRate: await _detakJantungIstirahat(
        connector,
        awal,
        sekarang,
        jumlah,
        status,
      ),
      hrv: await _hrv(connector, awal, sekarang, jumlah, status),
      spo2: await _spo2(connector, awal, sekarang, jumlah, status),
      respRate: await _lajuNapas(connector, awal, sekarang, jumlah, status),
      sleep: await _tidur(connector, sekarang, jumlah, status),
      activity: await _aktivitas(connector, awal, sekarang, jumlah, status),
      cycle: await _siklus(connector, sekarang, jumlah, status),
      jumlahRecord: Map.unmodifiable(jumlah),
      statusSinyal: Map.unmodifiable(status),
    );
  }

  /// Perangkat asli menyimpan riwayatnya sendiri; tidak ada data benih.
  @override
  Future<List<HealthSample>> benihRiwayat() async => const [];

  // =============================================================== pembacaan

  /// Baca halaman pertama lalu telusuri halaman berikutnya sampai
  /// [_maksHalaman]. Kegagalan apa pun menghasilkan list kosong, bukan throw.
  Future<List<R>> _baca<R extends HealthRecord>(
    Future<ReadRecordsInTimeRangeResponse<R>> Function() halamanPertama,
    Future<ReadRecordsInTimeRangeResponse<R>> Function(
      ReadRecordsInTimeRangeResponse<R> response,
    )
    halamanBerikutnya, {
    required String kunci,
    required Map<String, String> status,
  }) async {
    try {
      var respons = await halamanPertama();
      final hasil = <R>[...respons.records];
      var halaman = 1;
      while (respons.hasMorePages && halaman < _maksHalaman) {
        if (respons.nextPageRequest == null) break;
        respons = await halamanBerikutnya(respons);
        hasil.addAll(respons.records);
        halaman++;
      }
      status[kunci] = hasil.isEmpty ? 'kosong' : 'ok';
      return hasil;
    } on HealthConnectorException catch (e, s) {
      status[kunci] = e.code == HealthConnectorErrorCode.notAuthorized
          ? 'izin'
          : 'gagal';
      debugPrint('Gagal membaca $kunci (${e.code}): $e — $s');
      return const [];
    } catch (e, s) {
      status[kunci] = 'gagal';
      debugPrint('Gagal membaca $kunci: $e — $s');
      return const [];
    }
  }

  Future<HeartRateSummary?> _detakJantung(
    HealthConnector connector,
    DateTime awal,
    DateTime akhir,
    Map<String, int> jumlah,
    Map<String, String> status,
  ) async {
    final records = await _baca(
      () => connector.readRecords(
        HealthDataType.heartRateSeriesRecord.readInTimeRange(
          startTime: awal,
          endTime: akhir,
          pageSize: _ukuranHalaman,
        ),
      ),
      (r) => connector.readRecords(r.nextPageRequest!),
      kunci: 'heart_rate',
      status: status,
    );

    final nilai = <int>[];
    DateTime? pertama;
    DateTime? terakhir;
    for (final record in records) {
      for (final sampel in record.samples) {
        nilai.add(sampel.beatsPerMinute.value.round());
        pertama = _min(pertama, sampel.time);
        terakhir = _max(terakhir, sampel.time);
      }
    }
    jumlah['heart_rate'] = nilai.length;
    if (nilai.isEmpty) {
      debugPrint('Health Connect: tidak ada sampel detak jantung.');
      return null;
    }
    return HeartRateSummary(
      minBpm: nilai.reduce(_minInt),
      maxBpm: nilai.reduce(_maxInt),
      avgBpm: (nilai.reduce((a, b) => a + b) / nilai.length).round(),
      latestBpm: nilai.last,
      sampleCount: nilai.length,
      windowStart: pertama ?? awal,
      windowEnd: terakhir ?? akhir,
    );
  }

  Future<RestingHeartRateSummary?> _detakJantungIstirahat(
    HealthConnector connector,
    DateTime awal,
    DateTime akhir,
    Map<String, int> jumlah,
    Map<String, String> status,
  ) async {
    final records = await _baca(
      () => connector.readRecords(
        HealthDataType.restingHeartRate.readInTimeRange(
          startTime: awal,
          endTime: akhir,
          pageSize: _ukuranHalaman,
        ),
      ),
      (r) => connector.readRecords(r.nextPageRequest!),
      kunci: 'resting_hr',
      status: status,
    );
    jumlah['resting_hr'] = records.length;
    if (records.isEmpty) return null;
    final terbaru = records.reduce((a, b) => a.time.isAfter(b.time) ? a : b);
    return RestingHeartRateSummary(
      bpm: terbaru.beatsPerMinute.value.toDouble(),
      sampleCount: records.length,
      at: terbaru.time,
    );
  }

  Future<HrvSummary?> _hrv(
    HealthConnector connector,
    DateTime awal,
    DateTime akhir,
    Map<String, int> jumlah,
    Map<String, String> status,
  ) async {
    final records = await _baca(
      () => connector.readRecords(
        HealthDataType.heartRateVariabilityRMSSD.readInTimeRange(
          startTime: awal,
          endTime: akhir,
          pageSize: _ukuranHalaman,
        ),
      ),
      (r) => connector.readRecords(r.nextPageRequest!),
      kunci: 'hrv',
      status: status,
    );
    final urut = records.toList()..sort((a, b) => a.time.compareTo(b.time));
    final nilai = urut
        .map((r) => r.heartRateVariabilityMillis)
        .where((v) => v > 0)
        .toList();
    jumlah['hrv'] = records.length;
    if (nilai.isEmpty) return null;
    return HrvSummary(
      latestMs: urut.last.heartRateVariabilityMillis,
      avgMs: nilai.fold<double>(0, (a, b) => a + b) / nilai.length,
      minMs: nilai.reduce(_minDouble),
      sampleCount: nilai.length,
    );
  }

  Future<Spo2Summary?> _spo2(
    HealthConnector connector,
    DateTime awal,
    DateTime akhir,
    Map<String, int> jumlah,
    Map<String, String> status,
  ) async {
    final records = await _baca(
      () => connector.readRecords(
        HealthDataType.oxygenSaturation.readInTimeRange(
          startTime: awal,
          endTime: akhir,
          pageSize: _ukuranHalaman,
        ),
      ),
      (r) => connector.readRecords(r.nextPageRequest!),
      kunci: 'spo2',
      status: status,
    );
    final urut = records.toList()..sort((a, b) => a.time.compareTo(b.time));
    final nilai = urut
        .map((r) => normalisasiPersen(r.percentage.asDecimal))
        .whereType<double>()
        .toList();
    jumlah['spo2'] = records.length;
    if (nilai.isEmpty) {
      // Record ada tetapi semuanya tidak masuk akal (mis. 9600% dari plugin
      // lama). Jangan tampilkan angka itu; minta sumber mengirim ulang.
      if (records.isNotEmpty) status['spo2'] = 'gagal';
      return null;
    }
    return Spo2Summary(
      latestPct: nilai.last,
      minPct: nilai.reduce(_minDouble),
      avgPct: nilai.fold<double>(0, (a, b) => a + b) / nilai.length,
      readings: List<double>.unmodifiable(
        nilai.length > _maksBacaanSpo2
            ? nilai.sublist(nilai.length - _maksBacaanSpo2)
            : nilai,
      ),
    );
  }

  Future<RespRateSummary?> _lajuNapas(
    HealthConnector connector,
    DateTime awal,
    DateTime akhir,
    Map<String, int> jumlah,
    Map<String, String> status,
  ) async {
    final records = await _baca(
      () => connector.readRecords(
        HealthDataType.respiratoryRate.readInTimeRange(
          startTime: awal,
          endTime: akhir,
          pageSize: _ukuranHalaman,
        ),
      ),
      (r) => connector.readRecords(r.nextPageRequest!),
      kunci: 'resp_rate',
      status: status,
    );
    final nilai = records
        .map((r) => r.breathsPerMin.value.toDouble())
        .where((v) => v > 0)
        .toList();
    jumlah['resp_rate'] = records.length;
    if (nilai.isEmpty) return null;
    return RespRateSummary(
      latestPerMenit: nilai.last,
      avgPerMenit: nilai.fold<double>(0, (a, b) => a + b) / nilai.length,
      maxPerMenit: nilai.reduce(_maxDouble),
      sampleCount: nilai.length,
    );
  }

  Future<SleepSummary?> _tidur(
    HealthConnector connector,
    DateTime akhir,
    Map<String, int> jumlah,
    Map<String, String> status,
  ) async {
    final records = await _baca(
      () => connector.readRecords(
        HealthDataType.sleepSession.readInTimeRange(
          startTime: akhir.subtract(_jendelaTidur),
          endTime: akhir,
          pageSize: 40,
        ),
      ),
      (r) => connector.readRecords(r.nextPageRequest!),
      kunci: 'sleep',
      status: status,
    );
    jumlah['sleep'] = records.length;
    if (records.isEmpty) {
      debugPrint('Health Connect: tidak ada sesi tidur 36 jam terakhir.');
      return null;
    }
    final sesi = records.reduce((a, b) => a.endTime.isAfter(b.endTime) ? a : b);

    var diKasur = Duration.zero;
    var terbangun = Duration.zero;
    var rem = Duration.zero;
    var dalam = Duration.zero;
    var ringan = Duration.zero;
    for (final tahap in sesi.samples) {
      switch (tahap.stageType) {
        case SleepStageType.inBed:
        case SleepStageType.outOfBed:
          diKasur += tahap.duration;
        case SleepStageType.awake:
          terbangun += tahap.duration;
        case SleepStageType.rem:
          rem += tahap.duration;
        case SleepStageType.deep:
          dalam += tahap.duration;
        case SleepStageType.sleeping:
        case SleepStageType.light:
          ringan += tahap.duration;
        case SleepStageType.unknown:
          break;
      }
    }
    // Sebagian sumber hanya mengirim rentang sesi tanpa rincian tahap, jadi
    // totalSleepDuration-nya nol. Jumlahkan etape tidurnya sebagai cadangan.
    final tidur = sesi.totalSleepDuration > Duration.zero
        ? sesi.totalSleepDuration
        : rem + dalam + ringan;
    if (tidur.inMinutes <= 0) {
      debugPrint('Health Connect: sesi tidur tanpa durasi tidur yang sah.');
      status['sleep'] = 'kosong';
      return null;
    }
    // Sampel inBed sudah membentang meliputi yang terbangun dan yang tidur,
    // jadi menambah keduanya lagi membuat efisiensi selalu tampak sempurna.
    final totalDiKasur = diKasur > Duration.zero
        ? diKasur
        : sesi.endTime.difference(sesi.startTime);

    return SleepSummary(
      startTime: sesi.startTime,
      endTime: sesi.endTime,
      totalSleepMinutes: tidur.inMinutes,
      inBedMinutes: totalDiKasur.inMinutes,
      wasoMinutes: terbangun.inMinutes,
      remMinutes: rem.inMinutes,
      deepMinutes: dalam.inMinutes,
    );
  }

  Future<ActivitySummary?> _aktivitas(
    HealthConnector connector,
    DateTime awal,
    DateTime akhir,
    Map<String, int> jumlah,
    Map<String, String> status,
  ) async {
    final sesi = await _baca(
      () => connector.readRecords(
        HealthDataType.exerciseSession.readInTimeRange(
          startTime: awal,
          endTime: akhir,
          pageSize: 40,
        ),
      ),
      (r) => connector.readRecords(r.nextPageRequest!),
      kunci: 'exercise',
      status: status,
    );
    final langkah = await _baca(
      () => connector.readRecords(
        HealthDataType.steps.readInTimeRange(
          startTime: awal,
          endTime: akhir,
          pageSize: _ukuranHalaman,
        ),
      ),
      (r) => connector.readRecords(r.nextPageRequest!),
      kunci: 'steps',
      status: status,
    );

    final menit = sesi.fold<double>(0, (t, s) => t + s.duration.inMinutes);
    final steps = langkah.isEmpty
        ? null
        : langkah.fold<int>(0, (t, s) => t + s.count.value.round());
    jumlah['exercise'] = sesi.length;
    jumlah['steps'] = langkah.length;
    if (menit <= 0 && (steps == null || steps <= 0)) return null;
    return ActivitySummary(
      exerciseMinutes: menit,
      steps: steps,
      sessionCount: sesi.length,
    );
  }

  /// Hari siklus diturunkan dari jarak antar tanggal haid, bukan dari isian.
  Future<CycleInfo> _siklus(
    HealthConnector connector,
    DateTime akhir,
    Map<String, int> jumlah,
    Map<String, String> status,
  ) async {
    final records = await _baca(
      () => connector.readRecords(
        HealthDataType.menstrualFlowInstant.readInTimeRange(
          startTime: akhir.subtract(_jendelaSiklus),
          endTime: akhir,
          pageSize: _ukuranHalaman,
        ),
      ),
      (r) => connector.readRecords(r.nextPageRequest!),
      kunci: 'menstrual',
      status: status,
    );
    final tanggal = <DateTime>{};
    for (final r in records) {
      tanggal.add(_hari(r.time));
    }
    jumlah['menstrual'] = records.length;
    if (tanggal.isEmpty) return const CycleInfo();

    final urut = tanggal.toList()..sort();
    final haidTerakhir = urut.last;

    double? panjang;
    if (urut.length >= 2) {
      final jarak = <double>[];
      DateTime? sebelumnya;
      for (final t in urut) {
        if (sebelumnya != null) {
          final selisih = t.difference(sebelumnya).inDays;
          // Hari di dalam satu episode haid bukan awal siklus baru.
          if (selisih >= 15 && selisih <= 45) jarak.add(selisih.toDouble());
        }
        sebelumnya = t;
      }
      if (jarak.isNotEmpty) {
        jarak.sort();
        final tengah = jarak.length ~/ 2;
        panjang = jarak.length.isOdd
            ? jarak[tengah]
            : (jarak[tengah - 1] + jarak[tengah]) / 2;
      }
    }

    var cycleDay = _hari(akhir).difference(haidTerakhir).inDays + 1;
    if (cycleDay < 1) cycleDay = 1;
    final batas = panjang?.round();
    if (batas != null && batas > 0 && cycleDay > batas) {
      cycleDay = ((cycleDay - 1) % batas) + 1;
    }

    return CycleInfo(
      cycleDay: cycleDay,
      cycleLengthDays: panjang,
      source: 'menstrualFlowInstant (${urut.length} hari tercatat)',
    );
  }

  // ================================================================= helpers

  static DateTime _hari(DateTime d) => DateTime(d.year, d.month, d.day);

  static int _minInt(int a, int b) => a < b ? a : b;
  static int _maxInt(int a, int b) => a > b ? a : b;
  static double _minDouble(double a, double b) => a < b ? a : b;
  static double _maxDouble(double a, double b) => a > b ? a : b;

  static DateTime? _min(DateTime? a, DateTime b) =>
      (a == null || b.isBefore(a)) ? b : a;
  static DateTime? _max(DateTime? a, DateTime b) =>
      (a == null || b.isAfter(a)) ? b : a;
}

/// Pintu implementasi per platform. Web/desktop tidak bisa memakai
/// `package:health_connector` (import `dart:io`), jadi pakai data simulasi.
HealthService createHealthService() {
  if (!Platform.isAndroid && !Platform.isIOS) {
    debugPrint(
      'Health Connect tidak tersedia di platform ini, pakai data simulasi.',
    );
    return DemoHealthService();
  }
  return HealthConnectService();
}
