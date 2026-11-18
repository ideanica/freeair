import 'dart:convert';

import '../l10n/l10n.dart';
import 'condition_result.dart';
import 'pemicu.dart';

/// Satu baris riwayat hasil cek kondisi.
///
/// [pemicu] adalah sumber kebenaran dan bisa dirender ke bahasa apa pun.
/// [alasan] tetap diisi kalimat yang sudah dirender saat baris itu ditulis,
/// supaya baris lama (sebelum pemicu terstruktur) dan pembaca database
/// manual tetap punya teks yang bisa dibaca langsung.
class AlertRecord {
  const AlertRecord({
    this.id,
    required this.timestamp,
    required this.kondisi,
    required this.skor,
    required this.level,
    required this.confidence,
    required this.intervensi,
    this.pemicu = const <Pemicu>[],
    this.alasan = const <String>[],
    this.inputJson,
  });

  final int? id;
  final DateTime timestamp;
  final String kondisi;
  final int skor;
  final String level;
  final String confidence;
  final List<Pemicu> pemicu;
  final List<String> alasan;
  final String intervensi;

  /// Input mentah yang menghasilkan hasil ini, untuk audit kalibrasi.
  final Map<String, dynamic>? inputJson;

  /// Kalimat pemicu untuk ditampilkan: pakai kode bila ada, kalau tidak
  /// pakai teks yang tersimpan di baris lama.
  List<String> tampil(L10n kamus) =>
      pemicu.isNotEmpty ? kamus.pemicuSemua(pemicu) : alasan;

  factory AlertRecord.fromRow(Map<String, Object?> row) => AlertRecord(
    id: (row['id'] as int?) ?? 0,
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      (row['timestamp'] as int?) ?? 0,
    ),
    kondisi: row['kondisi'] as String? ?? '',
    skor: (row['skor'] as int?) ?? 0,
    level: row['level'] as String? ?? AlertLevels.aman,
    confidence: row['confidence'] as String? ?? 'LOW',
    pemicu: Pemicu.dariJson(_decodeList(row['pemicu_json'] as String?)),
    alasan: _splitAlasan(row['alasan'] as String?),
    intervensi: row['intervensi'] as String? ?? '',
    inputJson: _decodeMap(row['input_json'] as String?),
  );

  Map<String, Object?> toRow() => {
    'timestamp': timestamp.millisecondsSinceEpoch,
    'kondisi': kondisi,
    'skor': skor,
    'level': level,
    'confidence': confidence,
    'alasan': alasan.join(' | '),
    'pemicu_json': pemicu.isEmpty ? null : jsonEncode(Pemicu.keJson(pemicu)),
    'intervensi': intervensi,
    'input_json': inputJson == null ? null : jsonEncode(inputJson),
  };

  factory AlertRecord.fromResult(
    ConditionResult r,
    Map<String, dynamic> input, {
    DateTime? at,
    L10n kamus = L10n.id,
  }) => AlertRecord(
    timestamp: at ?? DateTime.now(),
    kondisi: r.kondisi,
    skor: r.skor,
    level: r.level,
    confidence: r.confidence,
    pemicu: r.pemicu,
    alasan: r.alasanTeks(kamus),
    intervensi: r.intervensi,
    inputJson: input,
  );

  static List<String> _splitAlasan(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    return raw.split(' | ');
  }

  static Map<String, dynamic>? _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static Object? _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.millisecondsSinceEpoch,
    'kondisi': kondisi,
    'skor': skor,
    'level': level,
    'confidence': confidence,
    'pemicu': Pemicu.keJson(pemicu),
    'alasan': alasan,
    'intervensi': intervensi,
    'input_json': inputJson,
  };

  factory AlertRecord.fromJson(Map<String, dynamic> json) => AlertRecord(
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      (json['timestamp'] as num?)?.toInt() ?? 0,
    ),
    kondisi: json['kondisi'] as String? ?? '',
    skor: (json['skor'] as num?)?.toInt() ?? 0,
    level: json['level'] as String? ?? AlertLevels.aman,
    confidence: json['confidence'] as String? ?? 'LOW',
    pemicu: Pemicu.dariJson(json['pemicu']),
    alasan: List<String>.from(json['alasan'] as List? ?? const []),
    intervensi: json['intervensi'] as String? ?? '',
    inputJson: json['input_json'] is Map
        ? Map<String, dynamic>.from(json['input_json'] as Map)
        : null,
  );
}
