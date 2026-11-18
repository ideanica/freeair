import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Preferensi pengguna.
///
/// Sengaja TIDAK lagi berisi ambang: sejak v3 semua angka ambang diturunkan
/// otomatis dari literatur klinis + baseline personal (lihat ThresholdResolver
/// dan BaselineEngine). Yang tersimpan di sini hanya pilihan tentang kondisi
/// apa yang dipantau dan wilayah cuaca.
class HealthProfile {
  const HealthProfile({
    required this.nama,
    required this.kondisi,
    required this.bmkgKodeWilayah,
  });

  static const String _key = 'health_profile_v3';

  final String nama;
  final List<String> kondisi;
  final String bmkgKodeWilayah;

  factory HealthProfile.fromConfig(Map<String, dynamic> profilDefault) =>
      HealthProfile(
        nama: profilDefault['nama'] as String? ?? 'User',
        kondisi: List<String>.from(
          profilDefault['kondisi'] as List? ?? const [],
        ),
        bmkgKodeWilayah: AppConfig.BMKG_KODE_WILAYAH,
      );

  Map<String, dynamic> toJson() => {
    'nama': nama,
    'kondisi': kondisi,
    'bmkg_kode_wilayah': bmkgKodeWilayah,
  };

  factory HealthProfile.fromJson(Map<String, dynamic> json) => HealthProfile(
    nama: json['nama'] as String? ?? 'User',
    kondisi: List<String>.from(json['kondisi'] as List? ?? const []),
    bmkgKodeWilayah:
        json['bmkg_kode_wilayah'] as String? ?? AppConfig.BMKG_KODE_WILAYAH,
  );

  HealthProfile copyWith({
    String? nama,
    List<String>? kondisi,
    String? bmkgKodeWilayah,
  }) => HealthProfile(
    nama: nama ?? this.nama,
    kondisi: kondisi ?? this.kondisi,
    bmkgKodeWilayah: bmkgKodeWilayah ?? this.bmkgKodeWilayah,
  );

  static Future<HealthProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return HealthProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }
}
