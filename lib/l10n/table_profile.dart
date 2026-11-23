/// Teks layar profil. Kunci diawali `profil.`.
const Map<String, String> idProfile = {
  'profil.judul': 'Profil & Kalibrasi',
  'profil.simpan': 'Simpan Profil',
  'profil.reset': 'Pakai bawaan rule_config.json',
  'profil.error_kondisi': 'Pilih minimal satu kondisi untuk dipantau.',
  'profil.error_wilayah': 'Kode wilayah BMKG tidak boleh kosong.',
  'profil.tersimpan': 'Profil disimpan dan dipakai di siklus berikutnya.',
  'profil.catatan_kunci':
      'Tidak ada ambang yang diisi manual. Halaman ini hanya '
      'memilih apa yang dipantau dan di mana kamu berada — '
      'sisanya dihitung dari sensor dan riwayatmu.',

  // Kartu Tampilan: bahasa dan tema dipilih di sini, langsung berlaku.
  'profil.tampilan_judul': 'Tampilan',
  'profil.tampilan_deskripsi':
      'Bahasa dan tema tersimpan di perangkat dan berlaku seketika. '
      'Angka klinis tidak ikut berubah.',
  'profil.bahasa': 'Bahasa',
  'profil.tema': 'Tema',
  'profil.tema_sistem': 'Ikuti sistem',
  'profil.tema_terang': 'Terang',
  'profil.tema_gelap': 'Gelap',

  'profil.kondisi_judul': 'Kondisi yang dipantau',
  'profil.kondisi_deskripsi':
      'Hanya tiga kondisi yang dimodelkan khusus untukmu. Sisanya '
      'tidak dinilai supaya tidak ada angka karangan.',
  'profil.nama': 'Nama',
  'profil.pilih_kondisi': 'Pilih kondisi',
  'profil.wilayah_label': 'Kode wilayah BMKG (adm4)',
  'profil.wilayah_helper':
      'Level kelurahan, 12 digit bertitik. '
      'Contoh 35.10.07.2008',
  'profil.wilayah_catatan':
      'Koordinat kualitas udara diambil otomatis dari respons BMKG '
      'wilayah ini — tidak perlu API key atau pengaturan tambahan.',

  'profil.sumber_judul': 'Sumber data otomatis',
  'profil.izin_judul': 'Izin {sumber}',
  'profil.izin_deskripsi':
      'HR, HR istirahat, HRV, SpO2, laju napas, '
      'tidur, olahraga, langkah, dan catatan '
      'siklus dibaca sendiri dari perangkat.',
  'profil.izin_diberikan':
      'Izin diberikan. Data sensor mulai terbaca pada siklus berikutnya.',
  'profil.izin_belum': 'Izin belum lengkap — kondisi yang datanya tidak tersedia tidak akan dinilai.',

  'profil.kalibrasi_judul': 'Kalibrasi',
  'profil.kalibrasi_kosong':
      'Belum ada siklus yang selesai — ambang akan muncul setelah '
      'data pertama terbaca.',
  'profil.ambang_judul': 'Ambang yang dipakai sekarang',
  'profil.ambang_deskripsi':
      'Nilai = angka literatur yang sudah dilebur dengan median '
      'riwayatmu. Warna di kanan menunjukkan sejauh mana angka '
      'itu sudah personal.',
  'profil.kecukupan_judul': 'Kecukupan data riwayat',
  'profil.kecukupan_catatan':
      'Hari dengan level PERHATIAN/BAHAYA otomatis dikeluarkan '
      'dari perhitungan baseline supaya episode sakit tidak '
      'menggeser angka normalmu.',
  'profil.sumber_angka_judul': 'Sumber angka (jurnal & panduan)',
  'profil.sumber_ajakan':
      'Daftar lengkap setiap rujukan, beserta tautan '
      'jurnal dan API-nya, ada di halaman Sumber & Rujukan.',
  'profil.disclaimer':
      'Semua angka ini divalidasi terhadap guideline, tapi aplikasi '
      'ini alat pantau pribadi — bukan pengganti diagnosis dokter.',

  'profil.kondisi_kartu_sub':
      'Pilih kondisi yang dipantau dan wilayah cuacamu.',
  'profil.tampilan_kartu_sub': 'Bahasa dan tema berlaku seketika.',
  'profil.sumber_kartu_sub': 'Jurnal, pedoman, dan API yang dipakai aplikasi.',
  'profil.izin_kartu_sub': 'Kelola izin baca sensor dari perangkat.',
  'profil.kalibrasi_kartu_sub':
      'Ketuk untuk melihat ambang, kecukupan data, dan sumber angka.',
  'profil.kalibrasi_sheet_sub':
      'Semua angka dihitung otomatis — tidak ada yang diketik manual.',
  'profil.ambang_n': '{n} ambang',
};

/// Padanan English layar profil.
const Map<String, String> enProfile = {
  'profil.judul': 'Profile & calibration',
  'profil.simpan': 'Save profile',
  'profil.reset': 'Use rule_config.json defaults',
  'profil.error_kondisi': 'Pick at least one condition to monitor.',
  'profil.error_wilayah': 'The BMKG region code cannot be empty.',
  'profil.tersimpan': 'Profile saved and used from the next cycle.',
  'profil.catatan_kunci':
      'No threshold is entered by hand. This page only '
      'chooses what is monitored and where you are; '
      'everything else is computed from your sensors and history.',

  'profil.tampilan_judul': 'Appearance',
  'profil.tampilan_deskripsi':
      'Language and theme are stored on the device and apply '
      'immediately. Clinical figures are not affected.',
  'profil.bahasa': 'Language',
  'profil.tema': 'Theme',
  'profil.tema_sistem': 'Follow system',
  'profil.tema_terang': 'Light',
  'profil.tema_gelap': 'Dark',

  'profil.kondisi_judul': 'Conditions monitored',
  'profil.kondisi_deskripsi':
      'Only three conditions are modelled specifically for you. '
      'Anything else is left unmeasured so no number is invented.',
  'profil.nama': 'Name',
  'profil.pilih_kondisi': 'Choose conditions',
  'profil.wilayah_label': 'BMKG region code (adm4)',
  'profil.wilayah_helper':
      'Sub-district level, 12 dotted digits. '
      'Example 35.10.07.2008',
  'profil.wilayah_catatan':
      'Air-quality coordinates are taken automatically from the BMKG '
      'response for this region, so no API key or extra setup is needed.',

  'profil.sumber_judul': 'Automatic data sources',
  'profil.izin_judul': '{sumber} permissions',
  'profil.izin_deskripsi':
      'HR, resting HR, HRV, SpO2, breathing rate, '
      'sleep, workouts, steps, and cycle notes are read '
      'straight from the device.',
  'profil.izin_diberikan':
      'Permissions granted. Sensor data starts being read on the next cycle.',
  'profil.izin_belum':
      'Permissions incomplete. Conditions without data will not be scored.',

  'profil.kalibrasi_judul': 'Calibration',
  'profil.kalibrasi_kosong':
      'No completed cycle yet. Thresholds appear once the '
      'first data is read.',
  'profil.ambang_judul': 'Thresholds in use now',
  'profil.ambang_deskripsi':
      'Value = the literature figure blended with the median '
      'of your history. The colour on the right shows how personal '
      'that number already is.',
  'profil.kecukupan_judul': 'History data sufficiency',
  'profil.kecukupan_catatan':
      'Days rated PERHATIAN/BAHAYA are excluded automatically '
      'from the baseline calculation so an illness episode does not '
      'shift your normal figures.',
  'profil.sumber_angka_judul': 'Where the numbers come from',
  'profil.sumber_ajakan':
      'The Sources & References page lists every reference in full, with its '
      'journal and API links.',
  'profil.disclaimer':
      'All of these figures are checked against guidelines, but this '
      'app is a personal monitoring tool, not a substitute for a '
      'doctor\'s diagnosis.',

  'profil.kondisi_kartu_sub':
      'Choose the conditions to monitor and your weather region.',
  'profil.tampilan_kartu_sub': 'Language and theme apply immediately.',
  'profil.sumber_kartu_sub': 'Journals, guidelines, and APIs used by the app.',
  'profil.izin_kartu_sub': 'Manage permission to read device sensors.',
  'profil.kalibrasi_kartu_sub': 'Tap to see thresholds, data sufficiency, and where the numbers come from.',
  'profil.kalibrasi_sheet_sub':
      'Every number is computed automatically — nothing is typed by hand.',
  'profil.ambang_n': '{n} thresholds',
};
