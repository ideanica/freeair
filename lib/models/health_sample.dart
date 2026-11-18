/// Satu baris sampel siklus: nilai metrik mentah pada satu waktu.
///
/// Inilah bahan bakar kalibrasi dinamis — baseline personal, ambang desaturasi
/// relatif, dan ambang suhu dingin semuanya dihitung dari baris-baris ini,
/// bukan dari angka yang diketik pengguna.
class HealthSample {
  const HealthSample({
    required this.at,
    required this.metrics,
    this.levelTertinggi,
  });

  final DateTime at;

  /// Kunci metrik sesuai `dinamis.metrik` di rule_config.json.
  final Map<String, double> metrics;

  /// Level hasil siklus ini; dipakai untuk mengecualikan hari sakit dari
  /// perhitungan baseline (baseline tidak boleh tercemar episode).
  final String? levelTertinggi;

  String get tanggal => formatTanggal(at);

  static String formatTanggal(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, Object?> toRow() => {
    'timestamp': at.millisecondsSinceEpoch,
    'tanggal': tanggal,
    'metrik': metrics.map((k, v) => MapEntry(k, v)),
    'level': levelTertinggi,
  };

  factory HealthSample.fromRow(Map<String, Object?> row) {
    final raw = row['metrik'];
    Map<String, double> metrik = const {};
    if (raw is Map) {
      metrik = {
        for (final e in raw.entries)
          if (e.value is num) e.key.toString(): (e.value as num).toDouble(),
      };
    }
    return HealthSample(
      at: DateTime.fromMillisecondsSinceEpoch(
        (row['timestamp'] as num?)?.toInt() ?? 0,
      ),
      metrics: metrik,
      levelTertinggi: row['level'] as String?,
    );
  }

  double? nilai(String key) => metrics[key];
}
