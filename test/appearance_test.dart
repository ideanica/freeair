import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_alert/l10n/app_settings.dart';
import 'package:health_alert/main.dart';
import 'package:health_alert/screens/level_style.dart';
import 'package:health_alert/services/alert_orchestrator.dart';
import 'package:health_alert/services/database_helper_prefs.dart';
import 'package:health_alert/services/health_service_demo.dart';
import 'package:health_alert/services/notification_service_noop.dart';
import 'package:health_alert/services/rule_config.dart';
import 'package:health_alert/services/rule_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kartu Tampilan adalah satu-satunya tempat pengguna memilih bahasa dan tema,
/// jadi yang dijaga di sini adalah rantaian lengkapnya: pilihan tersimpan,
/// MaterialApp membangun ulang, semua layar ikut berganti, dan mode gelap
/// memakai tone gelap asli tanpa membuat satu pun tab error.
void main() {
  late PrefsAlertStore store;
  late AlertOrchestrator orkestrator;

  setUp(() async {
    // id + system dipaksa setiap test: tanpa ini AppSettings.load() mewarisi
    // bahasa perangkat (en-US di lingkungan test) dan assertion jadi ambigu.
    SharedPreferences.setMockInitialValues({
      AppSettings.keyLocale: 'id',
      AppSettings.keyTema: 'system',
    });
    await AppSettings.load();
    final engine = RuleEngine(
      RuleConfig.parse(File('assets/rule_config.json').readAsStringSync()),
    );
    store = PrefsAlertStore();
    orkestrator = AlertOrchestrator(
      ruleEngine: engine,
      healthService: DemoHealthService(),
      notificationService: NoopNotificationService(),
      databaseHelper: store,
    );
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearPlatformBrightnessTestValue();
  });

  Future<void> pumpApp(WidgetTester tester, {double tinggi = 4000}) async {
    await tester.binding.setSurfaceSize(Size(430, tinggi));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      HealthAlertApp(
        orchestrator: orkestrator,
        healthService: orkestrator.healthService,
        store: store,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> bukaTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  /// Tone yang benar-benar dipakai shell aplikasi.
  ///
  /// Diambil dari elemen RootShell, bukan dari teks di dalam tab, karena
  /// IndexedStack menandai tab yang tidak terpilih sebagai offstage.
  AppTones tonesAktif(WidgetTester tester) =>
      AppTones.of(tester.element(find.byType(RootShell)));

  testWidgets('kartu Tampilan mengganti bahasa seluruh aplikasi', (
    tester,
  ) async {
    await pumpApp(tester);
    await bukaTab(tester, 'Profil');

    expect(find.text('Tampilan'), findsOneWidget);
    expect(find.text('Indonesia'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Ikuti sistem'), findsOneWidget);
    expect(find.text('Profil & Kalibrasi'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(AppSettings.locale, 'en');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppSettings.keyLocale), 'en');

    // Bukan hanya kartu ini — judul layar dan navbar ikut berganti tanpa restart.
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Profile & calibration'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Follow system'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);

    await bukaTab(tester, 'Home');
    expect(find.text('No check yet'), findsOneWidget);
    expect(find.text('Belum ada pemeriksaan'), findsNothing);

    await bukaTab(tester, 'Statistics');
    expect(find.text('Statistics'), findsWidgets);
    expect(find.text('No statistics yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pilihan bahasa sudah benar sejak frame pertama', (tester) async {
    await pumpApp(tester);
    await bukaTab(tester, 'Profil');
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    // Aplikasi dibangun ulang: tidak ada kedipan Indonesia di awal.
    await pumpApp(tester);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Beranda'), findsNothing);
    await bukaTab(tester, 'Home');
    expect(find.text('No check yet'), findsOneWidget);
  });

  testWidgets('pilihan tema gelap tersimpan dan mengalahkan perangkat', (
    tester,
  ) async {
    final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
    // Perangkat berpindah ke terang setelah pilihan dibuat — aplikasi harus
    // tetap gelap karena pengguna yang memilih, bukan sistem.
    dispatcher.platformBrightnessTestValue = Brightness.light;

    await pumpApp(tester);
    await bukaTab(tester, 'Profil');
    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();

    expect(AppSettings.tema, 'dark');
    expect(AppSettings.themeMode, ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppSettings.keyTema), 'dark');
    expect(tonesAktif(tester), AppTones.gelap);

    await pumpApp(tester);
    expect(tonesAktif(tester), AppTones.gelap);
    expect(
      Theme.of(tester.element(find.byType(RootShell))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('mode gelap: keempat tab tampil tanpa error', (tester) async {
    await AppSettings.setTema('dark');
    await pumpApp(tester);
    expect(tonesAktif(tester), AppTones.gelap);

    for (final tab in ['Beranda', 'Alerts', 'Statistik', 'Profil']) {
      await bukaTab(tester, tab);
      expect(tester.takeException(), isNull, reason: 'tab $tab error');
      expect(
        tonesAktif(tester),
        AppTones.gelap,
        reason: 'tab $tab masih terang',
      );
    }
    // Hanya tab terakhir yang onstage (IndexedStack), jadi judul yang dicek
    // di sini ya milik tab itu.
    expect(find.text('Profil & Kalibrasi'), findsOneWidget);
  });

  testWidgets('tema mengikuti perangkat selama pilihannya sistem', (
    tester,
  ) async {
    final dispatcher = TestWidgetsFlutterBinding.instance.platformDispatcher;
    dispatcher.platformBrightnessTestValue = Brightness.dark;
    await pumpApp(tester);

    expect(AppSettings.tema, 'system');
    expect(tonesAktif(tester), AppTones.gelap);

    dispatcher.platformBrightnessTestValue = Brightness.light;
    await pumpApp(tester);
    expect(tonesAktif(tester), AppTones.terang);
    expect(AppTones.terang.canvas, isNot(AppTones.gelap.canvas));
  });

  testWidgets('kode bahasa/tema tak dikenal jatuh ke nilai aman', (
    tester,
  ) async {
    await pumpApp(tester);
    await bukaTab(tester, 'Profil');

    await AppSettings.setLocale('de');
    await AppSettings.setTema('neon');
    await tester.pumpAndSettle();

    expect(AppSettings.locale, 'id');
    expect(AppSettings.tema, 'system');
    expect(find.text('Tampilan'), findsOneWidget);
    expect(find.text('Ikuti sistem'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
