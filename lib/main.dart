import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_settings.dart';
import 'l10n/l10n.dart';
import 'models/condition_result.dart';
import 'models/health_profile.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/level_style.dart';
import 'screens/profile_screen.dart';
import 'screens/sources_screen.dart';
import 'services/alert_orchestrator.dart';
import 'services/database_helpers.dart';
import 'services/health_services.dart';
import 'services/notification_services.dart';
import 'services/rule_config.dart';
import 'services/rule_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bahasa dan tema dimuat lebih dulu supaya frame pertama sudah benar.
  await AppSettings.load();

  final notificationService = createNotificationService();
  await notificationService.init();

  final store = createDatabaseHelper();
  await store.init();

  final config = await RuleConfig.load();
  final ruleEngine = RuleEngine(config);

  final healthService = createHealthService();
  final orchestrator = AlertOrchestrator(
    ruleEngine: ruleEngine,
    healthService: healthService,
    notificationService: notificationService,
    databaseHelper: store,
  );

  // Profil dibuat sekali di sini agar cek berkala dan UI memakai kondisi yang
  // sama; hanya daftar kondisi dan wilayah cuaca yang bisa diubah pengguna.
  final profil =
      await HealthProfile.load() ??
      HealthProfile.fromConfig(config.profilDefault);
  await profil.save();

  runApp(
    HealthAlertApp(
      orchestrator: orchestrator,
      healthService: healthService,
      store: store,
    ),
  );

  // Sampel di luar jendela kalibrasi dibuang sekali saat aplikasi dibuka.
  await orchestrator.bereskan();

  // Siklus pertama dijalankan setelah frame tampil supaya UI tidak menunggu
  // jaringan; timer berkala menyusul tiap CYCLE_INTERVAL_MINUTES.
  orchestrator.startPeriodic();
  try {
    await orchestrator.runCycle(profil: profil);
  } catch (e, s) {
    debugPrint('Siklus awal gagal: $e — $s');
  }
}

class HealthAlertApp extends StatefulWidget {
  const HealthAlertApp({
    required this.orchestrator,
    required this.healthService,
    required this.store,
    super.key,
  });

  final AlertOrchestrator orchestrator;
  final HealthService healthService;
  final DatabaseHelper store;

  @override
  State<HealthAlertApp> createState() => _HealthAlertAppState();
}

class _HealthAlertAppState extends State<HealthAlertApp> {
  @override
  void initState() {
    super.initState();
    AppSettings.perubahan.addListener(_uatTampilan);
  }

  @override
  void dispose() {
    AppSettings.perubahan.removeListener(_uatTampilan);
    super.dispose();
  }

  /// Ganti bahasa atau tema langsung terasa di seluruh aplikasi.
  void _uatTampilan() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Alert',
      debugShowCheckedModeBanner: false,
      locale: AppSettings.localeMaterial,
      supportedLocales: const [Locale('id'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: temaAplikasi(),
      darkTheme: temaAplikasi(gelap: true),
      themeMode: AppSettings.themeMode,
      // Latar radial Taskez dipasang di sini, bukan di ThemeData (yang memang
      // tidak punya builder), supaya ikut berlaku di semua route dan dialog.
      builder: (context, child) => DecoratedBox(
        decoration: AppTones.of(context).radialLatar(),
        child: child ?? const SizedBox.shrink(),
      ),
      home: RootShell(
        orchestrator: widget.orchestrator,
        healthService: widget.healthService,
        store: widget.store,
      ),
      routes: {
        '/profile': (_) => ProfileScreen(orchestrator: widget.orchestrator),
        '/history': (_) =>
            HistoryScreen(store: widget.store, pengamat: widget.orchestrator),
        '/sources': (_) => SourcesScreen(config: widget.orchestrator.config),
      },
    );
  }
}

/// Tema yang dipasang MaterialApp.
///
/// Diekspor supaya test bisa memompa layar dengan tema yang sama persis seperti
/// aplikasi, bukan tiruan yang bisa menyimpang dari warna asli.
ThemeData temaAplikasi({bool gelap = false}) => bangunTema(
  gelap ? AppTones.gelap : AppTones.terang,
  gelap ? _skemaGelap : _skemaTerang,
);

final ColorScheme _skemaTerang = ColorScheme.light(
  primary: AppTones.terang.aksen,
  onPrimary: AppTones.terang.onAksen,
  primaryContainer: AppTones.terang.aksenSoft,
  onPrimaryContainer: AppTones.terang.aksenDeep,
  secondary: AppTones.terang.mauve,
  onSecondary: Colors.white,
  surface: AppTones.terang.card,
  onSurface: AppTones.terang.ink,
  surfaceContainerLowest: AppTones.terang.canvas,
  surfaceContainerLow: const Color(0xFFFAF9FD),
  surfaceContainer: const Color(0xFFF1EFF8),
  surfaceContainerHigh: const Color(0xFFE9E6F3),
  surfaceContainerHighest: const Color(0xFFE1DDEC),
  onSurfaceVariant: AppTones.terang.inkSoft,
  outline: const Color(0xFF8B8FA0),
  outlineVariant: AppTones.terang.line,
  error: AppTones.terang.bahaya,
);

final ColorScheme _skemaGelap = ColorScheme.dark(
  primary: AppTones.gelap.aksen,
  onPrimary: AppTones.gelap.onAksen,
  primaryContainer: AppTones.gelap.aksenSoft,
  onPrimaryContainer: AppTones.gelap.aksenDeep,
  secondary: AppTones.gelap.mauve,
  onSecondary: AppTones.gelap.onAksen,
  surface: AppTones.gelap.card,
  onSurface: AppTones.gelap.ink,
  surfaceContainerLowest: AppTones.gelap.canvas,
  surfaceContainerLow: const Color(0xFF1B1E25),
  surfaceContainer: const Color(0xFF1F222B),
  surfaceContainerHigh: const Color(0xFF252934),
  surfaceContainerHighest: const Color(0xFF2B303C),
  onSurfaceVariant: AppTones.gelap.inkSoft,
  outline: const Color(0xFF8A93A8),
  outlineVariant: AppTones.gelap.line,
  error: AppTones.gelap.bahaya,
);

/// Satu builder tema untuk terang dan gelap.
///
/// Yang berbeda hanya [scheme] dan [t]; bentuk kartu, tipografi, dan navbar
/// tetap sama supaya pindah mode tidak mengubah tata letak.
///
/// Gaya visualnya diambil dari template Taskez: Lato di seluruh UI, latar
/// radial dari sudut kiri atas, kartu radius 20 tanpa garis tepi keras,
/// tombol/chip pil, dan indikator navbar berbentuk diamond.
ThemeData bangunTema(AppTones t, ColorScheme scheme) {
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Lato',
    // Scaffold transparan supaya latar radial dari MaterialApp.builder
    // terlihat di semua layar tanpa menyalin DecoratedBox di tiap screen.
    scaffoldBackgroundColor: Colors.transparent,
    splashColor: t.aksen.withValues(alpha: 0.10),
    highlightColor: t.aksen.withValues(alpha: 0.06),
    textTheme: TextTheme(
      // Skala template Taskez: 40 sapaan, 25 judul halaman, 22/20 judul kartu,
      // 16 isi, 12 label. Widget custom membaca AppTeks; ini supaya Material
      // (AppBar, dialog, ListTile) tidak menyimpang dari skala yang sama.
      displayLarge: AppTeks.sapaan(t),
      headlineMedium: AppTeks.judulHalaman(t),
      titleLarge: AppTeks.judulHero(t),
      titleMedium: AppTeks.judulKartu(t),
      titleSmall: AppTeks.judulBaris(t),
      bodyLarge: AppTeks.isi(t),
      bodyMedium: AppTeks.isi(t).copyWith(fontSize: 15),
      bodySmall: AppTeks.isiSoft(t).copyWith(fontSize: 13.5),
      labelLarge: AppTeks.tautan(t),
      labelMedium: AppTeks.labelSeksi(t),
      labelSmall: AppTeks.badge(t).copyWith(color: t.inkSoft),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: t.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppTeks.judulHalaman(t),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: t.card,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 20),
      // Kartu template tidak bergaris tepi; kedalamannya datang dari bayangan.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.radiusKartu),
      ),
    ),
    dividerTheme: DividerThemeData(color: t.line, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: t.line.withValues(alpha: 0.45),
      labelStyle: TextStyle(fontSize: 13, color: t.inkSoft),
      hintStyle: TextStyle(
        fontSize: 13,
        color: t.inkSoft.withValues(alpha: 0.7),
      ),
      helperStyle: TextStyle(fontSize: 11.5, color: t.inkSoft),
      counterStyle: TextStyle(fontSize: 11.5, color: t.inkSoft),
      iconColor: t.inkSoft,
      prefixIconColor: t.inkSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: t.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: t.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: t.aksen, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.aksen,
        foregroundColor: t.onAksen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        textStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14.5,
          color: t.onAksen,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.aksen,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    // Chip pil ala PrimaryTabButton: terpilih = biru penuh, tidak = panel.
    chipTheme: ChipThemeData(
      backgroundColor: t.line.withValues(alpha: 0.45),
      selectedColor: t.aksen,
      side: BorderSide(color: t.line),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: t.ink,
      ),
      secondaryLabelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: t.onAksen,
      ),
      shape: const StadiumBorder(),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.ink,
      contentTextStyle: TextStyle(
        color: t.canvas,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w800,
        color: t.ink,
      ),
      contentTextStyle: TextStyle(fontSize: 13.5, height: 1.45, color: t.ink),
    ),
    listTileTheme: ListTileThemeData(iconColor: t.inkSoft, textColor: t.ink),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: t.ink.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(9),
      ),
      textStyle: TextStyle(fontFamily: 'Lato', color: t.canvas, fontSize: 12),
    ),
  );
}

/// Navigasi bawah Beranda / Riwayat / Sumber / Profil dengan state tiap tab
/// dipertahankan lewat IndexedStack.
class RootShell extends StatefulWidget {
  const RootShell({
    required this.orchestrator,
    required this.healthService,
    required this.store,
    super.key,
  });

  final AlertOrchestrator orchestrator;
  final HealthService healthService;
  final DatabaseHelper store;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _indeks = 0;

  @override
  void initState() {
    super.initState();
    widget.orchestrator.addListener(_uatHasil);
  }

  @override
  void dispose() {
    widget.orchestrator.removeListener(_uatHasil);
    super.dispose();
  }

  /// Siklus di latar belakang mengubah level, jadi badge tab ikut diperbarui.
  void _uatHasil() {
    if (mounted) setState(() {});
  }

  /// Badge di tab Beranda: berapa kondisi yang sedang di atas ambang aman.
  int get _alertAktif {
    final hasil = widget.orchestrator.hasilTerakhir?.results;
    if (hasil == null) return 0;
    return hasil.where((r) => AlertLevels.levelButuhAlert(r.level)).length;
  }

  @override
  Widget build(BuildContext context) {
    final badge = _alertAktif;
    return Scaffold(
      body: IndexedStack(
        index: _indeks,
        children: [
          HomeScreen(
            orchestrator: widget.orchestrator,
            healthService: widget.healthService,
          ),
          HistoryScreen(store: widget.store, pengamat: widget.orchestrator),
          SourcesScreen(config: widget.orchestrator.config),
          ProfileScreen(orchestrator: widget.orchestrator),
        ],
      ),
      bottomNavigationBar: BarBawah(
        indeks: _indeks,
        alertCount: badge > 0 ? badge : null,
        onPilih: (i) => setState(() => _indeks = i),
      ),
    );
  }
}

/// Bar navigasi bawah: ikon lebih ekspresif + indikator diamond mauve.
class BarBawah extends StatelessWidget {
  const BarBawah({
    required this.indeks,
    required this.onPilih,
    this.alertCount,
    super.key,
  });

  final int indeks;
  final int? alertCount;
  final void Function(int) onPilih;

  // Ikon yang lebih ekspresif dibanding ikon outline generik Material.
  static const List<IconData> _ikonTab = [
    Icons.monitor_heart_outlined,
    Icons.history_edu_outlined,
    Icons.library_books_outlined,
    Icons.manage_accounts_outlined,
  ];

  static const List<IconData> _ikonTabAktif = [
    Icons.monitor_heart_rounded,
    Icons.history_edu_rounded,
    Icons.library_books_rounded,
    Icons.manage_accounts_rounded,
  ];

  static const List<String> _kunciTab = [
    'nav.beranda',
    'nav.riwayat',
    'nav.sumber',
    'nav.profil',
  ];

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    final tones = AppTones.of(context);
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      height: AppLayout.tinggiBar + inset,
      decoration: BoxDecoration(
        color: tones.card.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppLayout.radiusKartu),
        ),
        boxShadow: [
          BoxShadow(
            color: tones.bayangan.withValues(alpha: tones.shadowAlpha * 0.6),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 10, 24, 4 + inset),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < _kunciTab.length; i++)
            Expanded(
              child: _ItemTab(
                aktif: indeks == i,
                label: kamus.t(_kunciTab[i]),
                ikon: i == indeks ? _ikonTabAktif[i] : _ikonTab[i],
                jumlah: i == 0 ? alertCount : null,
                onPilih: () => onPilih(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemTab extends StatelessWidget {
  const _ItemTab({
    required this.aktif,
    required this.label,
    required this.ikon,
    required this.onPilih,
    this.jumlah,
  });

  final bool aktif;
  final String label;
  final IconData ikon;
  final VoidCallback onPilih;
  final int? jumlah;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final ikonColor = aktif ? tones.aksen : tones.inkSoft.withValues(alpha: 0.80);
    final ikonTab = Icon(ikon, size: 26, color: ikonColor);
    return Semantics(
      button: true,
      selected: aktif,
      label: label,
      child: InkWell(
        onTap: onPilih,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
              horizontal: aktif ? 10 : 6, vertical: 4),
          decoration: aktif
              ? BoxDecoration(
                  color: tones.aksenSoft,
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              jumlah == null
                  ? ikonTab
                  : LencanaJumlah(ikon: ikon, jumlah: jumlah, ukuranIkon: 26),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 10.5,
                  fontWeight: aktif ? FontWeight.bold : FontWeight.w500,
                  color: aktif ? tones.aksen : tones.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
