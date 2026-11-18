import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_alert/l10n/app_settings.dart';
import 'package:health_alert/l10n/l10n.dart';
import 'package:health_alert/l10n/table_core.dart';
import 'package:health_alert/l10n/table_engine.dart';
import 'package:health_alert/l10n/table_history.dart';
import 'package:health_alert/l10n/table_home.dart';
import 'package:health_alert/l10n/table_profile.dart';
import 'package:health_alert/l10n/table_sources.dart';
import 'package:health_alert/models/alert_record.dart';
import 'package:health_alert/models/condition_result.dart';
import 'package:health_alert/models/pemicu.dart';
import 'package:health_alert/services/baseline_engine.dart';
import 'package:health_alert/services/rule_config.dart';
import 'package:health_alert/services/threshold_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Menjaga dua hal: kamus id/en benar-benar sepasang, dan kalimat pemicu serta
/// provenance ambang dirakit ulang saat ditampilkan — jadi baris yang sama
/// bisa dibaca dalam bahasa mana pun, termasuk baris yang sudah tersimpan.
void main() {
  // AppSettings.load() membaca bahasa perangkat lewat WidgetsBinding, jadi
  // binding test harus ada walau kelompok di bawah tidak memompa widget.
  TestWidgetsFlutterBinding.ensureInitialized();

  final config = RuleConfig.parse(
    File('assets/rule_config.json').readAsStringSync(),
  );
  final resolver = ThresholdResolver(config, BaselineEngine(config));
  final sekarang = DateTime(2026, 11, 5, 10);

  // Sama dengan komposisi di lib/l10n/l10n.dart.
  final kamusId = <String, String>{
    ...idCore,
    ...idEngine,
    ...idHome,
    ...idHistory,
    ...idProfile,
    ...idSources,
  };
  final kamusEn = <String, String>{
    ...enCore,
    ...enEngine,
    ...enHome,
    ...enHistory,
    ...enProfile,
    ...enSources,
  };
  final polaPlaceholder = RegExp(r'\{([a-zA-Z0-9_]+)\}');
  Set<String> placeholder(String teks) =>
      polaPlaceholder.allMatches(teks).map((m) => m[1]!).toSet();

  group('kamus id dan en sepasang', () {
    test('tidak ada kunci yang kehilangan padanan', () {
      expect(
        kamusEn.keys.toSet().difference(kamusId.keys.toSet()),
        isEmpty,
        reason: 'kunci en tanpa padanan id',
      );
      expect(
        kamusId.keys.toSet().difference(kamusEn.keys.toSet()),
        isEmpty,
        reason: 'kunci id tanpa padanan en',
      );
      expect(kamusId.length, greaterThan(200));
    });

    test('placeholder {nama} identik di kedua bahasa', () {
      for (final kunci in kamusId.keys) {
        expect(
          placeholder(kamusEn[kunci]!),
          placeholder(kamusId[kunci]!),
          reason: 'placeholder beda di kunci $kunci',
        );
      }
    });

    test('tidak ada entri kamus yang kosong', () {
      for (final e in {...kamusId, ...kamusEn}.entries) {
        expect(e.value.trim(), isNotEmpty, reason: 'kunci ${e.key} kosong');
      }
    });
  });

  group('pemicu terstruktur bisa dirender ulang', () {
    test('suhu dingin: bahasa berbeda, kode dan angkanya tetap sama', () {
      const p = Pemicu('pemicu.dingin.dingin', {
        'suhu': '5',
        'sumber': '@pemicu.ambang.literatur',
        'v': '18.0',
        'n': '0',
      });
      expect(
        L10n.id.pemicu(p),
        'Suhu 5°C — dingin, di bawah band literatur 18.0°C',
      );
      expect(
        L10n.en.pemicu(p),
        'Temperature 5°C — cold, below literature band 18.0°C',
      );
    });

    test('status SpO2 bersarang ikut berganti bahasa', () {
      const p = Pemicu('pemicu.spo2.hipoksemia', {
        'spo2': '88',
        'n': '3',
        'status': '@pemicu.status.beruntun',
      });
      expect(L10n.id.pemicu(p), 'SpO2 88% — hipoksemia (3 pembacaan beruntun)');
      expect(L10n.en.pemicu(p), 'SpO2 88% — hypoxaemia (3 readings in a row)');
    });

    test('argumen bersarang yang dalam tidak membuat render gagal', () {
      final teks = L10n.id.pemicu(
        const Pemicu('pemicu.dingin.sangat', {
          'suhu': '5',
          'delta': '13.0',
          'sumber': '@pemicu.ambang.personal',
          'v': '18.0',
          'n': '3',
        }),
      );
      expect(teks, contains('ambang personal 18.0°C (3 reaksi tercatat)'));
    });

    test('pemicu tak dikenal menampilkan kodenya, bukan crash', () {
      expect(
        L10n.id.pemicu(const Pemicu('pemicu.tidak.ada')),
        'pemicu.tidak.ada',
      );
    });

    test('baris lama tanpa pemicu tetap menampilkan teks yang tersimpan', () {
      final lama = AlertRecord(
        timestamp: sekarang,
        kondisi: 'Alergi Dingin',
        skor: 60,
        level: AlertLevels.perhatian,
        confidence: 'HIGH',
        intervensi: '',
        alasan: const ['Suhu 5°C — dingin (kalimat lama)'],
      );
      expect(lama.tampil(L10n.en), lama.alasan);
      expect(lama.tampil(L10n.id), lama.alasan);
    });

    test('pemicu yang disimpan ke database menghasilkan kalimat yang sama', () {
      const asli = Pemicu('pemicu.hr.deviasi_bahaya', {
        'hr': '92',
        'delta': '14',
        'baseline': '61',
      });
      final pulih = Pemicu.fromJson(jsonDecode(jsonEncode(asli.toJson())));
      expect(pulih.arg, asli.arg);
      expect(L10n.en.pemicu(pulih), 'HR 92 bpm — 14 bpm above baseline 61 bpm');
    });
  });

  group('provenance ambang ikut bahasa', () {
    test('label, detail, dan kutipan setiap ambang ada padanan en', () {
      final provenance = resolver
          .resolve(samples: const [], sekarang: sekarang)
          .provenance;
      expect(provenance, isNotEmpty);
      for (final info in provenance) {
        expect(L10n.en.t(info.labelKey), isNot(info.labelKey));
        if (info.detailKey != null) {
          expect(L10n.en.t(info.detailKey!), isNot(info.detailKey));
        }
        expect(
          config.sumberTeks(info.sumberKey, locale: 'en'),
          isNot('-'),
          reason: 'sumber_en belum diisi untuk ${info.sumberKey}',
        );
      }
    });

    test('satuan Indonesia dipetakan ke padanan Inggris', () {
      expect(L10n.id.satuan(' x/mnt'), ' x/mnt');
      expect(L10n.en.satuan(' x/mnt'), ' /min');
      expect(L10n.en.satuan('%poin'), '% points');
      expect(L10n.en.satuan('°C'), '°C');
    });

    test('laporan kecukupan data memakai label dan satuan bahasa aktif', () {
      final baseline = resolver
          .resolve(samples: const [], sekarang: sekarang)
          .baseline;
      final id = BaselineEngine(config).laporanKecukupanData(baseline);
      final en = BaselineEngine(config)
          .laporanKecukupanData(baseline, locale: 'en');
      expect(id.first, endsWith('hari'));
      expect(en.first, endsWith('days'));
    });
  });

  group('rule_config.json membawa varian English', () {
    test('setiap blok literatur punya sumber_en', () {
      for (final e in config.rawLiteratur.entries) {
        expect(
          (e.value as Map)['sumber_en'],
          isA<String>(),
          reason: 'blok ${e.key} belum ada sumber_en',
        );
      }
    });

    test('saran tindakan en memakai placeholder yang sama', () {
      for (final kondisi in ['Bronkitis', 'Anxiety', 'Alergi Dingin']) {
        for (final level in AlertLevels.urutan) {
          final id = config.intervensi(kondisi, level);
          final en = config.intervensi(kondisi, level, locale: 'en');
          expect(en, isA<String>(), reason: '$kondisi.$level hilang');
          expect(placeholder(en), placeholder(id), reason: '$kondisi.$level');
        }
      }
    });

    // Yang diuji adalah KEHADIRAN varian English, bukan perbedaannya dengan
    // teks Indonesia: judul jurnal, satuan, dan nama paket memang sama di
    // kedua bahasa, dan itu bukan bug.
    test('setiap kelompok dan rujukan punya varian English', () {
      for (final kelompok in config.sumberRiset) {
        expect(
          kelompok.judulEn,
          isNotNull,
          reason: '${kelompok.judul} tanpa judul_en',
        );
        if (kelompok.deskripsi.isNotEmpty) {
          expect(
            kelompok.deskripsiEn,
            isNotNull,
            reason: '${kelompok.judul} tanpa deskripsi_en',
          );
        }
        for (final s in kelompok.sumber) {
          expect(
            s.menetapkanEn,
            isNotEmpty,
            reason: '${s.judul} tanpa menetapkan_en',
          );
          if (s.catatan != null) {
            expect(
              s.catatanEn,
              isNotNull,
              reason: '${s.judul} tanpa catatan_en',
            );
          }
        }
      }
    });

    test('label metrik dinamis punya padanan en', () {
      for (final e in config.metrikDinamis.entries) {
        expect(
          (e.value as Map)['label_en'],
          isA<String>(),
          reason: 'metrik ${e.key} belum ada label_en',
        );
        expect(
          ((e.value as Map)['label_en'] as String).trim(),
          isNotEmpty,
          reason: 'label_en metrik ${e.key} kosong',
        );
      }
    });
  });

  group('AppSettings menyimpan pilihan bahasa dan tema', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(() async {
      await AppSettings.setLocale('id');
      await AppSettings.setTema('system');
    });

    test('bahasa perangkat dipakai selama pengguna belum memilih', () async {
      await AppSettings.load();
      // Lingkungan test berpura-pura jadi perangkat en-US; di HP Indonesia
      // jalur yang sama menghasilkan 'id'.
      expect(AppSettings.locale, 'en');
      expect(AppSettings.tema, 'system');
      expect(AppSettings.themeMode, ThemeMode.system);
      expect(L10n.untuk(null).kode, AppSettings.locale);
      expect(L10n.untuk('de').kode, AppSettings.locale);
    });

    test('pilihan disimpan dan memberi tahu pendengar', () async {
      await AppSettings.load();
      var notifikasi = 0;
      void dengar() => notifikasi++;
      AppSettings.perubahan.addListener(dengar);
      final awal = AppSettings.perubahan.value;

      await AppSettings.setLocale('en');
      await AppSettings.setTema('dark');

      expect(AppSettings.locale, 'en');
      expect(AppSettings.themeMode, ThemeMode.dark);
      expect(notifikasi, 2);
      expect(AppSettings.perubahan.value, greaterThan(awal));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ui.locale'), 'en');
      expect(prefs.getString('ui.theme'), 'dark');

      AppSettings.perubahan.removeListener(dengar);
    });

    test('kode tak dikenal jatuh ke nilai aman', () async {
      await AppSettings.load();
      await AppSettings.setLocale('de');
      await AppSettings.setTema('neon');
      expect(AppSettings.locale, 'id');
      expect(AppSettings.tema, 'system');
    });
  });
}
