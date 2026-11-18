/// Teks layar sumber. Kunci diawali `sumber.`.
///
/// Judul artikel, nama penulis, dan kutipan jurnal sengaja TIDAK ada di
/// kamus: itu nama diri yang memang sama di semua bahasa. Yang diterjemahkan
/// di sini hanya chrome layar dan label jenis rujukan.
const Map<String, String> idSources = {
  'sumber.judul': 'Sumber & Rujukan',
  'sumber.tooltip_semua': 'Tampilkan semua rujukan',
  'sumber.pengantar':
      'Setiap ambang di aplikasi ini berpijak pada satu rujukan: '
      'pedoman klinis, jurnal, standar alat, atau sumber data. '
      'Angka personalmu dihitung dari riwayat sensor — tapi batas '
      'di mana riwayat itu dianggap menyimpang tetap berasal dari '
      'daftar di bawah. Ketuk satu baris untuk membuka halaman '
      'aslinya.',
  'sumber.kosong_judul': 'Belum ada daftar rujukan',
  'sumber.kosong_pesan':
      'Blok "sumber_riset" belum ada di rule_config.json, jadi '
      'tidak ada rujukan yang bisa ditampilkan.',
  'sumber.ringkasan_judul': 'Dari mana angka ini datang',
  'sumber.n_rujukan': '{n} rujukan',
  'sumber.label_rujukan': 'rujukan',
  'sumber.label_topik': 'topik klinis',
  'sumber.label_perlu_cek': 'perlu dicek manual',
  'sumber.filter_judul': 'SARING BERDASARKAN JENIS',
  'sumber.filter_semua': 'Semua',
  'sumber.filter_catatan':
      '{n} entri ditandai perlu dicek manual — penerbitnya '
      'menolak pembacaan otomatis, bukan berarti tautannya mati.',
  'sumber.filter_kosong_judul': 'Tidak ada rujukan tipe ini',
  'sumber.filter_kosong_pesan':
      'Pilih tipe lain, atau hapus filter untuk melihat '
      'semua {n} rujukan.',
  'sumber.verifikasi_judul': 'Catatan verifikasi',
  'sumber.verifikasi_default':
      'Semua tautan di daftar ini dibuka dan dicocokkan '
      'dengan isinya sebelum ditampilkan.',
  'sumber.gagal_buka': 'Tautan tidak bisa dibuka: {url}',
  'sumber.status_perlu_cek': 'tautan perlu dicek di browser',
  'sumber.status_tidak_ditemukan':
      'rujukan tidak ditemukan — dipakai sebagai konvensi',

  // Label jenis rujukan; kunci datanya tetap `jurnal`, `pedoman`, dst.
  'sumber.tipe_jurnal': 'jurnal',
  'sumber.tipe_pedoman': 'pedoman',
  'sumber.tipe_standar': 'standar',
  'sumber.tipe_buku': 'buku',
  'sumber.tipe_api': 'api',
  'sumber.tipe_dataset': 'dataset',
  'sumber.tipe_paket': 'paket',
  'sumber.tipe_web': 'web',
};

/// Padanan English layar sumber.
const Map<String, String> enSources = {
  'sumber.judul': 'Sources & references',
  'sumber.tooltip_semua': 'Show all references',
  'sumber.pengantar':
      'Every threshold in this app rests on one reference: a clinical '
      'guideline, a journal, an instrument standard, or a data source. '
      'Your personal figures come from your sensor history, but the '
      'line where history counts as abnormal still comes from the list '
      'below. Tap a row to open the original page.',
  'sumber.kosong_judul': 'No reference list yet',
  'sumber.kosong_pesan':
      'The "sumber_riset" block is missing from rule_config.json, so '
      'there is nothing to display.',
  'sumber.ringkasan_judul': 'Where these numbers come from',
  'sumber.n_rujukan': '{n} references',
  'sumber.label_rujukan': 'references',
  'sumber.label_topik': 'clinical topics',
  'sumber.label_perlu_cek': 'to verify manually',
  'sumber.filter_judul': 'FILTER BY TYPE',
  'sumber.filter_semua': 'All',
  'sumber.filter_catatan':
      '{n} entries are marked for manual checking. The publisher '
      'blocks automated reading, which does not mean the link is dead.',
  'sumber.filter_kosong_judul': 'No references of this type',
  'sumber.filter_kosong_pesan':
      'Pick another type, or clear the filter to see '
      'all {n} references.',
  'sumber.verifikasi_judul': 'Verification note',
  'sumber.verifikasi_default':
      'Every link in this list was opened and matched against its '
      'contents before being shown.',
  'sumber.gagal_buka': 'Could not open the link: {url}',
  'sumber.status_perlu_cek': 'link needs checking in a browser',
  'sumber.status_tidak_ditemukan': 'reference not found — used as a convention',

  'sumber.tipe_jurnal': 'journal',
  'sumber.tipe_pedoman': 'guideline',
  'sumber.tipe_standar': 'standard',
  'sumber.tipe_buku': 'book',
  'sumber.tipe_api': 'API',
  'sumber.tipe_dataset': 'dataset',
  'sumber.tipe_paket': 'package',
  'sumber.tipe_web': 'web',
};
