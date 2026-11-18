import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show MethodCall, MethodChannel, MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:health_alert/models/sumber_riset.dart';
import 'package:health_alert/screens/sources_screen.dart';
import 'package:health_alert/services/rule_config.dart';

import 'uji_app.dart';

/// Layar Sumber adalah satu-satunya tempat aplikasi mengaku dari mana angka
/// klinisnya datang, jadi tesnya menjaga dua hal: tidak ada rujukan ber-URL
/// palsu yang masuk konfigurasi, dan tidak ada kutipan yang sudah terbukti
/// tidak ada yang dibiarkan tersisa di file konfigurasi.
void main() {
  late RuleConfig config;

  setUp(
    () => config = RuleConfig.parse(
      File('assets/rule_config.json').readAsStringSync(),
    ),
  );

  List<SumberRiset> semua() =>
      config.sumberRiset.expand((k) => k.sumber).toList();

  testWidgets('sumber_riset: URL nyata, tanpa duplikat, status dikenal', (
    tester,
  ) async {
    final sumber = semua();
    expect(config.sumberRiset.length, 8);
    expect(sumber.length, greaterThanOrEqualTo(45));

    final url = <String>{};
    for (final s in sumber) {
      // Hanya satu entri yang boleh tanpa tautan: dataset simulasi di repo ini.
      if (s.url.isEmpty) {
        expect(s.terbitan, 'kode lokal', reason: '${s.judul} tanpa alasan');
        continue;
      }
      expect(
        s.url.startsWith('https://'),
        isTrue,
        reason: '${s.judul} bukan HTTPS: ${s.url}',
      );
      expect(Uri.parse(s.url).hasAbsolutePath, isTrue, reason: s.url);
      expect(url, isNot(contains(s.url)), reason: 'URL ganda: ${s.url}');
      url.add(s.url);
    }

    expect(sumber.map((s) => s.status).toSet(), {'terverifikasi', 'perlu_cek'});
    // Tidak ada rujukan yang memuat angka tapi tidak menetapkan apa pun.
    expect(sumber.every((s) => s.menetapkan.isNotEmpty), isTrue);
    for (final kelompok in config.sumberRiset) {
      expect(kelompok.jumlah, greaterThanOrEqualTo(3), reason: kelompok.judul);
    }
  });

  test('kutipan yang gagal diverifikasi tidak dipakai sebagai sumber', () {
    // Yang dijaga: nama yang tidak terbukti ada tidak boleh menyandarkan
    // angka. Catatan audit yang menyebutnya sebagai "sudah diganti" boleh,
    // karena justru itu yang membuat perubahan ini bisa ditelusuri.
    final kutipan = StringBuffer();
    final literatur = config.rawLiteratur;
    for (final blok in literatur.values) {
      kutipan.write((blok as Map)['sumber'] ?? '');
      kutipan.write('\n');
    }
    for (final kelompok in config.sumberRiset) {
      for (final s in kelompok.sumber) {
        kutipan.write('${s.judul} ${s.penulis} ${s.terbitan}\n');
      }
    }
    final isi = kutipan.toString();
    for (final nama in [
      'Zhu 2020',
      'Egger 2016',
      'ACSM 2021',
      'Braat 1998',
      'AECOPD/IBCC',
    ]) {
      expect(isi, isNot(contains(nama)), reason: '$nama tidak punya sumber');
    }
    // Penggantinya memang ada.
    for (final nama in ['Weiler', 'Garber', 'Van Gerven 2012', 'Farmer']) {
      expect(isi, contains(nama), reason: 'pengganti $nama hilang');
    }
  });

  testWidgets('layar Sumber menampilkan kelompok, kredit, dan angkanya', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 40000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ujiApp(
        SourcesScreen(config: config),
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sumber & Rujukan'), findsOneWidget);
    expect(find.text('52 rujukan'), findsOneWidget);
    expect(find.text('Oksigen & napas'), findsOneWidget);
    expect(find.text('Sumber data & perangkat'), findsOneWidget);
    expect(
      find.text(
        '2024 GOLD Report: Global Strategy for the Diagnosis, '
        'Management and Prevention of COPD',
      ),
      findsOneWidget,
    );
    expect(find.textContaining("O'Driscoll BR"), findsOneWidget);
    expect(
      find.text('SpO2 kritis 88% (padanan ambang LTOT PaO2<=55 mmHg)'),
      findsOneWidget,
    );
    expect(find.text('tautan perlu dicek di browser'), findsWidgets);

    // Layar ini murni baca: tidak ada satu pun tempat untuk mengetik.
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('mengetuk rujukan membuka tautan milik rujukan itu sendiri', (
    tester,
  ) async {
    // url_launcher tidak punya plugin di lingkungan test, jadi channel-nya
    // dimock — yang dijaga di sini adalah URL mana yang dikirim.
    final dibuka = <String>[];
    _pasangLauncher(tester, (call) async {
      if (call.method == 'launch') {
        dibuka.add((call.arguments as Map)['url'] as String);
      }
      return true;
    });

    await tester.binding.setSurfaceSize(const Size(430, 40000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ujiApp(SourcesScreen(config: config)));
    await tester.pumpAndSettle();

    await tester.tap(
      find.text('An Overview of Heart Rate Variability Metrics and Norms'),
    );
    await tester.pumpAndSettle();

    expect(dibuka, ['https://pmc.ncbi.nlm.nih.gov/articles/PMC5624990/']);
    expect(find.byType(SnackBar), findsNothing);
    // Entri tanpa tautan (dataset lokal) tetap tampil, hanya tidak bisa dibuka.
    expect(
      find.text('Dataset simulasi 28 hari (benih riwayat)'),
      findsOneWidget,
    );
  });

  testWidgets(
    'kegagalan membuka tautan dilaporkan, bukan menjatuhkan aplikasi',
    (tester) async {
      _pasangLauncher(
        tester,
        (call) async => throw MissingPluginException('tidak ada browser'),
      );

      await tester.binding.setSurfaceSize(const Size(430, 40000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ujiApp(SourcesScreen(config: config)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('AQI Basics'));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Tautan tidak bisa dibuka'),
        findsOneWidget,
        reason: 'tap pada tautan harus berakhir dengan pesan, bukan exception',
      );
    },
  );
}

/// Meniru plugin url_launcher; `null` handler melepas mock lagi.
void _pasangLauncher(
  WidgetTester tester,
  Future<Object?>? Function(MethodCall) handler,
) {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, handler);
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
}
