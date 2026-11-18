import 'package:flutter_test/flutter_test.dart';
import 'package:health_alert/services/rule_config.dart';

/// Jaga-jaga struktur `assets/rule_config.json` v3.
///
/// Dua hal yang bikin aplikasi rusak diam-diam: aset tidak terdaftar di
/// pubspec (boot gagal) dan satu kunci bobot/angka yang hilang (rule engine
/// melempar StateError di tengah siklus). Tes ini membunyikan keduanya lebih
/// awal, termasuk aturan paling penting: tidak ada ambang yang boleh diisi
/// pengguna.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rule_config.json termuat dari asset bundle', () async {
    final config = await RuleConfig.load();

    expect(config.versi, '3.0.0');
    expect(config.batasWaspada, 20);
    expect(config.batasPerhatian, 45);
    expect(config.batasBahaya, 70);
    expect(config.dedupMenit, 60);
    expect(config.dedupJikaLevelBerubah, isTrue);
  });

  test('profil default tidak menyimpan satu pun ambang', () async {
    final profil = (await RuleConfig.load()).profilDefault;

    expect(profil['nama'], 'User');
    expect(profil['kondisi'], ['Bronkitis Kronis', 'Anxiety', 'Alergi Dingin']);
    for (final kunciLama in [
      'ambang_suhu_alergi',
      'hr_warning',
      'hr_bahaya',
      'cycle_day',
    ]) {
      expect(
        profil.containsKey(kunciLama),
        isFalse,
        reason: '$kunciLama sudah manual',
      );
    }
  });

  test('setiap blok literatur membawa kutipan jurnal', () async {
    final config = await RuleConfig.load();

    for (final blok in [
      'spo2',
      'desaturasi_personal',
      'laju_napas',
      'detak_jantung',
      'hrv_rmssd',
      'tidur',
      'udara_dingin',
      'partikulat',
      'aktivitas',
      'siklus',
      'offset_suhu_personal',
    ]) {
      final sumber = config.rawLiteratur[blok]?['sumber'] as String?;
      expect(sumber, isNotNull, reason: 'blok $blok tanpa sumber');
      expect(
        sumber!.length,
        greaterThan(20),
        reason: 'sumber $blok terlalu tipis',
      );
    }

    // Spot-check angka yang tidak boleh berubah tanpa rujukan baru.
    expect(config.lit('spo2', 'hipoksemia'), 90);
    expect(config.lit('laju_napas', 'takipnea'), 24);
    expect(config.lit('tidur', 'efisiensi_pct_min'), 85);
    expect(config.lit('partikulat', 'pm25_waspada'), closeTo(35.4, 0.01));
    expect(config.lit('detak_jantung', 'delta_baseline_waspada_bpm'), 5);
  });

  test(
    'dinamis: jendela, tier dan 11 metrik yang dipelajari ada semua',
    () async {
      final config = await RuleConfig.load();

      expect(config.jendelaHari, 28);
      expect(config.minimumHariSebagian, 7);
      expect(config.minimumHariPersonal, 14);
      expect(config.bobotCampurPersonal, 0.6);
      expect(config.outlierMadScore, 3.5);
      expect(config.faktorVariabilitas, 2.0);
      expect(config.dinamisSumber, contains('Iglewicz'));
      expect(config.metrikDinamis.keys, [
        'resting_hr',
        'hrv_rmssd',
        'spo2',
        'resp_rate',
        'tidur_menit',
        'tidur_efisiensi',
        'suhu_ambient',
        'angin_ms',
        'pm25',
        'hr_avg',
        'olahraga_menit',
      ]);
      expect(config.metrikDinamis.values.every((m) => m is Map), isTrue);
    },
  );

  test('pembelajaran ambang dingin punya parameter lengkap', () async {
    final config = await RuleConfig.load();

    expect(config.reaksiHrDelta, 8);
    expect(config.reaksiRrMin, 21);
    expect(config.reaksiRrDelta, 4);
    expect(config.reaksiSpo2Drop, 4);
    expect(config.minimumKejadianDingin, 3);
    expect(config.marginAmanDingin, 1);
    expect(config.pembelajaranDinginSumber, contains('Van Gerven'));
  });

  test('setiap kunci bobot yang dibaca rule engine tersedia', () async {
    final config = await RuleConfig.load();

    const dibaca = {
      'Bronkitis': {
        'spo2_absolut': [
          'hipoksemia_dikonfirmasi',
          'hipoksemia_tidak_dikonfirmasi',
          'sedang_dikonfirmasi',
          'sedang_tidak_dikonfirmasi',
          'ringan',
        ],
        'laju_napas': ['takipnea', 'takipnea_ringan'],
        'hr_deviasi_baseline': ['bahaya', 'waspada'],
        'tidur_durasi': ['min'],
        'tidur_efisiensi': ['min'],
        'pm25': ['bahaya', 'perhatian', 'waspada'],
        'luteal': ['syarat_skor', 'bobot'],
      },
      'Anxiety': {
        'hrv_deviasi_baseline': ['perhatian', 'waspada'],
        'hrv_floor': ['floor'],
        'hr_deviasi_baseline': ['bahaya', 'waspada'],
        'hr_absolut': ['berat', 'takikardia'],
        'tidur_durasi': ['min'],
        'tidur_efisiensi': ['min'],
        'tidur_waso': ['min'],
        'olahraga': ['protektif', 'minim'],
      },
      'Alergi Dingin': {
        'suhu_terhadap_ambang_personal': [
          'sangat_dingin',
          'dingin',
          'mendekati',
        ],
        'suhu_drop_baseline': ['bahaya', 'waspada'],
        'kelembapan': ['sangat_kering', 'kering'],
        'angin': ['bahaya', 'waspada'],
        'hr_deviasi_baseline': ['bahaya', 'waspada'],
        'olahraga': ['berat'],
      },
    };

    final tabel = {
      'Bronkitis': config.bronkitis,
      'Anxiety': config.anxiety,
      'Alergi Dingin': config.alergiDingin,
    };

    for (final kondisi in tabel.entries) {
      for (final grup in dibaca[kondisi.key]!.entries) {
        for (final kunci in grup.value) {
          expect(
            kondisi.value.weight(grup.key, kunci),
            isA<int>(),
            reason: '${kondisi.key}.${grup.key}.$kunci hilang',
          );
        }
      }
    }

    // Bobot tunggal (nilai = angka langsung) dipakai untuk fase siklus.
    expect(config.anxiety.single('luteal'), 10);
    expect(config.anxiety.single('menstruasi'), 5);
    expect(config.alergiDingin.single('luteal'), 10);
    expect(config.bronkitis.single('spo2_desaturasi_personal'), 20);
    // Olahraga boleh melindungi: bobotnya negatif.
    expect(config.anxiety.weight('olahraga', 'protektif'), -10);
  });

  test('teks intervensi ada untuk tiap level yang membunyikan alert', () async {
    final config = await RuleConfig.load();

    for (final kondisi in ['Bronkitis', 'Anxiety', 'Alergi Dingin']) {
      expect(config.intervensi(kondisi, 'AMAN'), isEmpty);
      for (final level in ['WASPADA', 'PERHATIAN', 'BAHAYA']) {
        expect(
          config.intervensi(kondisi, level),
          isNotEmpty,
          reason: '$kondisi/$level tanpa intervensi',
        );
      }
    }

    // Placeholder yang diisi otomatis dari sensor/baseline — tidak ada yang
    // boleh bergantung pada isian pengguna.
    expect(config.intervensi('Bronkitis', 'BAHAYA'), contains('{spo2}'));
    expect(
      config.intervensi('Bronkitis', 'BAHAYA'),
      contains('{spo2_baseline}'),
    );
    expect(config.intervensi('Alergi Dingin', 'PERHATIAN'), contains('{suhu}'));
    expect(
      config.intervensi('Alergi Dingin', 'PERHATIAN'),
      contains('{ambang_dingin}'),
    );
    expect(config.intervensi('Anxiety', 'WASPADA'), contains('{hrv}'));
  });
}
