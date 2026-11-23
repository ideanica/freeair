import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_settings.dart';
import '../l10n/l10n.dart';
import '../models/alert_record.dart';
import '../models/condition_result.dart';
import '../models/health_sample.dart';
import 'database_helper.dart';

export 'database_helper.dart';

/// Fallback riwayat untuk web/desktop, tempat sqflite tidak tersedia.
///
/// Disimpan di SharedPreferences dengan batas jumlah baris agar tidak
/// membesar tanpa batas.
class PrefsAlertStore implements DatabaseHelper {
  static const String _key = 'alert_history_v1';
  static const String _sampleKey = 'cycle_samples_v1';
  /// Cukup untuk 30 hari, 96 siklus harian, dan 3 kondisi per siklus.
  static const int _maxRows = 10000;

  /// 35 hari x 96 siklus 15 menit, dibulatkan ke bawah.
  static const int _maxSamples = 3000;

  @override
  Future<void> init() async {}

  @override
  Future<int> insertAlert(
    ConditionResult result,
    Map<String, dynamic> input,
  ) async {
    final rows = await _read();
    final record = AlertRecord.fromResult(
      result,
      input,
      kamus: L10n.untuk(AppSettings.locale),
    );
    rows.insert(0, record);
    if (rows.length > _maxRows) rows.removeRange(_maxRows, rows.length);
    await _write(rows);
    return rows.length;
  }

  @override
  Future<List<AlertRecord>> getRecentAlerts({int limit = 50}) async {
    final rows = await _read();
    return rows.take(limit).toList();
  }

  @override
  Future<AlertRecord?> getLastAlert(String kondisi) async {
    final rows = await _read();
    for (final row in rows) {
      if (row.kondisi == kondisi) return row;
    }
    return null;
  }

  @override
  Future<void> clearOldAlerts({int days = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final rows = await _read();
    rows.removeWhere((r) => r.timestamp.isBefore(cutoff));
    await _write(rows);
  }

  @override
  Future<void> insertSample(HealthSample sample) async {
    final rows = await _readSamples();
    rows.insert(0, sample);
    if (rows.length > _maxSamples) rows.removeRange(_maxSamples, rows.length);
    await _writeSamples(rows);
  }

  @override
  Future<List<HealthSample>> getSamples({int days = 28}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final rows = await _readSamples();
    return rows.where((s) => !s.at.isBefore(cutoff)).toList();
  }

  @override
  Future<void> clearOldSamples({int days = 35}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final rows = await _readSamples();
    rows.removeWhere((s) => s.at.isBefore(cutoff));
    await _writeSamples(rows);
  }

  Future<List<HealthSample>> _readSamples() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sampleKey);
      if (raw == null || raw.isEmpty) return <HealthSample>[];
      return [
        for (final item in jsonDecode(raw) as List)
          if (item is Map<String, dynamic>) HealthSample.fromRow(item),
      ];
    } catch (e, s) {
      debugPrint('Gagal membaca sampel (prefs): $e — $s');
      return <HealthSample>[];
    }
  }

  Future<void> _writeSamples(List<HealthSample> rows) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _sampleKey,
        jsonEncode(rows.map((r) => r.toRow()).toList()),
      );
    } catch (e, s) {
      debugPrint('Gagal menyimpan sampel (prefs): $e — $s');
    }
  }

  Future<List<AlertRecord>> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return <AlertRecord>[];
      return [
        for (final item in jsonDecode(raw) as List)
          if (item is Map<String, dynamic>) AlertRecord.fromJson(item),
      ];
    } catch (e, s) {
      debugPrint('Gagal membaca riwayat (prefs): $e — $s');
      return <AlertRecord>[];
    }
  }

  Future<void> _write(List<AlertRecord> rows) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(rows.map((r) => r.toJson()).toList()),
      );
    } catch (e, s) {
      debugPrint('Gagal menyimpan riwayat (prefs): $e — $s');
    }
  }
}

DatabaseHelper createDatabaseHelper() => PrefsAlertStore();
