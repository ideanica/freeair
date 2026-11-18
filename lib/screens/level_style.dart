import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/condition_result.dart';

/// Palet terang dasar — angka aslinya dituliskan satu kali di sini.
///
/// Warnanya diambil dari template Taskez (navy `#181A1F`, biru `#246CFD`,
/// mauve `#C25FFF`, peach `#FC946E`) lalu dinaikkan kontrasnya supaya teks
/// tetap terbaca di latar terang. Mode gelap tidak membuat palet baru di
/// setiap layar, melainkan memakai [AppTones] yang dipilih dari brightness
/// tema aktif.
class AppPalette {
  const AppPalette._();

  static const Color aksen = Color(0xFF246CFD);
  static const Color aksenDeep = Color(0xFF1846B4);
  static const Color aksenSoft = Color(0xFFE3ECFF);

  /// Lavender tipis, padanan terang dari latar navy template.
  static const Color canvas = Color(0xFFF3F1F8);
  static const Color card = Colors.white;
  static const Color line = Color(0xFFE3DFEE);

  /// Navy template `#181A1F` dipakai sebagai warna teks, bukan latar.
  static const Color ink = Color(0xFF1B1D26);
  static const Color inkSoft = Color(0xFF666A7B);

  static const Color aman = Color(0xFF2E9E63);
  static const Color waspada = Color(0xFFB8791A);
  static const Color perhatian = Color(0xFFDC6B2E);
  static const Color bahaya = Color(0xFFC9414C);
  static const Color netral = Color(0xFF6B7280);
  static const Color mauve = Color(0xFF8B3FCB);
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
    panel: Color(0xFFEDE9F7),
    sinyal: Color(0xFFFF9B76),
    bayangan: AppPalette.ink,
    shadowAlpha: 0.07,
    gradien: [Color(0xFFEDE7F8), Color(0xFFF3F1F8)],
    gradasi: _gradasiTerang,
  );

  /// Latar navy `#181A1F` + radial ke `#1D192D` seperti template Taskez; kartu
  /// satu tingkat lebih terang (`#1F222B`) supaya tetap terbaca sebagai bidang.
  static const AppTones gelap = AppTones(
    aksen: Color(0xFF4A85FF),
    aksenDeep: Color(0xFF9DC0FF),
    aksenSoft: Color(0xFF18243C),
    canvas: Color(0xFF181A1F),
    card: Color(0xFF1F222B),
    line: Color(0xFF31333D),
    ink: Color(0xFFF3F5FA),
    inkSoft: Color(0xFF97A0B4),
    aman: Color(0xFF94D57B),
    waspada: Color(0xFFFFD996),
    perhatian: Color(0xFFFC946E),
    bahaya: Color(0xFFFF7B7B),
    netral: Color(0xFF8FA0B5),
    mauve: Color(0xFFC25FFF),
    onAksen: Color(0xFF0B1220),
    panel: Color(0xFF20222A),
    sinyal: Color(0xFFFF9B76),
    bayangan: Colors.black,
    shadowAlpha: 0.42,
    gradien: [Color(0xFF1D192D), Color(0xFF181A1F)],
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
  static const Color onGradien = Color(0xFF181A1F);

  static const Map<String, List<Color>> _gradasiTerang = {
    AlertLevels.aman: [Color(0xFF9FF0C4), Color(0xFF63BE86)],
    AlertLevels.waspada: [Color(0xFFFFE2AC), Color(0xFFE3AE5D)],
    AlertLevels.perhatian: [Color(0xFFFFB494), Color(0xFFE07B47)],
    AlertLevels.bahaya: [Color(0xFFFFB1B1), Color(0xFFDE6570)],
    AlertLevels.tidakDievaluasi: [Color(0xFFBFE3EA), Color(0xFFC8B0EF)],
  };

  /// Versi gelap sedikit lebih dalam supaya tidak menyilaukan di latar navy,
  /// tapi tetap pastel agar teks navy di atasnya kontras.
  static const Map<String, List<Color>> _gradasiGelap = {
    AlertLevels.aman: [Color(0xFF87EFB5), Color(0xFF57B98A)],
    AlertLevels.waspada: [Color(0xFFFFD996), Color(0xFFD9A75C)],
    AlertLevels.perhatian: [Color(0xFFFC946E), Color(0xFFD2724E)],
    AlertLevels.bahaya: [Color(0xFFF89A9A), Color(0xFFCF5F6C)],
    AlertLevels.tidakDievaluasi: [Color(0xFF87D3DF), Color(0xFFAE93D8)],
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

  /// Latar layar: radial dari sudut, persis `DarkRadialBackground` template.
  BoxDecoration radialLatar() => BoxDecoration(
    gradient: RadialGradient(
      center: const Alignment(-0.9, -1.0),
      radius: 1.4,
      colors: [...gradien],
    ),
  );

  /// Bayangan kartu template: tipis, offset ke kanan-bawah.
  ///
  /// Tint-nya [bayangan], bukan [ink]: di mode gelap ink hampir putih, jadi
  /// kalau ikut warna teks kartu akan berhalo terang alih-alih berbayang.
  List<BoxShadow> softShadow({Color? tint}) => [
    BoxShadow(
      color: (tint ?? bayangan).withValues(alpha: shadowAlpha),
      blurRadius: 12,
      offset: const Offset(4, 8),
    ),
    BoxShadow(
      color: (tint ?? bayangan).withValues(alpha: shadowAlpha * 0.45),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];
}

/// Skala tipografi Lato yang dipakai template Taskez di seluruh layarnya.
///
/// Template menulis ukuran per-komponen (bukan token Material), jadi angka
/// aslinya dikumpulkan di sini: sapaan 40, judul halaman 25, judul kartu 20
/// w600, judul hero 22, teks isi 16, label seksi 12 bold, badge 11-12. Semua
/// sudah termasuk warna dari [AppTones] supaya mode gelap ikut berganti.
class AppTeks {
  const AppTeks._();

  static const TextStyle _lato = TextStyle(fontFamily: 'Lato');

  /// "Hello,\nDereck Doyle" di `dashboard.dart`.
  static TextStyle sapaan(AppTones t) => _lato.copyWith(
    fontSize: 40,
    height: 1.1,
    fontWeight: FontWeight.bold,
    color: t.ink,
  );

  /// Judul layar `AppTextStyles.header2` / `app_header.dart`.
  static TextStyle judulHalaman(AppTones t) =>
      _lato.copyWith(fontSize: 25, fontWeight: FontWeight.bold, color: t.ink);

  /// Juduk `OverviewTaskContainer` dan judul kartu besar.
  static TextStyle judulKartu(AppTones t) => _lato.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: t.ink,
  );

  /// Judul di atas kartu bergradien pastel, persis `TaskProgressCard`.
  static TextStyle judulHero(AppTones t) => _lato.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppTones.onGradien,
  );

  /// Label `BadgedContainer` dan angka besar.
  static TextStyle judulBaris(AppTones t) =>
      _lato.copyWith(fontSize: 17, fontWeight: FontWeight.bold, color: t.ink);

  /// Eyebrow `DailyGoalCard`: keterangan 17 w500 di atas angka.
  static TextStyle eyebrow(AppTones t) => _lato.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: t.inkSoft,
  );

  /// Teks isi template (tanpa height — Lato sudah longgar).
  static TextStyle isi(AppTones t) => _lato.copyWith(
    fontSize: 16,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: t.ink,
  );

  static TextStyle isiSoft(AppTones t) => isi(t).copyWith(color: t.inkSoft);

  /// `ContainerLabel`: label seksi kecil yang digantung di atas kartu.
  static TextStyle labelSeksi(AppTones t) => _lato.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: t.inkSoft,
  );

  /// Angka dalam kartu: tabular supaya kolomnya tidak bergeser.
  static TextStyle angka(AppTones t) => _lato.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: t.ink,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Teks tombol pil / tautan aksi (`text_button.dart`, `PrimaryTabButton`).
  static TextStyle tautan(AppTones t) => _lato.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: t.aksenDeep,
  );

  /// Isi badge bulat di kepala halaman.
  static TextStyle badge(AppTones t) => _lato.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
}

/// Ukuran layout yang sama dipakai semua layar — angka aslinya dari template.
class AppLayout {
  const AppLayout._();

  /// `EdgeInsets.all(20.0)` di `dashboard.dart`, `search_screen.dart`.
  static const EdgeInsets paddingHalaman = EdgeInsets.all(20);

  /// Jarak antar blok utama (`AppSpaces.verticalSpace20`).
  static const Widget jarak = SizedBox(height: 20);

  /// Jarak label seksi ke kartunya (`verticalSpace10`).
  static const Widget jarakKecil = SizedBox(height: 10);

  /// Radius kartu besar, kontainer daftar, dan pil (`20 / 10 / 50`).
  static const double radiusKartu = 20;
  static const double radiusGrup = 10;
  static const double radiusPil = 50;

  /// Tinggi bar navigasi template (`timeline.dart`), termasuk diamond di
  /// bawah ikon aktif.
  static const double tinggiBar = 90;

  /// Ruang kosong di bawah konten. Bar navigasi sekarang benar-benar menjadi
  /// `bottomNavigationBar`, jadi Scaffold yang menghitung sisanya dan konten
  /// cuma butuh satu padding halaman biasa.
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
    this.margin = const EdgeInsets.only(bottom: 20),
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
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: tones.sinyal,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$n',
                textAlign: TextAlign.center,
                style: AppTeks.badge(tones).copyWith(fontSize: 10),
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
    this.ukuranTeks = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
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
                fontFamily: 'Lato',
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ikon != null) ...[
            Icon(ikon, size: 11, color: color),
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
                  fontFamily: 'Lato',
                  color: color,
                  fontSize: 11,
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
            Icon(LevelStyle.iconOf(level), size: 11, color: color),
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
                  fontFamily: 'Lato',
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 10.5,
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
                fontFamily: 'Lato',
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
                  fontFamily: 'Lato',
                  fontSize: 11,
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
