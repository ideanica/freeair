# FreeAir

Aplikasi pemantau kualitas udara (Air Quality) dan kesehatan pribadi yang ramah
pengguna, dibangun dengan Flutter. Desain mengikuti sistem desain **Just Breathe**
dari Google Stitch: glassmorphism lembut, gradien langit, tombol pil, dan navigasi
bawah mengambang dengan orb napas di tengah.

## Fitur

- **Beranda**: AQI hero, status udara, mini stat (PM2.5, PM10, VOC), banner
  alert kesehatan, kebiasaan napas.
- **Alerts (Riwayat)**: daftar pemeriksaan per tanggal, filter, ringkasan, detail
  pemicu & audit.
- **Napas**: latihan napas terpandu (4-7-8, Box, Pursed) dengan orb animasi.
- **Statistik**: tren 7 hari kapsul, distribusi level, per kondisi, metrik mingguan.
- **Profil**: nama pengguna, kondisi yang dipantau, kode wilayah BMKG, bahasa &
  tema, izin sensor, kalibrasi ambang.

## Struktur

```
lib/
  main.dart
  screens/      # home, alerts, breathe, stats, profile, sources
  widgets/jb.dart
  services/     # weather, health, rule engine, database
  models/
  l10n/
```

## Menjalankan

```bash
flutter pub get
flutter run
```

## Build

```bash
flutter build apk          # Android
flutter build ios          # iOS
flutter build web          # Web
```

## Screenshot

Tambahkan tangkapan layar aplikasi ke folder `screenshots/` dan referensikan di
sini, misalnya:

![Beranda](screenshots/home.png)
![Alerts](screenshots/alerts.png)
![Statistik](screenshots/stats.png)
![Profil](screenshots/profile.png)

## Lisensi

Proyek pribadi.