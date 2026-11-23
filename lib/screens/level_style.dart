import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/condition_result.dart';

/// Palet terang dasar — angka aslinya dituliskan satu kali di sini.
///
/// Diambil dari design system Just Breathe (Stitch): biru langit `#1EB6F0`,
/// navy `#0F2A43`, dan latar es `#F4FAFF`. Warna level memakai nada yang lebih
/// dalam daripada pastel DESIGN.md supaya teks di atas putih tetap lolos
/// kontras 4.5:1; pastelnya dipakai sebagai bidang, bukan tinta.
class AppPalette {
  const AppPalette._();

  static const Color aksen = Color(0xFF1EB6F0);
  static const Color aksenDeep = Color(0xFF0877AE);
  static const Color aksenSoft = Color(0xFFCDEBFF);

  static const Color canvas = Color(0xFFF4FAFF);
  static const Color card = Colors.white;
  static const Color line = Color(0xFFD6E6F2);

  static const Color ink = Color(0xFF0F2A43);
  static const Color inkSoft = Color(0xFF5A6B82);

  static const Color aman = Color(0xFF2E9E63);
  static const Color waspada = Color(0xFFB07A00);
  static const Color perhatian = Color(0xFFC2620F);
  static const Color bahaya = Color(0xFFD93025);
  static const Color netral = Color(0xFF6B7A8C);
  static const Color mauve = Color(0xFF8B5CF6);

  /// Skala AQI persis DESIGN.md, dipakai untuk bar dan titik status.
  static const Color aqiGood = Color(0xFF3CCB7F);
  static const Color aqiModerate = Color(0xFFFFC94D);
  static const Color aqiSensitive = Color(0xFFFF9F43);
  static const Color aqiUnhealthy = Color(0xFFFF5C5C);
  static const Color aqiHazardous = Color(0xFFA56CF0);
}

/// Token warna yang dibaca dari tema aktif.
///
/// Layar mengambil warna lewat [AppTones.of] alih-alih menyebut `AppPalette`
/// langsung, supaya mode gelap cukup diganti di satu tempat. Nama fieldnya
/// sengaja sama dengan [AppPalette]: `tones.card`, `tones.line`, `tones.aman`.
class AppTones {
  const AppTones({
    required this.aksen,
    required this.aksenDeep,
    required this.aksenSoft,
    required this.canvas,
    required this.card,
    required this.line,
    required this.ink,
    required this.inkSoft,
    required this.aman,
    required this.waspada,
    required this.perhatian,
    required this.bahaya,
    required this.netral,
    required this.mauve,
    required this.onAksen,
    required this.panel,
    required this.sinyal,
    required this.bayangan,
    required this.shadowAlpha,
    required this.gradien,
    required this.gradasi,
  });

  static const AppTones terang = AppTones(
    aksen: AppPalette.aksen,
    aksenDeep: AppPalette.aksenDeep,
    aksenSoft: AppPalette.aksenSoft,
    canvas: AppPalette.canvas,
    card: AppPalette.card,
    line: AppPalette.line,
    ink: AppPalette.ink,
    inkSoft: AppPalette.inkSoft,
    aman: AppPalette.aman,
    waspada: AppPalette.waspada,
    perhatian: AppPalette.perhatian,
    bahaya: AppPalette.bahaya,
    netral: AppPalette.netral,
    mauve: AppPalette.mauve,
    onAksen: Colors.white,
    panel: Color(0xFFEAF4FC),
    sinyal: Color(0xFFFF9F43),
    bayangan: Color(0xFF0877AE),
    shadowAlpha: 0.10,
    gradien: [Color(0xFFE8F6FF), Color(0xFFF4FAFF)],
    gradasi: _gradasiTerang,
  );

  /// Malam di kota: navy dalam dengan aksen biru langit yang tetap lembut.
  static const AppTones gelap = AppTones(
    aksen: Color(0xFF4FC3F7),
    aksenDeep: Color(0xFF9AD9F5),
    aksenSoft: Color(0xFF10344A),
    canvas: Color(0xFF071C2C),
    card: Color(0xFF0F2A43),
    line: Color(0xFF1D3E55),
    ink: Color(0xFFE9F1FF),
    inkSoft: Color(0xFF9AB0C4),
    aman: Color(0xFF4FD08A),
    waspada: Color(0xFFFFD166),
    perhatian: Color(0xFFFFA45C),
    bahaya: Color(0xFFFF6B6B),
    netral: Color(0xFF93A5B8),
    mauve: Color(0xFFB794F6),
    onAksen: Color(0xFF04212F),
    panel: Color(0xFF0B2436),
    sinyal: Color(0xFFFF9F43),
    bayangan: Colors.black,
    shadowAlpha: 0.50,
    gradien: [Color(0xFF0B2A40), Color(0xFF071C2C)],
    gradasi: _gradasiGelap,
  );

  static AppTones of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? gelap : terang;

  final Color aksen;
  final Color aksenDeep;
  final Color aksenSoft;
  final Color canvas;
  final Color card;
  final Color line;
  final Color ink;
  final Color inkSoft;
  final Color aman;
  final Color waspada;
  final Color perhatian;
  final Color bahaya;
  final Color netral;

  /// Aksen kedua template (diamond navbar, highlight), bukan warna level.
  final Color mauve;

  /// Warna teks di atas tombol/chip beraksen.
  final Color onAksen;

  /// Bidang setingkat di bawah kartu: pil tab tidak aktif dan kontainer
  /// daftar (di template navy `#20222A`/`#181A1F`).
  final Color panel;

  /// Lencana jumlah, persis lingkaran peach `#FF9B76` di `DashboardNav`.
  final Color sinyal;

  /// Warna bayangan kartu. Di mode gelap ini hitam, bukan [ink]: teksnya
  /// terang, jadi bayangan yang ikut warna teks jadi halo.
  final Color bayangan;

  /// Opasitas bayangan kartu; di latar gelap bayangan nyaris tak terlihat
  /// sehingga nilainya dinaikkan.
  final double shadowAlpha;

  /// Dua warna latar layar: radial dari sudut kiri atas ke [canvas].
  final List<Color> gradien;

  /// Gradien pastel per level untuk kartu menonjol, ditiru dari
  /// `progressCardGradientList` template.
  final Map<String, List<Color>> gradasi;

  /// Teks di atas kartu bergradien pastel: selalu navy, di mode apa pun,
  /// karena pastelnya terang di kedua tema.
  static const Color onGradien = Color(0xFF0F2A43);

  static const Map<String, List<Color>> _gradasiTerang = {
    AlertLevels.aman: [Color(0xFFD6F7E4), Color(0xFF9BE8BC)],
    AlertLevels.waspada: [Color(0xFFFFF0CC), Color(0xFFFFD98A)],
    AlertLevels.perhatian: [Color(0xFFFFE3D1), Color(0xFFFFB98C)],
    AlertLevels.bahaya: [Color(0xFFFFDCDC), Color(0xFFFFA3A3)],
    AlertLevels.tidakDievaluasi: [Color(0xFFDFF3FB), Color(0xFFC9E8F6)],
  };

  /// Versi gelap sedikit lebih dalam supaya tidak menyilaukan di latar navy,
  /// tapi tetap pastel agar teks navy di atasnya kontras.
  static const Map<String, List<Color>> _gradasiGelap = {
    AlertLevels.aman: [Color(0xFF87EFB5), Color(0xFF57B98A)],
    AlertLevels.waspada: [Color(0xFFFFD996), Color(0xFFD9A75C)],
    AlertLevels.perhatian: [Color(0xFFFFB98C), Color(0xFFD2724E)],
    AlertLevels.bahaya: [Color(0xFFF89A9A), Color(0xFFCF5F6C)],
    AlertLevels.tidakDievaluasi: [Color(0xFFB9E6F7), Color(0xFF8CC9E4)],
  };

  Color level(String namaLevel) => switch (namaLevel) {
    AlertLevels.aman => aman,
    AlertLevels.waspada => waspada,
    AlertLevels.perhatian => perhatian,
    AlertLevels.bahaya => bahaya,
    _ => netral,
  };

  Color tier(String namaTier) => switch (namaTier) {
    'personal' => aman,
    'sebagian' => waspada,
    _ => netral,
  };

  /// Gradien kartu menonjol untuk satu level.
  List<Color> gradasiLevel(String namaLevel) =>
      gradasi[namaLevel] ?? gradasi[AlertLevels.tidakDievaluasi]!;

  /// Latar berwarna tipis untuk chip dan kotak level.
  Color levelSurface(String namaLevel) =>
      Color.alphaBlend(level(namaLevel).withValues(alpha: 0.10), card);

  /// Latar layar: gradasi vertikal "langit pagi" dari [gradien].
  ///
  /// Glow lembut di dua sudut dipasang oleh [LatarJustBreathe] karena
  /// [BoxDecoration] hanya bisa memuat satu gradient.
  BoxDecoration radialLatar() => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [...gradien],
    ),
  );

  /// Bayangan kartu Just Breathe: biru tipis, blur 24, turun 8px.
  ///
  /// Tint-nya [bayangan], bukan [ink]: di mode gelap ink hampir putih, jadi
  /// kalau ikut warna teks kartu akan berhalo terang alih-alih berbayang.
  List<BoxShadow> softShadow({Color? tint}) => [
    BoxShadow(
      color: (tint ?? bayangan).withValues(alpha: shadowAlpha * 0.55),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  /// Warna status untuk skala AQI 0-300+.
  static Color aqiBand(double aqi) {
    if (aqi <= 50) return AppPalette.aqiGood;
    if (aqi <= 100) return AppPalette.aqiModerate;
    if (aqi <= 150) return AppPalette.aqiSensitive;
    if (aqi <= 200) return AppPalette.aqiUnhealthy;
    return AppPalette.aqiHazardous;
  }
}

/// Latar aplikasi: gradasi vertikal plus dua glow radial tipis, persis
/// "soft sky-blue gradients with faint blurred light glows" di DESIGN.md.
class LatarJustBreathe extends StatelessWidget {
  const LatarJustBreathe({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final gelap = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: tones.radialLatar(),
      child: Stack(
        children: [
          Positioned(
            top: -140,
            right: -100,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      tones.aksen.withValues(alpha: gelap ? 0.16 : 0.22),
                      tones.aksen.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 380,
            left: -160,
            child: IgnorePointer(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      tones.aksenSoft.withValues(alpha: gelap ? 0.10 : 0.55),
                      tones.aksenSoft.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Skala tipografi Just Breathe.
///
/// DESIGN.md menulis display-xl 56/800, headline-md 22/700, title-sm 16/600,
/// body-md 14/400, caption 12/500. Angka-angka itu dipetakan ke nama peran
/// yang sudah dipakai seluruh layar supaya layar lama ikut berubah tanpa
/// disentuh satu per satu.
class AppTeks {
  const AppTeks._();

  static const TextStyle _jakarta = TextStyle(fontFamily: 'Plus Jakarta Sans');

  /// Sapaan besar di beranda.
  static TextStyle sapaan(AppTones t) => _jakarta.copyWith(
    fontSize: 28,
    height: 1.15,
    fontWeight: FontWeight.w800,
    color: t.ink,
  );

  /// Judul layar (headline-md).
  static TextStyle judulHalaman(AppTones t) => _jakarta.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: t.ink,
  );

  /// Judul kartu besar.
  static TextStyle judulKartu(AppTones t) => _jakarta.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: t.ink,
  );

  /// Judul di atas kartu bergradien pastel.
  static TextStyle judulHero(AppTones t) => _jakarta.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppTones.onGradien,
  );

  /// Label baris dan judul kecil (title-sm).
  static TextStyle judulBaris(AppTones t) => _jakarta.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: t.ink,
  );

  /// Keterangan pendamping angka.
  static TextStyle eyebrow(AppTones t) => _jakarta.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: t.inkSoft,
  );

  /// Teks isi (body-md).
  static TextStyle isi(AppTones t) => _jakarta.copyWith(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: t.ink,
  );

  static TextStyle isiSoft(AppTones t) => isi(t).copyWith(color: t.inkSoft);

  /// Label seksi (caption).
  static TextStyle labelSeksi(AppTones t) => _jakarta.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: t.inkSoft,
  );

  /// Angka dalam kartu: tabular supaya kolomnya tidak bergeser.
  static TextStyle angka(AppTones t) => _jakarta.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: t.ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Angka hero AQI (display-xl) dengan satuan kecil di sebelahnya.
  static TextStyle displayAngka(AppTones t) => _jakarta.copyWith(
    fontSize: 56,
    height: 1,
    fontWeight: FontWeight.w800,
    color: t.ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Teks tombol pil / tautan aksi.
  static TextStyle tautan(AppTones t) => _jakarta.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: t.aksenDeep,
  );

  /// Isi badge bulat di kepala halaman.
  static TextStyle badge(AppTones t) => _jakarta.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
}

/// Ukuran layout Just Breathe: padding 20, kartu radius 24, pil penuh.
class AppLayout {
  const AppLayout._();

  static const EdgeInsets paddingHalaman = EdgeInsets.all(20);

  static const Widget jarak = SizedBox(height: 16);

  static const Widget jarakKecil = SizedBox(height: 10);

  static const double radiusKartu = 14;
  static const double radiusGrup = 12;
  static const double radiusPil = 999;

  /// Tinggi bar navigasi mengambang; Scaffold memakai tinggi ini sebagai
  /// ruang bawah, jadi konten tidak tertutup pil.
  static const double tinggiBar = 88;

  /// Ruang kosong di bawah konten; bar navigasi mengambang menambah
  /// [tinggiBar] lewat `bottomNavigationBar`.
  static double bawahKonten(BuildContext context) => 20;
}

/// Ikon, bentuk eskalasi, dan teks untuk setiap level alert.
///
/// Warnanya tidak ada di sini lagi — lihat [AppTones.level], karena warna
/// harus mengikuti tema terang/gelap.
class LevelStyle {
  const LevelStyle._();

  /// Warna level untuk kode non-UI (notifikasi) yang tidak punya konteks.
  static Color colorOf(String level) => AppTones.terang.level(level);

  static Color surfaceOf(String level) => AppTones.terang.levelSurface(level);

  /// Eskalasi bentuk, bukan hanya warna: lingkaran → segitiga → oktagonal →
  /// SOS, supaya level tetap bedah bagi pembaca yang buta warna.
  static IconData iconOf(String level) => switch (level) {
    AlertLevels.aman => Icons.check_circle_outline,
    AlertLevels.waspada => Icons.warning_amber_rounded,
    AlertLevels.perhatian => Icons.dangerous_outlined,
    AlertLevels.bahaya => Icons.sos_rounded,
    _ => Icons.help_outline_rounded,
  };

  static String deskripsi(String level, L10n kamus) =>
      kamus.t('level.${kunciLevel(level)}');

  static String kunciLevel(String level) => switch (level) {
    AlertLevels.aman => 'aman',
    AlertLevels.waspada => 'waspada',
    AlertLevels.perhatian => 'perhatian',
    AlertLevels.bahaya => 'bahaya',
    _ => 'tidak_dievaluasi',
  };
}

/// Ikon dan label pendek untuk tiap kondisi yang dipantau secara personal.
class KondisiStyle {
  const KondisiStyle._();

  static IconData iconOf(String kondisi) => switch (kondisi) {
    'Bronkitis' => Icons.air_rounded,
    'Anxiety' => Icons.psychology_outlined,
    'Alergi Dingin' => Icons.ac_unit_rounded,
    _ => Icons.monitor_heart_outlined,
  };

  static String subtitle(String kondisi, L10n kamus) =>
      kamus.t('kondisi.${kunci(kondisi)}.subtitle');

  /// Label pendek untuk ringkasan di kartu paling atas, supaya nama kondisi
  /// tidak muncul dua kali di satu layar.
  static String shortLabel(String kondisi, L10n kamus) =>
      kamus.t('kondisi.${kunci(kondisi)}.pendek');

  static String kunci(String kondisi) => switch (kondisi) {
    'Bronkitis' => 'bronkitis',
    'Anxiety' => 'anxiety',
    _ => 'dingin',
  };
}

/// Kartu bagian dengan judul, ikon, dan deskripsi opsional.
///
/// Semua layar memakainya supaya hierarki informasi seragam: ikon kecil,
/// judul singkat, satu baris penjelasan, lalu isinya. Bentuknya ditiru dari
/// kartu template: radius 20, tanpa garis tepi keras, bayangan tipis offset
/// (4,8). [gradasi] mengubah kartu menjadi kartu menonjol bergaya pastel
/// seperti `TaskProgressCard`, dengan teks navy di atasnya.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.judul,
    required this.children,
    this.ikon,
    this.deskripsi,
    this.trailing,
    this.warnaIkon,
    this.gradasi,
    this.ukuranJudul,
    this.margin = const EdgeInsets.only(bottom: 16),
    super.key,
  });

  final String judul;
  final List<Widget> children;
  final IconData? ikon;
  final String? deskripsi;
  final Widget? trailing;
  final Color? warnaIkon;

  /// Ukuran judul khusus kartu yang judulnya panjang; null = ukuran bawaan.
  final double? ukuranJudul;

  /// Dua warna gradient; kalau diisi, kartu memakai teks [AppTones.onGradien].
  final List<Color>? gradasi;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = AppTones.of(context);
    final menonjol = gradasi != null && gradasi!.length >= 2;
    final aksen =
        warnaIkon ??
        (menonjol ? AppTones.onGradien : theme.colorScheme.primary);
    final teksJudul = menonjol ? AppTones.onGradien : tones.ink;
    final teksSoft = menonjol
        ? AppTones.onGradien.withValues(alpha: 0.8)
        : tones.inkSoft;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: menonjol ? null : tones.card,
        gradient: menonjol
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradasi!,
              )
            : null,
        borderRadius: BorderRadius.circular(AppLayout.radiusKartu),
        boxShadow: menonjol
            ? const [
                // Persis `TaskProgressCard`: satu bayangan hitam tipis, offset
                // (4,8), tanpa lapisan kedua.
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(4, 8),
                ),
              ]
            : tones.softShadow(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (ikon != null) ...[
                  KotakIkon(ikon: ikon!, warna: aksen),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    judul,
                    style: AppTeks.judulKartu(tones).copyWith(
                      color: teksJudul,
                      fontSize: ukuranJudul,
                      fontWeight: menonjol ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              ],
            ),
            if (deskripsi != null && deskripsi!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                deskripsi!,
                style: AppTeks.isi(tones)
                    .copyWith(fontSize: 15, color: teksSoft),
              ),
            ],
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Kotak ikon paling khas template: bidang kecil bersudut 10 (bukan pil, bukan
/// lingkaran) dengan warna level di belakang ikon.
///
/// Ukurannya diambil dari `project_badge.dart` (60×60 radius 10) lalu diturunkan
/// sedikit supaya muat di judul kartu; `BadgedContainer` memakai lingkaran 50×50
/// untuk baris pengaturan, dan itu [lingkaran].
class KotakIkon extends StatelessWidget {
  const KotakIkon({
    required this.ikon,
    required this.warna,
    this.ukuran = 44,
    this.ukuranIkon = 22,
    this.lingkaran = false,
    this.tertutup = false,
    super.key,
  });

  final IconData ikon;
  final Color warna;
  final double ukuran;
  final double ukuranIkon;
  final bool lingkaran;

  /// Isi penuh (ikon putih di bidang warna), seperti badge `A06AFA` di
  /// `BadgedContainer`; kalau false, warnanya jadi latar tipis saja.
  final bool tertutup;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Container(
      width: ukuran,
      height: ukuran,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tertutup ? warna : warna.withValues(alpha: 0.16),
        shape: lingkaran ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: lingkaran
            ? null
            : BorderRadius.circular(AppLayout.radiusGrup + 2),
        border: tertutup
            ? null
            : Border.all(color: warna.withValues(alpha: 0.28), width: 1),
      ),
      child: Icon(
        ikon,
        size: ukuranIkon,
        color: tertutup
            ? (lingkaran || tones.bayangan == Colors.black
                  ? Colors.white
                  : tones.canvas)
            : warna,
      ),
    );
  }
}

/// Label seksi `ContainerLabel`: teks 12 bold berwarna muted yang digantung DI
/// LUAR kartu, lalu 10 px ruang ke kartunya.
class LabelSeksi extends StatelessWidget {
  const LabelSeksi({
    required this.teks,
    this.trailing,
    this.margin = const EdgeInsets.only(top: 20, bottom: 10),
    super.key,
  });

  final String teks;
  final Widget? trailing;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Padding(
      padding: margin,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(teks, style: AppTeks.labelSeksi(tones))),
          ?trailing,
        ],
      ),
    );
  }
}

/// Tautan aksi kecil di ujung kanan label seksi, gaya `text_button.dart`
/// (16 bold, `#616575`).
class TautanLihat extends StatelessWidget {
  const TautanLihat({required this.teks, required this.onTap, super.key});

  final String teks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppLayout.radiusPil),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(teks, style: AppTeks.tautan(tones)),
      ),
    );
  }
}

/// Kepala halaman template (`DashboardNav` / `app_header.dart`): judul 25 bold
/// di kiri, lalu di kanan ikon dengan lencana jumlah + avatar.
class KepalaHalaman extends StatelessWidget {
  const KepalaHalaman({
    required this.judul,
    this.ikon,
    this.jumlah,
    this.onKetukIkon,
    this.onKetukAvatar,
    this.namaAvatar,
    super.key,
  });

  final String judul;
  final IconData? ikon;
  final int? jumlah;
  final VoidCallback? onKetukIkon;
  final VoidCallback? onKetukAvatar;
  final String? namaAvatar;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            judul,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTeks.judulHalaman(tones),
          ),
        ),
        if (ikon != null) ...[
          const SizedBox(width: 12),
          InkWell(
            onTap: onKetukIkon,
            borderRadius: BorderRadius.circular(AppLayout.radiusPil),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: LencanaJumlah(ikon: ikon!, jumlah: jumlah),
            ),
          ),
        ],
        if (onKetukAvatar != null || namaAvatar != null) ...[
          const SizedBox(width: 20),
          InkWell(
            onTap: onKetukAvatar,
            customBorder: const CircleBorder(),
            child: AvatarLingkaran(nama: namaAvatar),
          ),
        ],
      ],
    );
  }
}

/// Ikon 30 dengan lencana bulat peach di sudut kanan atas, persis Stack di
/// `DashboardNav` (padding 6/2, teks 11 putih).
class LencanaJumlah extends StatelessWidget {
  const LencanaJumlah({
    required this.ikon,
    required this.jumlah,
    this.ukuranIkon = 26,
    super.key,
  });

  final IconData ikon;
  final int? jumlah;
  final double ukuranIkon;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final n = jumlah ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(ikon, size: ukuranIkon, color: tones.ink),
        if (n > 0)
          Positioned(
            top: -3,
            right: -5,
            child: Container(
              // Badge lebih kecil: min-width 16, padding horizontal 4
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
              decoration: BoxDecoration(
                color: tones.sinyal,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$n',
                textAlign: TextAlign.center,
                style: AppTeks.badge(tones).copyWith(fontSize: 9),
              ),
            ),
          ),
      ],
    );
  }
}

/// Avatar lingkaran template: `ProfileDummy` 40×scale dengan latar pastel.
class AvatarLingkaran extends StatelessWidget {
  const AvatarLingkaran({this.nama, this.skala = 0.9, super.key});

  final String? nama;
  final double skala;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final besar = 40 * skala;
    final inisial = (nama ?? '').trim();
    return Container(
      width: besar,
      height: besar,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tones.aksenSoft,
        shape: BoxShape.circle,
        border: Border.all(color: tones.line),
      ),
      child: inisial.isEmpty
          ? Icon(
              Icons.person_rounded,
              size: besar * 0.55,
              color: tones.aksenDeep,
            )
          : Text(
              inisial.characters.first.toUpperCase(),
              style: AppTeks.judulBaris(tones)
                  .copyWith(color: tones.aksenDeep, fontSize: besar * 0.38),
            ),
    );
  }
}

/// Baris kartu yang bisa ditekan, anatomi `OverviewTaskContainer`: tinggi 80,
/// padding 8, lead 70×80 bersudut 10, judul 20 w600, angka + chevron 30.
class KartuBaris extends StatelessWidget {
  const KartuBaris({
    required this.ikon,
    required this.judul,
    this.warna,
    this.nilai,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.margin = const EdgeInsets.symmetric(vertical: 10),
    super.key,
  });

  final IconData ikon;
  final String judul;
  final Color? warna;
  final String? nilai;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final aksen = warna ?? tones.aksen;
    return Padding(
      padding: margin,
      child: Material(
        color: tones.card,
        borderRadius: BorderRadius.circular(AppLayout.radiusKartu),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppLayout.radiusKartu),
          child: Container(
            width: double.infinity,
            height: 80,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppLayout.radiusKartu),
              boxShadow: tones.softShadow(),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: aksen.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(
                            AppLayout.radiusGrup,
                          ),
                        ),
                        child: Icon(ikon, size: 26, color: aksen),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              judul,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTeks.judulKartu(tones),
                            ),
                            if (subtitle != null && subtitle!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTeks.labelSeksi(tones),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (nilai != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    nilai!,
                    style: AppTeks.judulKartu(tones).copyWith(color: aksen),
                  ),
                ],
                if (trailing != null) ...[const SizedBox(width: 10), trailing!],
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 30,
                    color: tones.inkSoft,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sekumpulan baris di dalam SATU kontainer bersudut 10 + pembatas 1 px,
/// gaya `ProfileTextOption` di `my_profile.dart`.
class GrupBaris extends StatelessWidget {
  const GrupBaris({
    required this.children,
    this.paddingTombol = true,
    this.warna,
    super.key,
  });

  final List<Widget> children;
  final bool paddingTombol;

  /// Latar kontainer. Default [AppTones.card]; di dalam kartu lain pakai
  /// [AppTones.panel] supaya daftarnya terlihat sebagai bidang sendiri.
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final daftar = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        daftar.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 20,
            endIndent: 20,
            color: tones.line,
          ),
        );
      }
      daftar.add(children[i]);
    }
    return Container(
      decoration: BoxDecoration(
        color: warna ?? tones.card,
        borderRadius: BorderRadius.circular(AppLayout.radiusGrup),
        boxShadow: warna == null ? tones.softShadow() : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppLayout.radiusGrup),
        child: paddingTombol
            ? Material(
                color: Colors.transparent,
                child: Column(children: daftar),
              )
            : Column(children: daftar),
      ),
    );
  }
}

/// Satu baris dalam [GrupBaris]: ikon 24 + teks 18 + aksi, padding vertikal 10
/// seperti `ProfileTextOption`.
class BarisSetelan extends StatelessWidget {
  const BarisSetelan({
    required this.ikon,
    required this.judul,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.warna,
    super.key,
  });

  final IconData ikon;
  final String judul;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final aksen = warna ?? tones.inkSoft;
    final isi = Row(
      children: [
        Icon(ikon, size: 24, color: aksen),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                judul,
                style: AppTeks.judulBaris(tones)
                    .copyWith(fontWeight: FontWeight.w600, fontSize: 18),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: AppTeks.isi(tones)
                      .copyWith(fontSize: 13.5, color: tones.inkSoft),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: isi,
      );
    }
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: isi,
      ),
    );
  }
}

/// Tombol pil filter/segment, tiruan `PrimaryTabButton`: radius 50, aktif biru
/// penuh dengan teks putih 16, tidak aktif bidang `panel`.
class PilTab extends StatelessWidget {
  const PilTab({
    required this.teks,
    required this.aktif,
    required this.onTap,
    this.ukuranTeks = 13,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    super.key,
  });

  final String teks;
  final bool aktif;
  final VoidCallback onTap;
  final double ukuranTeks;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Material(
        color: aktif ? tones.aksen : tones.panel,
        borderRadius: BorderRadius.circular(AppLayout.radiusPil),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppLayout.radiusPil),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppLayout.radiusPil),
              border: Border.all(
                color: aktif ? tones.aksen : tones.panel,
                width: 1,
              ),
            ),
            child: Text(
              teks,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: ukuranTeks,
                fontWeight: aktif ? FontWeight.bold : FontWeight.w500,
                color: aktif ? Colors.white : tones.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Batang progres template: rel putih/lembut tinggi 10, radius 20, isinya
/// proporsi [pct] dengan warna aksen. Anatomi `TaskProgressCard` +
/// `ProjectCardHorizontal`.
class BilasProgres extends StatelessWidget {
  const BilasProgres({
    required this.pct,
    required this.warna,
    this.teriisi,
    super.key,
  });

  final double pct;
  final Color warna;

  /// Warna isian di atas kartu bergradien; template memakai hitam solid.
  final Color? teriisi;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final p = pct.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, c) => Row(
        children: [
          SizedBox(
            width: c.maxWidth,
            height: 10,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: tones.card.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(
                        AppLayout.radiusKartu,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: (c.maxWidth * p).clamp(0.0, c.maxWidth),
                  child: Container(
                    decoration: BoxDecoration(
                      color: teriisi ?? warna,
                      borderRadius: BorderRadius.circular(
                        AppLayout.radiusKartu,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip kecil tanpa ikon, untuk label jumlah atau keterangan singkat.
class InfoChip extends StatelessWidget {
  const InfoChip({
    required this.teks,
    this.ikon,
    this.warna,
    this.berat = FontWeight.w700,
    super.key,
  });

  final String teks;
  final IconData? ikon;
  final Color? warna;
  final FontWeight berat;

  @override
  Widget build(BuildContext context) {
    final color = warna ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      // Padding lebih kecil agar chip proporsional di mobile
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ikon != null) ...[
            Icon(ikon, size: 10, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                teks,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: color,
                  fontSize: 10,
                  fontWeight: berat,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip level: warna + ikon + teks, dipakai di semua kartu hasil.
class LevelChip extends StatelessWidget {
  const LevelChip({required this.level, this.showIcon = true, super.key});

  final String level;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final color = AppTones.of(context).level(level);
    return Container(
      // Padding lebih kecil agar chipnya tidak terlalu besar
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(LevelStyle.iconOf(level), size: 10, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                level,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 9.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gauge skor 0-100: angka di tengah, cincin menunjukkan proporsinya.
class ScoreGauge extends StatelessWidget {
  const ScoreGauge({
    required this.skor,
    required this.level,
    this.size = 52,
    super.key,
  });

  final int skor;
  final String level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    final tones = AppTones.of(context);
    final color = tones.level(level);
    return Tooltip(
      message: kamus.t('umum.skor_dari', {'skor': '$skor'}),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: Padding(
                padding: const EdgeInsets.all(1.5),
                child: CircularProgressIndicator(
                  value: (skor / 100).clamp(0.0, 1.0),
                  // Cincin tebal seperti ring 8px di `DailyGoalCard`, relnya
                  // bidang netral (bukan warna level yang dipudarkan).
                  strokeWidth: size >= 80 ? 8 : 6,
                  strokeCap: StrokeCap.round,
                  backgroundColor: tones.panel,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
            Text(
              '$skor',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: color,
                fontSize: size * 0.34,
                fontWeight: FontWeight.bold,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip asal ambang: seberapa personal angka yang dipakai kondisi ini.
class KalibrasiChip extends StatelessWidget {
  const KalibrasiChip({required this.kalibrasi, super.key});

  final String kalibrasi;

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    final warna = AppTones.of(context).tier(kalibrasi);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                kamus.t('umum.ambang_kalibrasi', {
                  'kalibrasi': kamus.t('kalibrasi.$kalibrasi'),
                }),
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: warna,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiga angka ringkas dalam satu baris: nilai besar + label kecil.
class MiniStat extends StatelessWidget {
  const MiniStat({
    required this.nilai,
    required this.label,
    this.warna,
    super.key,
  });

  final String nilai;
  final String label;
  final Color? warna;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final color = warna ?? tones.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nilai,
          style: AppTeks.angka(
            tones,
          ).copyWith(color: color, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTeks.labelSeksi(tones)
              .copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Kotak kosong yang rapi: ikon di lingkaran + judul + penjelasan.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.ikon,
    required this.judul,
    required this.pesan,
    super.key,
  });

  final IconData ikon;
  final String judul;
  final String pesan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = AppTones.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: tones.card,
        borderRadius: BorderRadius.circular(AppLayout.radiusKartu),
        boxShadow: tones.softShadow(),
      ),
      child: Column(
        children: [
          KotakIkon(
            ikon: ikon,
            warna: theme.colorScheme.primary,
            ukuran: 50,
            ukuranIkon: 26,
            lingkaran: true,
            tertutup: true,
          ),
          const SizedBox(height: 16),
          Text(
            judul,
            textAlign: TextAlign.center,
            style: AppTeks.judulKartu(tones)
                .copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            pesan,
            textAlign: TextAlign.center,
            style: AppTeks.isi(tones)
                .copyWith(fontSize: 15, color: tones.inkSoft),
          ),
        ],
      ),
    );
  }
}
