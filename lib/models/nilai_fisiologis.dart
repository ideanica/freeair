/// Normalisasi angka persentase dari sumber yang berbeda-beda.
///
/// Health Connect menyimpan SpO2 sebagai 0–100, sementara sebagian plugin
/// dan versi lama mengirim desimal 0–1 atau bahkan sudah dikali 100 dua kali
/// (96% menjadi 9600). Semua bentuk itu harus mendarat di angka yang sama
/// sebelum masuk rule engine, riwayat, maupun layar.
///
/// Nilai yang tetap tidak masuk akal setelah normalisasi (di bawah 50% atau
/// di atas 100%) dianggap rusak dan dibuang, bukan ditampilkan sebagai angka
/// klinis palsu.
double? normalisasiPersen(num? mentah) {
  if (mentah == null) return null;
  final angka = mentah.toDouble();
  if (!angka.isFinite) return null;

  var nilai = angka;
  if (nilai > 100 && nilai <= 10000) {
    // 9600 → 96, 960 → 9.6 (nanti ditolak karena di bawah 50).
    nilai /= 100;
  } else if (nilai > 0 && nilai <= 1.05) {
    // 0.96 → 96.
    nilai *= 100;
  }

  if (nilai < 50 || nilai > 100) return null;
  return nilai;
}

/// Format persen tanpa desimal yang tidak perlu: 96.0 → "96", 96.4 → "96.4".
String formatPersen(num? nilai, {int desimal = 1}) {
  if (nilai == null) return '—';
  final angka = nilai.toDouble();
  if (!angka.isFinite) return '—';
  final bulat = angka == angka.roundToDouble();
  return angka.toStringAsFixed(bulat ? 0 : desimal);
}
