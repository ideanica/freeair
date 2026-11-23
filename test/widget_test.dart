import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_alert/config/app_config.dart';
import 'package:health_alert/main.dart';
import 'package:health_alert/models/condition_result.dart';
import 'package:health_alert/models/health_profile.dart';
import 'package:health_alert/models/health_sample.dart';
import 'package:health_alert/models/sensor_snapshot.dart';
import 'package:health_alert/screens/history_screen.dart';
import 'package:health_alert/screens/home_screen.dart';
import 'package:health_alert/screens/level_style.dart';
import 'package:health_alert/screens/profile_screen.dart';
import 'package:health_alert/screens/sources_screen.dart';
import 'package:health_alert/services/air_quality_service.dart';
import 'package:health_alert/services/alert_orchestrator.dart';
import 'package:health_alert/services/database_helper_prefs.dart';
import 'package:health_alert/services/health_service_demo.dart';
import 'package:health_alert/services/notification_service_noop.dart';
import 'package:health_alert/services/rule_config.dart';
import 'package:health_alert/services/rule_engine.dart';
import 'package:health_alert/services/weather_service.dart';

import 'uji_app.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sensor yang sengaja tidak mengembalikan apa pun.
///
/// Dipakai untuk menguji kontrak "tanpa data = tidak dinilai": sensor yang
/// absen tidak boleh dipalsukan jadi AMAN, dan ambang personal tidak boleh
/// dihitung dari riwayat kosong.
class SensorHampa implements HealthService {
  @override
  String get sourceLabel => 'Tanpa sensor';

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<SensorSnapshot> bacaSnapshot({
    Duration jendela = const Duration(hours: 24),
  }) async => SensorSnapshot(at: DateTime.now());

  @override
  Future<List<HealthSample>> benihRiwayat() async => const [];
}

/// Notifikasi yang hanya mencatat.
///
/// Dipakai untuk membuktikan siklus benar-benar memanggil jalur notifikasi:
/// alert terkirim sekali (dedup) dan pengingat siklus berikutnya ditata ulang.
class NotifikasiPerekam implements NotificationService {
  final alert = <ConditionResult>[];
  final jendela = <Duration>[];
  var pembatalan = 0;

  @override
  Future<void> init() async {}

  @override
  Future<void> showAlert(ConditionResult result) async => alert.add(result);

  @override
  Future<void> jadwalkanPengingat(Duration jendela) async =>
      this.jendela.add(jendela);

  @override
  Future<void> batalkanPengingat() async => pembatalan++;
}

void main() {
  late RuleEngine engine;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    engine = RuleEngine(
      RuleConfig.parse(File('assets/rule_config.json').readAsStringSync()),
    );
  });

  ThemeData appTheme() => temaAplikasi();

  String dua(int n) => n.toString().padLeft(2, '0');

  /// BMKG membalas satu prakiraan pada jam sekarang. `suhu: null` meniru
  /// balasan kosong — jalur yang membuat alergi dingin TIDAK_DIEVALUASI.
  WeatherService cuacaMock({double? suhu, double? rh, double? angin}) {
    final sekarang = DateTime.now();
    final stamp =
        '${sekarang.year}-${dua(sekarang.month)}-${dua(sekarang.day)} '
        '${dua(sekarang.hour)}:${dua(sekarang.minute)}:00';
    return WeatherService(
      client: MockClient((_) async {
        if (suhu == null) return http.Response('{"data":[]}', 200);
        return http.Response(
          jsonEncode({
            'data': [
              {
                'cuaca': [
                  [
                    {
                      't': suhu,
                      'hu': rh ?? 60,
                      'ws': angin ?? 2,
                      'weather_desc': 'Cerah Berawan',
                      'local_datetime': stamp,
                    },
                  ],
                ],
              },
            ],
          }),
          200,
        );
      }),
    );
  }

  /// Tidak dipakai bila BMKG tidak mengirim koordinat, tapi tetap dimock agar
  /// test tidak menyentuh jaringan sungguhan.
  AirQualityService udaraMock() => AirQualityService(
    client: MockClient((_) async => http.Response('{}', 200)),
  );

  AlertOrchestrator buatOrkestrator({
    required HealthService sensor,
    double? suhu,
    double? rh,
    double? angin,
    PrefsAlertStore? store,
  }) => AlertOrchestrator(
    ruleEngine: engine,
    healthService: sensor,
    weatherService: cuacaMock(suhu: suhu, rh: rh, angin: angin),
    airQualityService: udaraMock(),
    notificationService: NoopNotificationService(),
    databaseHelper: store ?? PrefsAlertStore(),
  );

  /// Semua layar adalah ListView; permukaan uji yang tinggi membangun seluruh
  /// item sehingga assertion tidak perlu menggulir manual.
  Future<void> pumpLayar(
    WidgetTester tester,
    Widget layar, {
    double tinggi = 5200,
  }) async {
    await tester.binding.setSurfaceSize(Size(430, tinggi));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ujiApp(layar, theme: appTheme()));
    await tester.pumpAndSettle();
  }

  Future<void> bukaBeranda(
    WidgetTester tester,
    AlertOrchestrator orkestrator,
  ) async {
    await pumpLayar(
      tester,
      HomeScreen(
        orchestrator: orkestrator,
        healthService: orkestrator.healthService,
      ),
    );
  }

  Future<void> jalanCek(WidgetTester tester) async {
    await tester.tap(find.text('Sinkron & Cek'));
    await tester.pumpAndSettle();
  }

  /// Tidak ada satu pun tempat pengguna boleh mengetik angka klinis.
  void takAdaInputManual() {
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Input manual'), findsNothing);
    expect(find.text('SpO2 (%)'), findsNothing);
    expect(find.text('Waspada (bpm)'), findsNothing);
    expect(find.text('Ambang suhu alergi'), findsNothing);
    expect(find.text('Sudah dikonfirmasi'), findsNothing);
    expect(find.text('Hari siklus manual'), findsNothing);
  }

  testWidgets('beranda: tanpa input manual, hasil dari sensor + BMKG', (
    tester,
  ) async {
    await bukaBeranda(
      tester,
      buatOrkestrator(sensor: DemoHealthService(), suhu: 27.0),
    );

    expect(find.textContaining('Selamat'), findsOneWidget);
    // Spanduk mode observasi hanya tampil kalau notifikasi sistem dimatikan;
    // build Android ini shipped dengan ENABLE_NOTIFICATIONS = true.
    expect(find.textContaining('Mode Observasi Aktif'), findsNothing);
    expect(find.text('Belum ada pemeriksaan'), findsOneWidget);
    expect(find.text('Menunggu data sensor pertama'), findsOneWidget);
    takAdaInputManual();

    await jalanCek(tester);

    expect(find.text('Bronkitis'), findsOneWidget);
    expect(find.text('Anxiety'), findsOneWidget);
    expect(find.text('Alergi Dingin'), findsOneWidget);
    // Skor tampil sebagai gauge cincin di kartu hasil, plus ringkasan singkat
    // di kartu paling atas.
    expect(find.byType(ScoreGauge), findsNWidgets(3));
    expect(find.text('dari 100'), findsNothing);
    // Sumber dan sensor kini ada di lembar "Pemantauan", bukan di Beranda.
    await tester.tap(find.text('Pemantauan'));
    await tester.pumpAndSettle();
    expect(
      find.text('Sumber otomatis: Data simulasi + BMKG + Open-Meteo'),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    // Ikon di appbar memakai jalur paksa-refresh: tidak membaca cache cuaca.
    await tester.tap(find.byIcon(Icons.sync_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Bronkitis'), findsOneWidget);
    takAdaInputManual();
  });

  testWidgets('beranda: ambang dihitung dari riwayat 28 hari, bukan diketik', (
    tester,
  ) async {
    await bukaBeranda(
      tester,
      buatOrkestrator(sensor: DemoHealthService(), suhu: 27.0),
    );
    await jalanCek(tester);

    // Ringkasan ambang tetap di Beranda; detailnya dibuka dari kartu Pemantauan.
    expect(find.textContaining('ambang dingin PERSONAL'), findsOneWidget);
    await tester.tap(find.text('Pemantauan'));
    await tester.pumpAndSettle();
    expect(find.text('Ambang yang dipakai siklus ini'), findsOneWidget);
    expect(
      find.textContaining('Semua angka dihitung dari 28 hari riwayat sensor'),
      findsOneWidget,
    );
    expect(find.text('Ambang suhu dingin'), findsOneWidget);
    expect(
      find.textContaining('Setiap angka punya kutipan jurnal'),
      findsOneWidget,
    );
  });

  testWidgets(
    'beranda: tanpa suhu lingkungan, alergi dingin TIDAK_DIEVALUASI',
    (tester) async {
      await bukaBeranda(tester, buatOrkestrator(sensor: SensorHampa()));
      await jalanCek(tester);

      expect(find.text(AlertLevels.tidakDievaluasi), findsOneWidget);
      expect(find.text(AlertLevels.aman), findsNWidgets(2));
      // Tidak ada satu pun sinyal tubuh → keyakinan rendah, bukan data rapi.
      // Keyakinan rendah dirangkum di kartu kalibrasi ("keyakinan LOW").
      expect(find.textContaining('keyakinan LOW'), findsOneWidget);
      expect(find.textContaining('Level tertinggi: AMAN'), findsOneWidget);
      // Riwayat kosong → ambang masih murni literatur.
      expect(find.textContaining('ambang dingin LITERATUR'), findsOneWidget);

      // Alasan "tidak dievaluasi" ada di lembar kondisi, bukan di Beranda.
      await tester.tap(find.text('Kondisi saat ini'));
      await tester.pumpAndSettle();
      expect(find.text('Data suhu lingkungan tidak tersedia'), findsOneWidget);
    },
  );

  testWidgets('beranda: cuaca dingin saja sudah bisa memicu alergi', (
    tester,
  ) async {
    await bukaBeranda(
      tester,
      buatOrkestrator(sensor: SensorHampa(), suhu: 5.0, rh: 25.0, angin: 9.0),
    );
    await jalanCek(tester);

    // 30 sangat dingin + 10 udara kering + 15 angin bahaya, tanpa sensor tubuh.
    // Skor 55 kini hanya tampil di gauge kartu hasil; kartu atas menampilkan
    // AQI, bukan skor kondisi.
    expect(find.text('55'), findsOneWidget);
    expect(find.text(AlertLevels.perhatian), findsOneWidget);
    // Di Beranda kalimat pemicu hanya muncul di banner; versi lengkapnya
    // ada di lembar "Kondisi saat ini".
    expect(
      find.text(
        'Suhu 5°C — sangat dingin, 13.0°C di bawah band literatur 18.0°C',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Kondisi saat ini'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Suhu 5°C — sangat dingin, 13.0°C di bawah band literatur 18.0°C',
      ),
      findsNWidgets(2),
    );
    expect(find.textContaining('ambang dingin LITERATUR'), findsOneWidget);
  });

  testWidgets('beranda: hasil siklus latar tampil tanpa menekan tombol', (
    tester,
  ) async {
    final orkestrator = buatOrkestrator(
      sensor: SensorHampa(),
      suhu: 5.0,
      rh: 25.0,
      angin: 9.0,
    );
    await bukaBeranda(tester, orkestrator);

    expect(find.text('Menunggu data sensor pertama'), findsOneWidget);

    // Persis jalur main(): siklus awal dan timer 15 menit berjalan di luar UI.
    await orkestrator.runCycle();
    await tester.pumpAndSettle();

    expect(find.text('Menunggu data sensor pertama'), findsNothing);
    expect(find.textContaining('Level tertinggi: PERHATIAN'), findsOneWidget);
    expect(find.text('Alergi Dingin'), findsOneWidget);
  });

  testWidgets('siklus mengirim alert lalu menata ulang pengingat berikutnya', (
    tester,
  ) async {
    final notifikasi = NotifikasiPerekam();
    final orkestrator = AlertOrchestrator(
      ruleEngine: engine,
      healthService: SensorHampa(),
      weatherService: cuacaMock(suhu: 5.0, rh: 25.0, angin: 9.0),
      airQualityService: udaraMock(),
      notificationService: notifikasi,
      databaseHelper: PrefsAlertStore(),
    );

    await orkestrator.runCycle();
    expect(notifikasi.alert.map((a) => a.kondisi), contains('Alergi Dingin'));
    expect(notifikasi.jendela, [
      const Duration(minutes: AppConfig.CYCLE_INTERVAL_MINUTES + 3),
    ]);
    expect(notifikasi.pembatalan, 1);

    await orkestrator.runCycle();
    // Level sama di dalam jendela dedup: alert tidak boleh menumpuk, tapi
    // pengingat siklus berikutnya tetap digeser ke menit ke-18 dari sekarang.
    expect(notifikasi.alert.length, 1);
    expect(notifikasi.jendela.length, 2);
    expect(notifikasi.pembatalan, 2);
  });

  testWidgets('riwayat: ikut terisi saat siklus latar selesai', (tester) async {
    final store = PrefsAlertStore();
    final orkestrator = buatOrkestrator(
      sensor: SensorHampa(),
      suhu: 5.0,
      rh: 25.0,
      angin: 9.0,
      store: store,
    );

    await orkestrator.runCycle();
    await pumpLayar(tester, HistoryScreen(store: store, pengamat: orkestrator));

    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('HARI INI'), findsOneWidget);
    expect(find.text('Bronkitis'), findsOneWidget);

    await orkestrator.runCycle();
    await tester.pumpAndSettle();

    expect(find.text('Bronkitis'), findsNWidgets(2));
  });

  testWidgets('riwayat: detail menunjukkan pemicu dan jejak audit', (
    tester,
  ) async {
    final store = PrefsAlertStore();
    final orkestrator = buatOrkestrator(
      sensor: SensorHampa(),
      suhu: 5.0,
      rh: 25.0,
      angin: 9.0,
      store: store,
    );
    await orkestrator.runCycle();
    await pumpLayar(tester, HistoryScreen(store: store));

    await tester.tap(find.text('Alergi Dingin'));
    await tester.pumpAndSettle();

    expect(
      find.text('Alergi Dingin • ${AlertLevels.perhatian}'),
      findsOneWidget,
    );
    expect(find.text('Skor 55/100 — keyakinan LOW'), findsOneWidget);
    // Di dialog riwayat kalimat pemicu hanya muncul sekali.
    expect(
      find.text(
        'Suhu 5°C — sangat dingin, 13.0°C di bawah band literatur 18.0°C',
      ),
      findsOneWidget,
    );
    // Yang diaudit adalah bacaan lingkungan, bukan angka yang diketik pengguna.
    expect(find.textContaining('Suhu 5°C • Angin 9 m/s'), findsOneWidget);

    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    expect(find.text('Tutup'), findsNothing);
  });

  testWidgets('riwayat: AMAN tanpa pemicu tetap tercatat untuk kalibrasi', (
    tester,
  ) async {
    final store = PrefsAlertStore();
    await buatOrkestrator(sensor: SensorHampa(), store: store).runCycle();
    await pumpLayar(tester, HistoryScreen(store: store));

    await tester.tap(find.text('Bronkitis'));
    await tester.pumpAndSettle();

    expect(find.text('Skor 0/100 — keyakinan LOW'), findsOneWidget);
    expect(find.text('Tidak ada pemicu yang tercatat.'), findsOneWidget);
  });

  testWidgets('profil: hanya kondisi dan wilayah yang bisa diubah', (
    tester,
  ) async {
    final orkestrator = buatOrkestrator(
      sensor: DemoHealthService(),
      suhu: 27.0,
    );
    await orkestrator.runCycle();
    await pumpLayar(
      tester,
      ProfileScreen(orchestrator: orkestrator),
      tinggi: 4800,
    );

    expect(find.text('Profil & Kalibrasi'), findsOneWidget);
    expect(find.text('Kondisi yang dipantau'), findsOneWidget);
    expect(find.text('Sumber data otomatis'), findsOneWidget);
    expect(find.text('Ambang yang dipakai sekarang'), findsOneWidget);
    // Dua kolom saja: nama dan kode wilayah. Tidak ada ambang yang diketik.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byType(Slider), findsNothing);
    expect(find.text('Ambang suhu alergi'), findsNothing);
    expect(
      find.textContaining('Tidak ada ambang yang diisi manual'),
      findsOneWidget,
    );

    // Detail kalibrasi ada di lembar yang dibuka dari kartu ringkas.
    await tester.tap(find.text('Ambang yang dipakai sekarang'));
    await tester.pumpAndSettle();
    expect(find.text('Kecukupan data riwayat'), findsOneWidget);
    expect(find.text('Sumber angka (jurnal & panduan)'), findsOneWidget);
    expect(find.textContaining('GOLD 2024'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Anxiety'));
    // Tombol simpan di kepala halaman selalu terlihat; tombol besar di ujung
    // daftar baru ter-render setelah daftar kutipan jurnalnya terlewati.
    await tester.tap(find.widgetWithText(FilledButton, 'Simpan Profil'));
    await tester.pumpAndSettle();

    expect(
      find.text('Profil disimpan dan dipakai di siklus berikutnya.'),
      findsOneWidget,
    );
    final tersimpan = await HealthProfile.load();
    expect(tersimpan, isNotNull);
    expect(tersimpan!.kondisi, ['Bronkitis Kronis', 'Alergi Dingin']);
    expect(tersimpan.bmkgKodeWilayah, isNotEmpty);
  });

  testWidgets('profil: menolak kondisi kosong tanpa menyimpan', (tester) async {
    await pumpLayar(
      tester,
      ProfileScreen(orchestrator: buatOrkestrator(sensor: SensorHampa())),
    );

    for (final kondisi in ['Bronkitis Kronis', 'Anxiety', 'Alergi Dingin']) {
      await tester.tap(find.text(kondisi));
    }
    await tester.tap(find.text('Simpan Profil'));
    await tester.pumpAndSettle();

    expect(
      find.text('Pilih minimal satu kondisi untuk dipantau.'),
      findsOneWidget,
    );
    expect(await HealthProfile.load(), isNull);
  });

  test('gaya level dipakai seragam di seluruh UI', () {
    expect(
      LevelStyle.colorOf(AlertLevels.aman),
      isNot(LevelStyle.colorOf(AlertLevels.bahaya)),
    );
    expect(
      LevelStyle.iconOf(AlertLevels.tidakDievaluasi),
      Icons.help_outline_rounded,
    );
    expect(KondisiStyle.iconOf('Alergi Dingin'), Icons.ac_unit_rounded);
    expect(AlertLevels.levelButuhAlert(AlertLevels.tidakDievaluasi), isFalse);
  });

  testWidgets('navbar punya tab Statistik dan menampilkannya', (tester) async {
    final store = PrefsAlertStore();
    final orkestrator = buatOrkestrator(
      sensor: DemoHealthService(),
      suhu: 27.0,
      store: store,
    );
    await orkestrator.runCycle();

    await tester.binding.setSurfaceSize(const Size(430, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ujiApp(
        RootShell(
          orchestrator: orkestrator,
          healthService: orkestrator.healthService,
          store: store,
        ),
        theme: appTheme(),
      ),
    );
    await tester.pumpAndSettle();

    final urutanTab = ['Beranda', 'Alerts', 'Statistik', 'Profil'];
    for (final tab in urutanTab) {
      expect(find.text(tab), findsOneWidget, reason: 'tab $tab hilang');
    }
    // Kiri ke kanan navbar = urutan yang diminta.
    final tengah = urutanTab
        .map((t) => tester.getCenter(find.text(t)).dx)
        .toList();
    for (var i = 1; i < tengah.length; i++) {
      expect(
        tengah[i],
        greaterThan(tengah[i - 1]),
        reason: 'tab ${urutanTab[i]} tidak berada di kanan ${urutanTab[i - 1]}',
      );
    }

    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();

    expect(find.text('Total cek'), findsOneWidget);
    expect(find.text('Tren 7 hari'), findsOneWidget);
    expect(find.text('Distribusi level'), findsOneWidget);
    // Pindah tab tidak boleh menghapus hasil siklus yang sudah ada.
    await tester.tap(find.text('Beranda'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Selamat'), findsOneWidget);
  });

  testWidgets('sumber dibuka dari kartu di Profil', (tester) async {
    final store = PrefsAlertStore();
    final orkestrator = buatOrkestrator(
      sensor: DemoHealthService(),
      suhu: 27.0,
      store: store,
    );

    await tester.binding.setSurfaceSize(const Size(430, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ujiApp(
        RootShell(
          orchestrator: orkestrator,
          healthService: orkestrator.healthService,
          store: store,
        ),
        theme: appTheme(),
        routes: {'/sources': (_) => SourcesScreen(config: orkestrator.config)},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sumber & Rujukan'));
    await tester.pumpAndSettle();

    expect(find.text('Sumber & Rujukan'), findsWidgets);
    expect(find.text('Oksigen & napas'), findsOneWidget);
    expect(find.text('52 rujukan'), findsOneWidget);
  });

  testWidgets('layar sempit: kartu ringkas tidak meluber', (tester) async {
    final store = PrefsAlertStore();
    final orkestrator = buatOrkestrator(
      sensor: DemoHealthService(),
      suhu: 27.0,
      store: store,
    );
    await orkestrator.runCycle();

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ujiApp(
        RootShell(
          orchestrator: orkestrator,
          healthService: orkestrator.healthService,
          store: store,
        ),
        theme: appTheme(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Lembar detail kondisi dan pemantauan juga harus muat di layar ponsel.
    await tester.tap(find.text('Kondisi saat ini'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Pemantauan'), 250);
    await tester.tap(find.text('Pemantauan'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
