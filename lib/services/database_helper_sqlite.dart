import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../l10n/app_settings.dart';
import '../l10n/l10n.dart';
import '../models/alert_record.dart';
import '../models/condition_result.dart';
import '../models/health_sample.dart';
import 'database_helper.dart';

export 'database_helper.dart';

/// Riwayat alert di SQLite (Android / iOS / desktop).
class SqliteAlertStore implements DatabaseHelper {
  static const String _table = 'alert_history';
  static const String _sampleTable = 'cycle_samples';
  static const String _dbName = 'health_alert.db';

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getDatabasesPath();
    final opened = await openDatabase(
      p.join(dir, _dbName),
      version: 3,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE $_table ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'timestamp INTEGER NOT NULL,'
          'kondisi TEXT NOT NULL,'
          'skor INTEGER NOT NULL,'
          'level TEXT NOT NULL,'
          'confidence TEXT,'
          'alasan TEXT,'
          'pemicu_json TEXT,'
          'intervensi TEXT,'
          'input_json TEXT'
          ')',
        );
        await db.execute(
          'CREATE INDEX idx_${_table}_kondisi ON $_table (kondisi, timestamp)',
        );
        await _buatTabelSampel(db);
      },
      onUpgrade: (db, dari, ke) async {
        if (dari < 2) await _buatTabelSampel(db);
        // v3: pemicu disimpan sebagai kode + angka supaya bisa dirender
        // dalam bahasa apa pun; kolom alasan lama tetap dipakai baris lama.
        if (dari < 3) {
          await db.execute('ALTER TABLE $_table ADD COLUMN pemicu_json TEXT');
        }
      },
    );
    _db = opened;
    return opened;
  }

  Future<void> _buatTabelSampel(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS $_sampleTable ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT,'
      'timestamp INTEGER NOT NULL,'
      'tanggal TEXT NOT NULL,'
      'metrik TEXT NOT NULL,'
      'level TEXT'
      ')',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_${_sampleTable}_tanggal '
      'ON $_sampleTable (tanggal)',
    );
  }

  @override
  Future<void> init() async {
    try {
      await database;
    } catch (e, s) {
      debugPrint('Gagal membuka database riwayat: $e — $s');
    }
  }

  @override
  Future<int> insertAlert(
    ConditionResult result,
    Map<String, dynamic> input,
  ) async {
    try {
      final db = await database;
      return await db.insert(
        _table,
        AlertRecord.fromResult(
          result,
          input,
          kamus: L10n.untuk(AppSettings.locale),
        ).toRow(),
      );
    } catch (e, s) {
      debugPrint('Gagal menyimpan riwayat alert: $e — $s');
      return 0;
    }
  }

  @override
  Future<List<AlertRecord>> getRecentAlerts({int limit = 50}) async {
    try {
      final db = await database;
      final rows = await db.query(
        _table,
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      return rows.map(AlertRecord.fromRow).toList();
    } catch (e, s) {
      debugPrint('Gagal membaca riwayat alert: $e — $s');
      return const [];
    }
  }

  @override
  Future<AlertRecord?> getLastAlert(String kondisi) async {
    try {
      final db = await database;
      final rows = await db.query(
        _table,
        where: 'kondisi = ?',
        whereArgs: [kondisi],
        orderBy: 'timestamp DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return AlertRecord.fromRow(rows.first);
    } catch (e, s) {
      debugPrint('Gagal membaca alert terakhir $kondisi: $e — $s');
      return null;
    }
  }

  @override
  Future<void> clearOldAlerts({int days = 30}) async {
    try {
      final db = await database;
      final cutoff = DateTime.now()
          .subtract(Duration(days: days))
          .millisecondsSinceEpoch;
      await db.delete(_table, where: 'timestamp < ?', whereArgs: [cutoff]);
    } catch (e, s) {
      debugPrint('Gagal membersihkan riwayat lama: $e — $s');
    }
  }

  @override
  Future<void> insertSample(HealthSample sample) async {
    try {
      final db = await database;
      await db.insert(_sampleTable, {
        'timestamp': sample.at.millisecondsSinceEpoch,
        'tanggal': sample.tanggal,
        'metrik': jsonEncode(sample.metrics),
        'level': sample.levelTertinggi,
      });
    } catch (e, s) {
      debugPrint('Gagal mencatat sampel siklus: $e — $s');
    }
  }

  @override
  Future<List<HealthSample>> getSamples({int days = 28}) async {
    try {
      final db = await database;
      final cutoff = DateTime.now()
          .subtract(Duration(days: days))
          .millisecondsSinceEpoch;
      final rows = await db.query(
        _sampleTable,
        where: 'timestamp >= ?',
        whereArgs: [cutoff],
        orderBy: 'timestamp DESC',
      );
      return rows.map((r) {
        final metrik = r['metrik'];
        return HealthSample(
          at: DateTime.fromMillisecondsSinceEpoch(
            (r['timestamp'] as num).toInt(),
          ),
          metrics: metrik is String
              ? {
                  for (final e in (jsonDecode(metrik) as Map).entries)
                    if (e.value is num)
                      e.key.toString(): (e.value as num).toDouble(),
                }
              : const {},
          levelTertinggi: r['level'] as String?,
        );
      }).toList();
    } catch (e, s) {
      debugPrint('Gagal membaca sampel siklus: $e — $s');
      return const [];
    }
  }

  @override
  Future<void> clearOldSamples({int days = 35}) async {
    try {
      final db = await database;
      final cutoff = DateTime.now()
          .subtract(Duration(days: days))
          .millisecondsSinceEpoch;
      await db.delete(
        _sampleTable,
        where: 'timestamp < ?',
        whereArgs: [cutoff],
      );
    } catch (e, s) {
      debugPrint('Gagal membersihkan sampel lama: $e — $s');
    }
  }
}

DatabaseHelper createDatabaseHelper() => SqliteAlertStore();
