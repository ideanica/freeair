/// Template kalimat pemicu dari rule engine, dua bahasa.
///
/// Yang disimpan ke database adalah kode + angka (lihat lib/models/pemicu.dart);
/// file ini yang merakit kalimatnya saat ditampilkan. Versi `id` harus identik
/// persis dengan kalimat yang dipakai rule engine sebelum ada i18n, karena
/// angka klinisnya (SpO2, °C, m/s, bpm) sudah diformat di engine dan hanya
/// disisipkan ke `{...}`.
const Map<String, String> idEngine = {
  // Status konfirmasi beruntun — dipakai bersarang oleh kalimat SpO2.
  'pemicu.status.beruntun': '{n} pembacaan beruntun',
  'pemicu.status.belum': 'belum terkonfirmasi',

  // Oksigen.
  'pemicu.spo2.hipoksemia': 'SpO2 {spo2}% — hipoksemia ({status})',
  'pemicu.spo2.ringan': 'SpO2 {spo2}% — hipoksemia ringan ({status})',
  'pemicu.spo2.borderline': 'SpO2 {spo2}% — borderline rendah',
  'pemicu.spo2.desaturasi_personal':
      'SpO2 turun {drop} poin dari baseline {baseline}% (ambang {ambang})',

  // Napas.
  'pemicu.rr.takipnea': 'Laju napas {rr} x/mnt — takipnea',
  'pemicu.rr.di_atas_normal': 'Laju napas {rr} x/mnt — di atas normal',

  // Tidur.
  'pemicu.tidur.durasi': 'Tidur {jam} jam (< {ambang} jam)',
  'pemicu.tidur.efisiensi': 'Efisiensi tidur {eff}% (< {ambang}%)',
  'pemicu.tidur.waso':
      'Terbangun {waso} menit setelah tidur mulai (>= {ambang})',

  // Udara.
  'pemicu.pm25.bahaya': 'PM2.5 {pm} µg/m³ — berbahaya',
  'pemicu.pm25.sensitif':
      'PM2.5 {pm} µg/m³ — tidak sehat untuk kelompok sensitif',
  'pemicu.pm25.who': 'PM2.5 {pm} µg/m³ — di atas panduan WHO 2021',

  // HRV dan detak jantung.
  'pemicu.hrv.deviasi_perhatian':
      'HRV {hrv} ms — turun {pct}% dari baseline {baseline} ms',
  'pemicu.hrv.deviasi_waspada': 'HRV {hrv} ms — turun {pct}% dari baseline',
  'pemicu.hrv.floor': 'HRV {hrv} ms — di bawah batas {ambang} ms literatur',
  'pemicu.hr.berat': 'HR {hr} bpm — takikardia berat',
  'pemicu.hr.takikardia': 'HR {hr} bpm — takikardia',
  'pemicu.hr.deviasi_bahaya':
      'HR {hr} bpm — {delta} bpm di atas baseline {baseline} bpm',
  'pemicu.hr.deviasi_waspada': 'HR {hr} bpm — {delta} bpm di atas baseline',

  // Aktivitas dan fase siklus.
  'pemicu.olahraga.protektif':
      'Olahraga {menit} mnt — protektif untuk kecemasan',
  'pemicu.olahraga.minim': 'Aktivitas fisik minim',
  'pemicu.olahraga.bronkokonstriksi':
      'Olahraga {menit} mnt — risiko bronkokonstriksi akibat olahraga',
  'pemicu.fase.luteal_bronk': 'Fase luteal — sesak bisa memberat',
  'pemicu.fase.luteal_anxiety': 'Fase luteal — progesteron pro-kecemasan',
  'pemicu.fase.luteal_dingin':
      'Fase luteal — sensitivitas dingin bisa meningkat',
  'pemicu.fase.menstruasi': 'Fase menstruasi',

  // Suhu lingkungan, termasuk asal ambang yang disisipkan bersarang.
  'pemicu.dingin.tidak_ada_suhu': 'Data suhu lingkungan tidak tersedia',
  'pemicu.ambang.personal': 'ambang personal {v}°C ({n} reaksi tercatat)',
  'pemicu.ambang.sebagian': 'ambang campuran {v}°C ({n} reaksi)',
  'pemicu.ambang.literatur': 'band literatur {v}°C',
  'pemicu.dingin.sangat':
      'Suhu {suhu}°C — sangat dingin, {delta}°C di bawah {sumber}',
  'pemicu.dingin.dingin': 'Suhu {suhu}°C — dingin, di bawah {sumber}',
  'pemicu.dingin.mendekati': 'Suhu {suhu}°C — mendekati {sumber}',
  'pemicu.dingin.drop_bahaya':
      'Suhu turun {drop}°C dari baseline {baseline}°C — perubahan mendadak',
  'pemicu.dingin.drop_waspada': 'Suhu turun {drop}°C dari baseline pribadi',
  'pemicu.rh.sangat_kering':
      'Udara sangat kering ({rh}% RH) — memperberat iritasi saluran napas',
  'pemicu.rh.kering': 'Udara kering ({rh}% RH)',
  'pemicu.angin.bahaya':
      'Angin {angin} m/s — paparan dingin lebih cepat terasa',
  'pemicu.angin.waspada': 'Angin {angin} m/s',

  'pemicu.tidak_dikenal': 'Pemicu tidak dikenal',
};

const Map<String, String> enEngine = {
  'pemicu.status.beruntun': '{n} readings in a row',
  'pemicu.status.belum': 'not yet confirmed',

  'pemicu.spo2.hipoksemia': 'SpO2 {spo2}% — hypoxaemia ({status})',
  'pemicu.spo2.ringan': 'SpO2 {spo2}% — mild hypoxaemia ({status})',
  'pemicu.spo2.borderline': 'SpO2 {spo2}% — borderline low',
  'pemicu.spo2.desaturasi_personal': 'SpO2 dropped {drop} points from baseline {baseline}% (threshold {ambang})',

  'pemicu.rr.takipnea': 'Respiratory rate {rr} /min — tachypnoea',
  'pemicu.rr.di_atas_normal': 'Respiratory rate {rr} /min — above normal',

  'pemicu.tidur.durasi': 'Sleep {jam} h (< {ambang} h)',
  'pemicu.tidur.efisiensi': 'Sleep efficiency {eff}% (< {ambang}%)',
  'pemicu.tidur.waso': 'Awake {waso} min after sleep onset (>= {ambang})',

  'pemicu.pm25.bahaya': 'PM2.5 {pm} µg/m³ — hazardous',
  'pemicu.pm25.sensitif': 'PM2.5 {pm} µg/m³ — unhealthy for sensitive groups',
  'pemicu.pm25.who': 'PM2.5 {pm} µg/m³ — above the 2021 WHO guideline',

  'pemicu.hrv.deviasi_perhatian':
      'HRV {hrv} ms — down {pct}% from baseline {baseline} ms',
  'pemicu.hrv.deviasi_waspada': 'HRV {hrv} ms — down {pct}% from baseline',
  'pemicu.hrv.floor': 'HRV {hrv} ms — below the {ambang} ms literature floor',
  'pemicu.hr.berat': 'HR {hr} bpm — severe tachycardia',
  'pemicu.hr.takikardia': 'HR {hr} bpm — tachycardia',
  'pemicu.hr.deviasi_bahaya':
      'HR {hr} bpm — {delta} bpm above baseline {baseline} bpm',
  'pemicu.hr.deviasi_waspada': 'HR {hr} bpm — {delta} bpm above baseline',

  'pemicu.olahraga.protektif': 'Exercise {menit} min — protective for anxiety',
  'pemicu.olahraga.minim': 'Minimal physical activity',
  'pemicu.olahraga.bronkokonstriksi':
      'Exercise {menit} min — risk of exercise-induced bronchoconstriction',
  'pemicu.fase.luteal_bronk': 'Luteal phase — breathlessness can worsen',
  'pemicu.fase.luteal_anxiety': 'Luteal phase — progesterone is pro-anxiety',
  'pemicu.fase.luteal_dingin': 'Luteal phase — cold sensitivity can increase',
  'pemicu.fase.menstruasi': 'Menstrual phase',

  'pemicu.dingin.tidak_ada_suhu': 'No ambient temperature data',
  'pemicu.ambang.personal': 'personal threshold {v}°C ({n} recorded reactions)',
  'pemicu.ambang.sebagian': 'mixed threshold {v}°C ({n} reactions)',
  'pemicu.ambang.literatur': 'literature band {v}°C',
  'pemicu.dingin.sangat':
      'Temperature {suhu}°C — very cold, {delta}°C below {sumber}',
  'pemicu.dingin.dingin': 'Temperature {suhu}°C — cold, below {sumber}',
  'pemicu.dingin.mendekati': 'Temperature {suhu}°C — approaching {sumber}',
  'pemicu.dingin.drop_bahaya':
      'Temperature fell {drop}°C from baseline {baseline}°C — sudden change',
  'pemicu.dingin.drop_waspada':
      'Temperature fell {drop}°C from personal baseline',
  'pemicu.rh.sangat_kering':
      'Air very dry ({rh}% RH) — worsens airway irritation',
  'pemicu.rh.kering': 'Dry air ({rh}% RH)',
  'pemicu.angin.bahaya': 'Wind {angin} m/s — cold is felt faster',
  'pemicu.angin.waspada': 'Wind {angin} m/s',

  'pemicu.tidak_dikenal': 'Unknown trigger',
};
