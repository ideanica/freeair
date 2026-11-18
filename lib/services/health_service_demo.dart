import 'dart:math' as math;

import '../models/health_data.dart';
import '../models/health_sample.dart';
import '../models/sensor_snapshot.dart';
import '../models/weather_forecast.dart';
import 'health_service.dart';

export 'health_service.dart';

/// Data simulasi untuk platform yang tidak punya Health Connect
/// (web, desktop) sehingga UI, rule engine, dan kalibrasi dinamis tetap bisa
/// dijalankan serta diuji.
///
/// Yang disimulasikan bukan cuma angka hari ini, tapi juga 28 hari riwayat —
/// termasuk beberapa hari dingin di mana tubuh "bereaksi" — supaya baseline
/// personal dan pembelajaran ambang suhu punya bahan hitungan sejak siklus
/// pertama. Nilainya deterministik (Random dengan seed tetap).
class DemoHealthService implements HealthService {
  DemoHealthService({this.seed = 7, DateTime? sekarang})
    : _base = sekarang ?? DateTime.now();

  final int seed;
  final DateTime _base;

  static const int _hariRiwayat = 28;

  @override
  String get sourceLabel => 'Data simulasi';

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<SensorSnapshot> bacaSnapshot({
    Duration jendela = const Duration(hours: 24),
  }) async {
    final hari = _HariSimulasi(
      index: 0,
      seed: seed,
      tanggal: _base,
      dingin: false,
    );
    final akhir = _base;
    final awal = akhir.subtract(jendela);

    // Runtunan pembacaan SpO2: satu episode turun di tengah jendela supaya
    // konfirmasi otomatis ("berapa pembacaan beruntun") bisa teruji.
    final readings = hari.spo2Runtunan;

    return SensorSnapshot(
      at: akhir,
      heartRate: HeartRateSummary(
        minBpm: (hari.hrIstirahat - 6).round(),
        maxBpm: (hari.hrIstirahat + 34).round(),
        avgBpm: (hari.hrIstirahat + 12).round(),
        latestBpm: (hari.hrIstirahat + 9).round(),
        sampleCount: hari.jumlahSampel,
        windowStart: awal,
        windowEnd: akhir,
      ),
      restingHeartRate: RestingHeartRateSummary(
        bpm: hari.hrIstirahat,
        sampleCount: 1,
        at: akhir,
      ),
      hrv: HrvSummary(
        latestMs: hari.hrv,
        avgMs: hari.hrv * 1.04,
        minMs: hari.hrv * 0.72,
        sampleCount: hari.jumlahSampel,
      ),
      spo2: Spo2Summary(
        latestPct: readings.last,
        minPct: readings.reduce(math.min),
        avgPct: readings.fold<double>(0, (a, b) => a + b) / readings.length,
        readings: List<double>.unmodifiable(readings),
      ),
      respRate: RespRateSummary(
        latestPerMenit: hari.lajuNapas,
        avgPerMenit: hari.lajuNapas * 0.94,
        maxPerMenit: hari.lajuNapas * 1.22,
        sampleCount: hari.jumlahSampel,
      ),
      sleep: SleepSummary(
        startTime: akhir.subtract(const Duration(hours: 20)),
        endTime: akhir.subtract(const Duration(hours: 12)),
        totalSleepMinutes: hari.tidurMenit,
        inBedMinutes: hari.tidurMenit + hari.wasoMenit + 12,
        wasoMinutes: hari.wasoMenit,
        remMinutes: (hari.tidurMenit * 0.21).round(),
        deepMinutes: (hari.tidurMenit * 0.16).round(),
      ),
      activity: ActivitySummary(
        exerciseMinutes: hari.olahragaMenit,
        steps: (6000 + hari.olahragaMenit * 120).round(),
        sessionCount: hari.olahragaMenit > 0 ? 1 : 0,
      ),
      cycle: hari.siklus,
      cuaca: WeatherForecast(
        temperature: hari.suhu,
        humidity: hari.kelembapan,
        weatherDesc: 'Berawan',
        localDatetime: hari.tanggalLabel,
        windSpeedMs: hari.angin,
        windDirection: '240',
        latitude: -8.4041531021,
        longitude: 114.170236537,
      ),
    );
  }

  /// 28 hari riwayat sintetis: 27 hari lampau sampai kemarin.
  @override
  Future<List<HealthSample>> benihRiwayat() async => [
    for (var index = _hariRiwayat - 1; index >= 1; index--)
      _HariSimulasi(
        index: index,
        seed: seed,
        tanggal: _base.subtract(Duration(days: index)),
        dingin: _dinginSimulasi[index] ?? false,
      ).sampel(),
  ];

  /// Hari-hari yang dibuat dingin agar ambang personal bisa dipelajari.
  static const Map<int, bool> _dinginSimulasi = {19: true, 12: true, 5: true};
}

/// Satu hari data simulasi: angka fisiologis + lingkungan yang saling konsisten.
class _HariSimulasi {
  _HariSimulasi({
    required this.index,
    required this.seed,
    required this.tanggal,
    required this.dingin,
  });

  final int index;
  final int seed;
  final DateTime tanggal;
  final bool dingin;

  late final math.Random _acak = math.Random(seed * 1000 + index);

  double _geser(double dasar, double amp) =>
      dasar + (_acak.nextDouble() - 0.5) * 2 * amp;

  /// Irama harian sederhana supaya baseline tidak terlihat datar.
  double _gelombang(double amp) =>
      amp * math.sin(index / 28 * 2 * math.pi + seed * 0.3);

  // Setiap metrik dihitung SATU kali. Getter yang menghitung ulang akan
  // memajukan RNG yang sama, sehingga satu hari bisa saling bertentangan
  // (misalnya rata-rata SpO2 lebih tinggi dari pembacaan tertingginya) dan
  // baseline personal yang dibangun darinya jadi tidak masuk akal.
  late final double hrIstirahat =
      (dingin ? 71.0 : 62.0) + _gelombang(2.2) + _geser(0, 1.6);

  late final double hrv =
      (dingin ? 31.0 : 44.0) - _gelombang(3.0) + _geser(0, 2.4);

  late final double lajuNapas = dingin ? 21.4 : _geser(15.6, 0.9);

  late final int tidurMenit = _geser(410, 32).round();

  late final int wasoMenit = _acak.nextInt(dingin ? 34 : 18) + 4;

  late final double olahragaMenit = _acak.nextInt(4) == 0
      ? 0
      : _geser(dingin ? 12 : 28, 12).clamp(0.0, 70.0);

  late final double suhu = dingin ? _geser(18.4, 1.2) : _geser(27.5, 2.6);

  late final double kelembapan = dingin ? _geser(46, 8) : _geser(72, 9);

  late final double angin = dingin ? _geser(6.2, 1.6) : _geser(2.4, 1.2);

  late final double pm25 = dingin ? _geser(21, 8) : _geser(33, 14);

  late final int jumlahSampel = 40 + _acak.nextInt(60);

  late final List<double> spo2Runtunan = _bacaSpo2();

  late final double spo2Rata =
      spo2Runtunan.fold<double>(0, (a, b) => a + b) / spo2Runtunan.length;

  late final CycleInfo siklus = CycleInfo(
    // Satu episode haid tiap ~28 hari, hari siklus diturunkan dari tanggal.
    cycleDay: (index % 28) + 1,
    cycleLengthDays: 28,
    source: 'simulasi menstrualFlowInstant',
  );

  List<double> _bacaSpo2() {
    final dasar = dingin ? 92.6 : 95.8;
    final n = 24 + _acak.nextInt(12);
    final readings = <double>[for (var i = 0; i < n; i++) _geser(dasar, 1.1)];
    if (dingin) {
      // Runtunan 3 pembacaan rendah: cukup untuk "terkonfirmasi" otomatis.
      for (var i = (n * 0.6).floor(), k = 0; k < 3; k++, i++) {
        readings[i] = 89.4 - k * 0.6;
      }
    }
    return readings.map((v) => v.clamp(80.0, 99.0)).toList();
  }

  String get tanggalLabel => HealthSample.formatTanggal(tanggal);

  HealthSample sampel() => HealthSample(
    at: tanggal,
    metrics: {
      'resting_hr': hrIstirahat,
      'hrv_rmssd': hrv,
      'spo2': spo2Rata,
      'resp_rate': lajuNapas,
      'tidur_menit': tidurMenit.toDouble(),
      'tidur_efisiensi': tidurMenit / (tidurMenit + wasoMenit + 12) * 100,
      'suhu_ambient': suhu,
      'angin_ms': angin,
      'pm25': pm25,
      'hr_avg': hrIstirahat + 12,
      'olahraga_menit': olahragaMenit,
    },
  );
}

HealthService createHealthService() => DemoHealthService();
