/// Ringkasan detak jantung pada satu jendela waktu.
class HeartRateSummary {
  const HeartRateSummary({
    required this.minBpm,
    required this.maxBpm,
    required this.avgBpm,
    required this.latestBpm,
    required this.sampleCount,
    required this.windowStart,
    required this.windowEnd,
  });

  final int minBpm;
  final int maxBpm;
  final int avgBpm;
  final int latestBpm;
  final int sampleCount;
  final DateTime windowStart;
  final DateTime windowEnd;
}

/// Detak jantung istirahat terbaru dari Health Connect.
class RestingHeartRateSummary {
  const RestingHeartRateSummary({
    required this.bpm,
    required this.sampleCount,
    this.at,
  });

  final double bpm;

  /// Jumlah catatan resting heart rate yang mendasari nilai ini.
  final int sampleCount;
  final DateTime? at;
}

/// HRV (RMSSD) pada jendela waktu, dalam milidetik.
class HrvSummary {
  const HrvSummary({
    required this.latestMs,
    required this.avgMs,
    required this.minMs,
    required this.sampleCount,
  });

  final double latestMs;
  final double avgMs;
  final double minMs;
  final int sampleCount;
}

/// Saturasi oksigen (SpO2) pada jendela waktu.
///
/// [readings] disimpan mentah agar konfirmasi "dua pembacaan beruntun" bisa
/// dihitung otomatis dari data, bukan dari centang manual.
class Spo2Summary {
  const Spo2Summary({
    required this.latestPct,
    required this.minPct,
    required this.avgPct,
    required this.readings,
  });

  final double latestPct;
  final double minPct;
  final double avgPct;

  /// Rangkaian nilai SpO2 kronologis (sudah dibatasi panjangnya).
  final List<double> readings;

  int get sampleCount => readings.length;

  /// Berapa pembacaan di bawah [ambang] — dipakai untuk memutuskan apakah
  /// hipoksemia "terkonfirmasi" (>= N pembacaan) atau perlu konfirmasi.
  int jumlahDiBawah(double ambang) => readings.where((v) => v < ambang).length;

  /// Runtunan pembacaan rendah terpanjang; meniru "2 pembacaan beruntun".
  int runtuhanTerpanjangDiBawah(double ambang) {
    var terbaik = 0;
    var berjalan = 0;
    for (final v in readings) {
      berjalan = v < ambang ? berjalan + 1 : 0;
      if (berjalan > terbaik) terbaik = berjalan;
    }
    return terbaik;
  }
}

/// Laju napas pada jendela waktu.
class RespRateSummary {
  const RespRateSummary({
    required this.latestPerMenit,
    required this.avgPerMenit,
    required this.maxPerMenit,
    required this.sampleCount,
  });

  final double latestPerMenit;
  final double avgPerMenit;
  final double maxPerMenit;
  final int sampleCount;
}

/// Ringkasan sesi tidur terakhir.
///
/// `quality` = durasi tidur dibagi 8 jam (480 menit), clamp 0..1 — sesuai
/// normalisasi di notebook model.
class SleepSummary {
  const SleepSummary({
    required this.startTime,
    required this.endTime,
    this.totalSleepMinutes,
    this.inBedMinutes,
    this.wasoMinutes,
    this.remMinutes,
    this.deepMinutes,
  });

  final DateTime startTime;
  final DateTime endTime;

  /// Total menit benar-benar tidur (semua stage selain awake/outOfBed/inBed).
  final int? totalSleepMinutes;

  /// Menit berada di tempat tidur, termasuk yang terbangun.
  final int? inBedMinutes;

  /// Menit terbangun setelah tidur mulai (wake after sleep onset).
  final int? wasoMinutes;
  final int? remMinutes;
  final int? deepMinutes;

  int get durationMinutes =>
      totalSleepMinutes ?? endTime.difference(startTime).inMinutes;

  double get quality {
    final raw = durationMinutes / 480.0;
    return raw.clamp(0.0, 1.0);
  }

  /// Efisiensi tidur = total tidur / waktu di tempat tidur (kriteria ICSD-3:
  /// <85% masuk batas insomnia).
  double? get efficiencyPct {
    final inBed = inBedMinutes;
    if (inBed == null || inBed <= 0) return null;
    return (durationMinutes / inBed * 100).clamp(0.0, 100.0);
  }

  double? get remFractionPct {
    final rem = remMinutes;
    final total = totalSleepMinutes;
    if (rem == null || total == null || total <= 0) return null;
    return (rem / total * 100).clamp(0.0, 100.0);
  }
}

/// Aktivitas fisik yang tercatat otomatis (exercise session + langkah).
class ActivitySummary {
  const ActivitySummary({
    required this.exerciseMinutes,
    this.steps,
    this.sessionCount = 0,
  });

  /// Menit sesi olahraga hari berjalan.
  final double exerciseMinutes;
  final int? steps;
  final int sessionCount;
}

/// Fase siklus yang diturunkan dari data Health Connect, bukan dari isian.
class CycleInfo {
  const CycleInfo({this.cycleDay, this.cycleLengthDays, this.source});

  final int? cycleDay;
  final double? cycleLengthDays;

  /// Dari mana angka ini berasal, mis. "menstrualFlowInstant (12 catatan)".
  final String? source;

  bool get tersedia => cycleDay != null;
}
