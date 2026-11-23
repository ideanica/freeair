/// Teks yang dipakai bersama di lebih dari satu layar: navigasi, level,
/// nama kondisi, kalibrasi, notifikasi, dan label sensor.
///
/// Nilai kunci data (AMAN/WASPADA/..., Bronkitis/Anxiety/Alergi Dingin,
/// personal/sebagian/literatur) sengaja tidak diterjemahkan — yang di bawah
/// ini hanya label yang dilihat pengguna.
const Map<String, String> idCore = {
  'nav.beranda': 'Beranda',
  'nav.profil': 'Profil',
  'nav.riwayat': 'Alerts',
  'nav.napas': 'Napas',
  'nav.statistik': 'Statistik',

  'level.aman': 'Semua sinyal masih di dalam batas normalmu',
  'level.waspada': 'Ada pemicu kecil — pantau 1-2 jam ke depan',
  'level.perhatian': 'Perlu tindakan sekarang, jangan ditunda',
  'level.bahaya': 'Kondisi berat — segera ambil tindakan',
  'level.tidak_dievaluasi': 'Data belum cukup, kondisi ini belum dinilai',

  'kondisi.bronkitis.subtitle': 'Napas & oksigen',
  'kondisi.anxiety.subtitle': 'Kecemasan & saraf',
  'kondisi.dingin.subtitle': 'Suhu lingkungan',
  'kondisi.bronkitis.pendek': 'Napas',
  'kondisi.anxiety.pendek': 'Cemas',
  'kondisi.dingin.pendek': 'Dingin',

  'umum.skor_dari': 'Skor {skor} dari 100',
  'umum.ambang_kalibrasi': 'ambang {kalibrasi}',
  'umum.jam': 'jam {waktu}',
  'umum.cek': '{jumlah} cek',
  'umum.tutup': 'Tutup',
  'umum.kembali': 'Kembali',
  'umum.simpan': 'Simpan',
  'umum.belum_ada': 'belum ada',
  'umum.skor_naik': 'YANG MEMBUAT SKOR NAIK',
  'umum.semua_normal': 'Semua normal',
  'umum.semua_normal_kapital': 'SEMUA NORMAL',
  'umum.saran_tindakan': 'Saran tindakan',
  'umum.keyakinan': 'Keyakinan data: {level}',
  'umum.belum_dicatat': 'belum tercatat',

  // Nilai tier dipakai apa adanya di database; hanya labelnya yang berubah.
  'kalibrasi.personal': 'personal',
  'kalibrasi.sebagian': 'sebagian',
  'kalibrasi.literatur': 'literatur',

  'label.napas': 'Napas',
  'label.tidur': 'Tidur',
  'label.suhu': 'Suhu',
  'label.angin': 'Angin',

  'sumber.simulasi': 'Data simulasi',

  'notif.nama_kanal': 'FreeAir',
  'notif.deskripsi_kanal': 'Peringatan kesehatan personal',
  'notif.judul': '⚠️ {kondisi} — {level}',
  'notif.pengingat_judul': 'Cek kesehatan berikutnya',
  'notif.pengingat_pesan': 'Jadwal pengecekan sudah lewat. Buka FreeAir untuk melihat kondisi terkini.',

  'sensor.jantung': 'Detak jantung',
  'sensor.napas': 'Laju napas',
  'sensor.tidur': 'Tidur',
  'sensor.aktivitas': 'Aktivitas',
  'sensor.siklus': 'Siklus',
  'sensor.oksigen': 'Oksimeter',
  'sensor.hrv': 'HRV',
  'sensor.cuaca': 'Cuaca',
  'sensor.udara': 'Kualitas udara',

  // Label sinyal yang diperiksa rule engine. Dipakai di daftar "kenapa skor
  // ini" pada detail kondisi.
  'periksa.spo2': 'SpO2 terendah',
  'periksa.laju_napas': 'Laju napas',
  'periksa.hr': 'Detak jantung',
  'periksa.hr_absolut': 'Detak jantung saat ini',
  'periksa.hrv': 'HRV (RMSSD)',
  'periksa.tidur_durasi': 'Durasi tidur',
  'periksa.tidur_efisiensi': 'Efisiensi tidur',
  'periksa.tidur_waso': 'Terbangun setelah tidur',
  'periksa.pm25': 'PM2.5',
  'periksa.kelembapan': 'Kelembapan udara',
  'periksa.angin': 'Kecepatan angin',
  'periksa.olahraga': 'Menit olahraga',
  'periksa.suhu': 'Suhu udara',
  'periksa.fase': 'Fase siklus',

  // Nilai fase dari rule engine (bukan kalimat).
  'fase.menstruasi': 'Menstruasi',
  'fase.folikular': 'Folikular',
  'fase.ovulasi': 'Ovulasi',
  'fase.luteal': 'Luteal',
  'fase.tidak_diketahui': 'Tidak diketahui',

  // Label satu baris untuk kartu "Ambang yang dipakai".
  'ambang.spo2': 'SpO2 hipoksemia',
  'ambang.desaturasi': 'Desaturasi relatif',
  'ambang.takipnea': 'Laju napas takipnea',
  'ambang.hr_delta': 'Kenaikan HR dari baseline',
  'ambang.hrv_drop': 'Penurunan HRV',
  'ambang.tidur_durasi': 'Durasi tidur minimum',
  'ambang.tidur_efisiensi': 'Efisiensi tidur minimum',
  'ambang.suhu_dingin': 'Ambang suhu dingin',
  'ambang.rh_kering': 'Udara kering',
  'ambang.angin': 'Kecepatan angin',
  'ambang.pm25': 'PM2.5',
  'ambang.siklus': 'Pergeseran fase siklus',

  'ambang.detail.spo2':
      'band absolut; status terkonfirmasi dihitung otomatis dari '
      'runtutan pembacaan sensor',
  'ambang.detail.desaturasi': 'dibanding median SpO2 pribadi ({k})',
  'ambang.detail.hr': 'baseline RHR pribadi {k}',
  'ambang.detail.hrv': 'baseline HRV pribadi {k}',
  'ambang.detail.efisiensi': 'median pribadi {k}',
  'ambang.detail.dingin_belum':
      'belum ada reaksi tercatat; memakai band literatur {m}°C',
  'ambang.detail.dingin_ada':
      'reaksi terpanas tercatat pada {m}°C ({n} kejadian)',
  'ambang.detail.siklus':
      'fase dihitung dari catatan menstruasi di Health Connect',

  // Piece kalimat yang dirujuk ulang lewat '@'.
  'baseline.keterangan': '{m}{satuan} dari {hari} hari',
  'baseline.tidak_ada': 'belum ada data',
  'baseline.kecukupan': '{label}: {hari}/{target} hari',

  // Nama tier yang tampil kapital di ringkasan status.
  'tier.literatur': 'LITERATUR',
  'tier.sebagian': 'SEBAGIAN',
  'tier.personal': 'PERSONAL',
};

const Map<String, String> enCore = {
  'nav.beranda': 'Home',
  'nav.profil': 'Profile',
  'nav.riwayat': 'Alerts',
  'nav.napas': 'Breathe',
  'nav.statistik': 'Statistics',

  'level.aman': 'Every signal is still inside your normal range',
  'level.waspada': 'Small trigger present — keep an eye on it for 1-2 hours',
  'level.perhatian': 'Act now, do not postpone',
  'level.bahaya': 'Severe state — take action immediately',
  'level.tidak_dievaluasi': 'Not enough data, this condition was not scored',

  'kondisi.bronkitis.subtitle': 'Breathing & oxygen',
  'kondisi.anxiety.subtitle': 'Anxiety & nervous system',
  'kondisi.dingin.subtitle': 'Outdoor temperature',
  'kondisi.bronkitis.pendek': 'Breath',
  'kondisi.anxiety.pendek': 'Anxiety',
  'kondisi.dingin.pendek': 'Cold',

  'umum.skor_dari': 'Score {skor} out of 100',
  'umum.ambang_kalibrasi': '{kalibrasi} threshold',
  'umum.jam': '{waktu}',
  'umum.cek': '{jumlah} checks',
  'umum.tutup': 'Close',
  'umum.kembali': 'Back',
  'umum.simpan': 'Save',
  'umum.belum_ada': 'no data',
  'umum.skor_naik': 'WHAT RAISED THE SCORE',
  'umum.semua_normal': 'All normal',
  'umum.semua_normal_kapital': 'ALL NORMAL',
  'umum.saran_tindakan': 'Suggested action',
  'umum.keyakinan': 'Data confidence: {level}',
  'umum.belum_dicatat': 'not recorded',

  'kalibrasi.personal': 'personal',
  'kalibrasi.sebagian': 'partial',
  'kalibrasi.literatur': 'literature',

  'label.napas': 'Breath',
  'label.tidur': 'Sleep',
  'label.suhu': 'Temp',
  'label.angin': 'Wind',

  'sumber.simulasi': 'Simulated data',

  'notif.nama_kanal': 'FreeAir',
  'notif.deskripsi_kanal': 'Personal health warnings',
  'notif.judul': '⚠️ {kondisi} — {level}',
  'notif.pengingat_judul': 'Next health check',
  'notif.pengingat_pesan':
      'The check window has passed. Open FreeAir to see your latest status.',

  'sensor.jantung': 'Heart rate',
  'sensor.napas': 'Breathing rate',
  'sensor.tidur': 'Sleep',
  'sensor.aktivitas': 'Activity',
  'sensor.siklus': 'Cycle',
  'sensor.oksigen': 'Oximeter',
  'sensor.hrv': 'HRV',
  'sensor.cuaca': 'Weather',
  'sensor.udara': 'Air quality',

  'periksa.spo2': 'Lowest SpO2',
  'periksa.laju_napas': 'Breathing rate',
  'periksa.hr': 'Heart rate',
  'periksa.hr_absolut': 'Current heart rate',
  'periksa.hrv': 'HRV (RMSSD)',
  'periksa.tidur_durasi': 'Sleep duration',
  'periksa.tidur_efisiensi': 'Sleep efficiency',
  'periksa.tidur_waso': 'Wake after sleep onset',
  'periksa.pm25': 'PM2.5',
  'periksa.kelembapan': 'Air humidity',
  'periksa.angin': 'Wind speed',
  'periksa.olahraga': 'Exercise minutes',
  'periksa.suhu': 'Air temperature',
  'periksa.fase': 'Cycle phase',

  'fase.menstruasi': 'Menstrual',
  'fase.folikular': 'Follicular',
  'fase.ovulasi': 'Ovulation',
  'fase.luteal': 'Luteal',
  'fase.tidak_diketahui': 'Unknown',

  'ambang.spo2': 'SpO2 hypoxaemia',
  'ambang.desaturasi': 'Relative desaturation',
  'ambang.takipnea': 'Tachypnoea rate',
  'ambang.hr_delta': 'HR rise above baseline',
  'ambang.hrv_drop': 'HRV drop',
  'ambang.tidur_durasi': 'Minimum sleep duration',
  'ambang.tidur_efisiensi': 'Minimum sleep efficiency',
  'ambang.suhu_dingin': 'Cold temperature threshold',
  'ambang.rh_kering': 'Dry air',
  'ambang.angin': 'Wind speed',
  'ambang.pm25': 'PM2.5',
  'ambang.siklus': 'Cycle phase shift',

  'ambang.detail.spo2':
      'absolute band; confirmed status is computed automatically from '
      'consecutive sensor readings',
  'ambang.detail.desaturasi': 'against your personal SpO2 median ({k})',
  'ambang.detail.hr': 'personal RHR baseline {k}',
  'ambang.detail.hrv': 'personal HRV baseline {k}',
  'ambang.detail.efisiensi': 'personal median {k}',
  'ambang.detail.dingin_belum':
      'no reaction recorded yet; using the literature band {m}°C',
  'ambang.detail.dingin_ada': 'warmest recorded reaction at {m}°C ({n} events)',
  'ambang.detail.siklus':
      'phase computed from menstrual records in Health Connect',

  'baseline.keterangan': '{m}{satuan} over {hari} days',
  'baseline.tidak_ada': 'no data yet',
  'baseline.kecukupan': '{label}: {hari}/{target} days',

  'tier.literatur': 'LITERATURE',
  'tier.sebagian': 'PARTIAL',
  'tier.personal': 'PERSONAL',
};
