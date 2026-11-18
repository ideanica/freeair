import 'air_quality.dart';
import 'health_data.dart';
import 'weather_forecast.dart';

/// Semua data yang terkumpul otomatis pada satu siklus pemeriksaan.
///
/// Tidak ada satu pun field yang diisi pengguna: sensor dari Health Connect,
/// lingkungan dari BMKG, kualitas udara dari Open-Meteo. Yang tidak tersedia
/// bernilai `null` dan rule engine wajib menanganinya.
class SensorSnapshot {
  const SensorSnapshot({
    required this.at,
    this.heartRate,
    this.restingHeartRate,
    this.hrv,
    this.spo2,
    this.respRate,
    this.sleep,
    this.activity,
    this.cycle = const CycleInfo(),
    this.cuaca,
    this.udara,
    this.jumlahRecord = const {},
    this.statusSinyal = const {},
  });

  final DateTime at;
  final HeartRateSummary? heartRate;
  final RestingHeartRateSummary? restingHeartRate;
  final HrvSummary? hrv;
  final Spo2Summary? spo2;
  final RespRateSummary? respRate;
  final SleepSummary? sleep;
  final ActivitySummary? activity;
  final CycleInfo cycle;
  final WeatherForecast? cuaca;
  final AirQuality? udara;

  /// Berapa record yang sungguh-sungguh terbaca per sinyal pada siklus ini.
  ///
  /// Kuncinya sama dengan nama metrik di [metrikSampel]. Nol berarti sumber
  /// datanya (jam atau HP) tidak mengirim record itu sama sekali — bukan
  /// aplikasi yang gagal membacanya. Kunci yang tidak ada di peta ini berarti
  /// platform tidak tahu (mis. data simulasi), jadi UI tidak boleh menyebut
  /// angka.
  final Map<String, int> jumlahRecord;

  /// Status pembacaan per sinyal: `ok`, `kosong`, `izin`, `gagal`, atau
  /// `tidak_diketahui`.
  ///
  /// [jumlahRecord] hanya bisa membedakan "ada data" dan "nol record". Peta
  /// ini membedakan izin yang ditolak dari jam yang memang tidak mengirim
  /// data, supaya layar bisa memberi tindakan yang tepat alih-alih menulis
  /// "0" tanpa penjelasan.
  final Map<String, String> statusSinyal;

  /// Layanan kesehatan hanya mengisi sinyal fisiologis; cuaca dan kualitas
  /// udara ditambahkan orchestrator setelah kedua sumber itu selesai.
  SensorSnapshot copyWith({WeatherForecast? cuaca, AirQuality? udara}) =>
      SensorSnapshot(
        at: at,
        heartRate: heartRate,
        restingHeartRate: restingHeartRate,
        hrv: hrv,
        spo2: spo2,
        respRate: respRate,
        sleep: sleep,
        activity: activity,
        cycle: cycle,
        cuaca: cuaca ?? this.cuaca,
        udara: udara ?? this.udara,
        jumlahRecord: jumlahRecord,
        statusSinyal: statusSinyal,
      );

  /// Jumlah record untuk satu sinyal, atau `null` bila platform tidak tahu.
  int? jumlah(String kunci) => jumlahRecord[kunci];

  /// Status pembacaan satu sinyal. Jatuh ke jumlah record bila peta status
  /// tidak diisi (mis. data simulasi yang tidak perlu membedakan izin).
  String status(String kunci) {
    final status = statusSinyal[kunci];
    if (status != null) return status;
    final n = jumlah(kunci);
    if (n == null) return 'tidak_diketahui';
    return n > 0 ? 'ok' : 'kosong';
  }

  double? get suhu => cuaca?.temperature;
  double? get kelembapan => cuaca?.humidity;
  double? get angin => cuaca?.windSpeedMs;
  double? get pm25 => udara?.pm25;

  /// Sinyal fisiologis yang benar-benar terisi; dipakai untuk keyakinan data.
  int get jumlahSinyal {
    var n = 0;
    for (final tersedia in [
      heartRate != null,
      restingHeartRate != null,
      hrv != null,
      spo2 != null,
      respRate != null,
      sleep != null,
      activity != null,
      cycle.tersedia,
    ]) {
      if (tersedia) n++;
    }
    return n;
  }

  String get confidence {
    final n = jumlahSinyal;
    if (n >= 5) return 'HIGH';
    if (n >= 3) return 'MEDIUM';
    return 'LOW';
  }

  /// Nilai metrik harian yang disimpan ke penyimpanan sampel untuk dihitung
  /// sebagai baseline personal pada siklus berikutnya.
  Map<String, double> get metrikSampel {
    final m = <String, double>{};
    final rhr = restingHeartRate;
    if (rhr != null) m['resting_hr'] = rhr.bpm;
    final h = hrv;
    if (h != null) m['hrv_rmssd'] = h.avgMs;
    final s = spo2;
    if (s != null) m['spo2'] = s.avgPct;
    final rr = respRate;
    if (rr != null) m['resp_rate'] = rr.avgPerMenit;
    final t = sleep;
    if (t != null) {
      m['tidur_menit'] = t.durationMinutes.toDouble();
      final e = t.efficiencyPct;
      if (e != null) m['tidur_efisiensi'] = e;
    }
    final suhu = this.suhu;
    if (suhu != null) m['suhu_ambient'] = suhu;
    final angin = this.angin;
    if (angin != null) m['angin_ms'] = angin;
    final pm = pm25;
    if (pm != null) m['pm25'] = pm;
    final hr = heartRate;
    if (hr != null) m['hr_avg'] = hr.avgBpm.toDouble();
    final olahraga = activity;
    if (olahraga != null) m['olahraga_menit'] = olahraga.exerciseMinutes;
    return m;
  }

  /// Sumber data untuk UI: apa yang aktif pada siklus ini.
  List<String> get sumberAktif => [
    if (heartRate != null) 'Detak jantung',
    if (restingHeartRate != null) 'RHR',
    if (hrv != null) 'HRV',
    if (spo2 != null) 'SpO2',
    if (respRate != null) 'Laju napas',
    if (sleep != null) 'Tidur',
    if (activity != null) 'Aktivitas',
    if (cycle.tersedia) 'Siklus',
    if (cuaca != null) 'BMKG',
    if (udara != null) 'PM2.5',
  ];
}
