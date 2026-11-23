import 'package:flutter/material.dart';

import '../l10n/app_settings.dart';
import '../l10n/l10n.dart';
import '../models/health_profile.dart';
import '../models/threshold_set.dart';
import '../services/alert_orchestrator.dart';
import '../services/baseline_engine.dart';
import 'level_style.dart';
import '../widgets/jb.dart';

/// Profil tanpa satu pun ambang yang bisa diketik.
///
/// Yang diubah di sini hanya apa yang dipantau, di mana pengguna berada, dan
/// bagaimana tampilan bicara (bahasa/tema). Sisanya — daftar ambang, tier
/// kalibrasi, dan kutipan jurnalnya — dibaca dari siklus terakhir supaya
/// bisa diaudit.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.orchestrator, super.key});

  final AlertOrchestrator orchestrator;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const List<String> _kondisiOption = [
    'Bronkitis Kronis',
    'Anxiety',
    'Alergi Dingin',
  ];

  /// Nama bahasa ditampilkan dalam bahasanya sendiri, jadi tidak ikut
  /// diterjemahkan: "English" tetap "English" di layar Indonesia.
  static const Map<String, String> _namaBahasa = {
    'id': 'Indonesia',
    'en': 'English',
  };

  static const Map<String, String> _keyTema = {
    'system': 'profil.tema_sistem',
    'light': 'profil.tema_terang',
    'dark': 'profil.tema_gelap',
  };

  final _namaController = TextEditingController();
  final _wilayahController = TextEditingController();
  final _namaFokus = FocusNode();

  List<String> _kondisi = const [];
  String _kodeWilayah = '';
  bool _siap = false;
  String? _pesanIzin;

  AlertOrchestrator get _o => widget.orchestrator;

  @override
  void initState() {
    super.initState();
    _o.addListener(_uatAmbang);
    _muat();
  }

  @override
  void dispose() {
    _o.removeListener(_uatAmbang);
    _namaController.dispose();
    _wilayahController.dispose();
    _namaFokus.dispose();
    super.dispose();
  }

  /// Ambang bisa berubah tiap siklus (data baru masuk), jadi layar ikut
  /// dibangun ulang saat orkestrator memberi tahu ada hasil terbaru.
  void _uatAmbang() {
    if (mounted) setState(() {});
  }

  Future<void> _muat() async {
    final tersimpan = await HealthProfile.load();
    final profil =
        tersimpan ?? HealthProfile.fromConfig(_o.config.profilDefault);
    if (!mounted) return;
    setState(() {
      _kondisi = List<String>.from(profil.kondisi);
      _kodeWilayah = profil.bmkgKodeWilayah;
      _namaController.text = profil.nama;
      _wilayahController.text = profil.bmkgKodeWilayah;
      _siap = true;
    });
  }

  Future<void> _simpan() async {
    final theme = Theme.of(context);
    final kamus = L10n.of(context);
    if (_kondisi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kamus.t('profil.error_kondisi')),
          backgroundColor: theme.colorScheme.error,
        ),
      );
      return;
    }
    if (_kodeWilayah.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kamus.t('profil.error_wilayah')),
          backgroundColor: theme.colorScheme.error,
        ),
      );
      return;
    }
    final profil = HealthProfile(
      nama: _namaController.text.trim().isEmpty
          ? 'User'
          : _namaController.text.trim(),
      kondisi: _kondisi,
      bmkgKodeWilayah: _kodeWilayah.trim(),
    );
    await profil.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(kamus.t('profil.tersimpan'))));
  }

  Future<void> _mintaIzin() async {
    final granted = await _o.healthService.requestPermissions();
    if (!mounted) return;
    final kamus = L10n.of(context);
    setState(() {
      _pesanIzin = kamus.t(
        granted ? 'profil.izin_diberikan' : 'profil.izin_belum',
      );
    });
  }

  /// Bahasa dan tema disimpan lewat AppSettings; notifiernya membangun ulang
  /// MaterialApp, jadi tidak ada layar yang perlu di-restart.
  Future<void> _uatBahasa(String kode) async {
    await AppSettings.setLocale(kode);
    if (mounted) setState(() {});
  }

  Future<void> _uatTema(String kode) async {
    await AppSettings.setTema(kode);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_siap) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final kamus = L10n.of(context);
    final tones = AppTones.of(context);
    final outcome = _o.hasilTerakhir;
    final nama = _namaController.text.trim().isEmpty
        ? 'User'
        : _namaController.text.trim();

    void uatKondisi(String opsi) => setState(() {
      _kondisi = _kondisi.contains(opsi)
          ? _kondisi.where((x) => x != opsi).toList()
          : [..._kondisi, opsi];
    });

    final bisaKembali = Navigator.canPop(context);
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top + 8,
          20,
          AppLayout.bawahKonten(context),
        ),
        children: [
          // Top bar gaya Stitch: back pill + judul + simpan.
          Row(
            children: [
              if (bisaKembali) ...[
                JbIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  tooltip: kamus.t('umum.kembali'),
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  kamus.t('profil.judul'),
                  style: AppTeks.judulHalaman(tones),
                ),
              ),
            ],
          ),
          // Identitas gaya Stitch: avatar + nama + chip kondisi + tombol edit.
          Column(
            children: [
              const SizedBox(height: 18),
              JbAvatar(name: nama, size: 92),
              const SizedBox(height: 14),
              Text(
                nama,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTeks.sapaan(tones).copyWith(fontSize: 24),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: JbStatusPill(
                      label: _kondisi.isEmpty
                          ? kamus.t('profil.pilih_kondisi')
                          : _kondisi.join(' · '),
                      color: tones.aksenDeep,
                      compact: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _namaFokus.requestFocus(),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: tones.card,
                        shape: BoxShape.circle,
                        boxShadow: tones.softShadow(),
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        size: 15,
                        color: tones.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          AppLayout.jarak,
          // Catatan singkat: tidak ada ambang yang diketik manual.
          JbCard(
            color: tones.panel,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 17,
                  color: tones.aksenDeep,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    kamus.t('profil.catatan_kunci'),
                    style: AppTeks.isiSoft(tones).copyWith(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Kartu utama: kondisi yang dipantau + nama + wilayah.
          SectionCard(
            judul: kamus.t('profil.kondisi_judul'),
            ikon: Icons.monitor_heart_outlined,
            deskripsi: kamus.t('profil.kondisi_kartu_sub'),
            children: [
              TextField(
                controller: _namaController,
                focusNode: _namaFokus,
                decoration: InputDecoration(
                  labelText: kamus.t('profil.nama'),
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                    size: 19,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              _LabelBaris(teks: kamus.t('profil.pilih_kondisi')),
              GrupBaris(
                warna: tones.panel,
                children: [
                  for (final opsi in _kondisiOption)
                    BarisSetelan(
                      ikon: KondisiStyle.iconOf(_kondisiPendek(opsi)),
                      judul: opsi,
                      warna: _kondisi.contains(opsi)
                          ? theme.colorScheme.primary
                          : tones.inkSoft,
                      onTap: () => uatKondisi(opsi),
                      trailing: Switch(
                        value: _kondisi.contains(opsi),
                        onChanged: (_) => uatKondisi(opsi),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _wilayahController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: kamus.t('profil.wilayah_label'),
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 19),
                  helperText: kamus.t('profil.wilayah_helper'),
                  helperMaxLines: 2,
                ),
                onChanged: (v) => setState(() => _kodeWilayah = v),
              ),
              const SizedBox(height: 8),
              Text(
                kamus.t('profil.wilayah_catatan'),
                style: AppTeks.isi(tones)
                    .copyWith(fontSize: 13, color: tones.inkSoft),
              ),
            ],
          ),
          // Tampilan: bahasa dan tema.
          SectionCard(
            judul: kamus.t('profil.tampilan_judul'),
            ikon: Icons.palette_outlined,
            deskripsi: kamus.t('profil.tampilan_kartu_sub'),
            children: [
              _LabelBaris(teks: kamus.t('profil.bahasa')),
              Wrap(
                runSpacing: 8,
                children: [
                  for (final kode in AppSettings.localeYangDidukung)
                    PilTab(
                      teks: _namaBahasa[kode]!,
                      aktif: AppSettings.locale == kode,
                      ukuranTeks: 14,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      onTap: () => _uatBahasa(kode),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _LabelBaris(teks: kamus.t('profil.tema')),
              Wrap(
                runSpacing: 8,
                children: [
                  for (final kode in AppSettings.temaYangDidukung)
                    PilTab(
                      teks: kamus.t(_keyTema[kode]!),
                      aktif: AppSettings.tema == kode,
                      ukuranTeks: 14,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      onTap: () => _uatTema(kode),
                    ),
                ],
              ),
            ],
          ),
          // Kartu yang diminta: Sumber & Rujukan, satu pintu ke halaman sendiri.
          JbCard(
            onTap: () => Navigator.pushNamed(context, '/sources'),
            child: Row(
              children: [
                KotakIkon(
                  ikon: Icons.menu_book_rounded,
                  warna: tones.aksenDeep,
                  ukuran: 44,
                  ukuranIkon: 22,
                  tertutup: true,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kamus.t('profil.resource_judul'),
                        style: AppTeks.judulKartu(tones).copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        kamus.t('profil.sumber_kartu_sub'),
                        style: AppTeks.isiSoft(tones).copyWith(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: tones.inkSoft),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Izin baca sensor: satu kartu, bukan daftar panjang.
          SectionCard(
            judul: kamus.t('profil.sumber_judul'),
            ikon: Icons.cloud_download_outlined,
            deskripsi: kamus.t('profil.izin_kartu_sub'),
            children: [
              InkWell(
                onTap: _mintaIzin,
                borderRadius: BorderRadius.circular(AppLayout.radiusGrup),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 6,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KotakIkon(
                        ikon: Icons.health_and_safety_outlined,
                        warna: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kamus.t('profil.izin_judul', {
                                'sumber': _o.healthService.sourceLabel,
                              }),
                              style: AppTeks.judulBaris(tones)
                                  .copyWith(fontSize: 16, height: 1.3),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _pesanIzin ?? kamus.t('profil.izin_deskripsi'),
                              style: AppTeks.isi(
                                tones,
                              ).copyWith(fontSize: 13.5, color: tones.inkSoft),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 30,
                        color: tones.inkSoft,
                      ),
                    ],
                  ),
                ),
              ),
              if (outcome != null) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final sumber in outcome.snapshot.sumberAktif)
                      InfoChip(
                        teks: kamus.sumberData(sumber),
                        berat: FontWeight.w600,
                      ),
                  ],
                ),
              ],
            ],
          ),
          // Kalibrasi: ringkas di sini, detail di lembar yang dibuka.
          _KartuKalibrasi(
            outcome: outcome,
            kamus: kamus,
            tones: tones,
            onTap: outcome == null
                ? null
                : () => _bukaKalibrasi(context, outcome),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _simpan,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppLayout.radiusPil),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Text(kamus.t('profil.simpan')),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                await HealthProfile.fromConfig(_o.config.profilDefault).save();
                await _muat();
              },
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: Text(kamus.t('profil.reset')),
            ),
          ),
        ],
      ),
    );
  }

  /// Ambang, kecukupan data, dan sumber angka dibuka dari kartu kalibrasi.
  void _bukaKalibrasi(BuildContext context, CycleOutcome outcome) {
    final kamus = L10n.of(context);
    final theme = Theme.of(context);
    final tones = AppTones.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LembarKalibrasi(
        judul: kamus.t('profil.kalibrasi_judul'),
        sub: kamus.t('profil.kalibrasi_sheet_sub'),
        anak: Column(
          children: [
            SectionCard(
              judul: kamus.t('profil.ambang_judul'),
              ikon: Icons.tune_rounded,
              deskripsi: kamus.t('profil.ambang_deskripsi'),
              children: [
                for (final info in outcome.ambang.provenance)
                  _AmbangBaris(info: info),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    InfoChip(
                      teks: kamus.t('beranda.tier_personal'),
                      warna: tones.aman,
                    ),
                    InfoChip(
                      teks: kamus.t('beranda.tier_sebagian'),
                      warna: tones.waspada,
                    ),
                    InfoChip(
                      teks: kamus.t('beranda.tier_literatur'),
                      warna: tones.netral,
                    ),
                  ],
                ),
              ],
            ),
            SectionCard(
              judul: kamus.t('profil.kecukupan_judul'),
              ikon: Icons.data_usage_rounded,
              children: [
                for (final baris
                    in BaselineEngine(_o.config).laporanKecukupanData(
                      outcome.ambang.baseline,
                      locale: kamus.kode,
                    ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            baris,
                            style: AppTeks.isi(tones).copyWith(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  kamus.t('profil.kecukupan_catatan'),
                  style: AppTeks.isi(tones)
                      .copyWith(fontSize: 13, color: tones.inkSoft),
                ),
              ],
            ),
            SectionCard(
              judul: kamus.t('profil.sumber_angka_judul'),
              ikon: Icons.menu_book_outlined,
              children: [
                for (final info in outcome.ambang.provenance)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: BoxDecoration(
                                color: tones.tier(info.tier.name),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                info.label(kamus),
                                style: AppTeks.judulBaris(tones)
                                    .copyWith(fontSize: 14.5, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: Text(
                            _o.config.sumberTeks(
                              info.sumberKey,
                              locale: kamus.kode,
                            ),
                            style: AppTeks.isi(tones)
                                .copyWith(fontSize: 13, color: tones.inkSoft),
                          ),
                        ),
                      ],
                    ),
                  ),
                Divider(height: 21, thickness: 1, color: tones.line),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).pushNamed('/sources');
                  },
                  borderRadius: BorderRadius.circular(AppLayout.radiusGrup),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 20,
                          color: tones.aksenDeep,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            kamus.t('profil.sumber_ajakan'),
                            style: AppTeks.tautan(tones).copyWith(height: 1.35),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 26,
                          color: tones.aksenDeep,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  kamus.t('profil.disclaimer'),
                  style: AppTeks.isi(tones)
                      .copyWith(fontSize: 13, color: tones.inkSoft),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Nama kondisi di daftar opsi memakai label panjang ("Bronkitis Kronis"),
  /// sedangkan ikon gaya dipetakan dari nama pendek hasil rule engine.
  static String _kondisiPendek(String opsi) => switch (opsi) {
    'Bronkitis Kronis' => 'Bronkitis',
    _ => opsi,
  };
}

/// Judul kecil di atas baris pilihan (bahasa, tema, kondisi) — `ContainerLabel`
/// versi di dalam kartu.
class _LabelBaris extends StatelessWidget {
  const _LabelBaris({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(teks, style: AppTeks.labelSeksi(AppTones.of(context))),
    );
  }
}

/// Satu ambang beserta asal angkanya. Bentuk barisnya mengikuti
/// `OverviewTaskContainer`: keterangan kiri, angka sewarna tier di kanan.
class _AmbangBaris extends StatelessWidget {
  const _AmbangBaris({required this.info});

  final AmbangInfo info;

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    final tones = AppTones.of(context);
    final warna = tones.tier(info.tier.name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.label(kamus),
                  style: AppTeks.judulBaris(tones)
                      .copyWith(fontSize: 15, height: 1.3),
                ),
                if (info.detailKey != null)
                  Text(
                    info.detail(kamus),
                    style: AppTeks.isi(tones)
                        .copyWith(fontSize: 13, color: tones.inkSoft),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${info.nilaiTeks}${kamus.satuan(info.satuan)}',
                style: AppTeks.angka(tones).copyWith(
                  color: warna,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                kamus.t('tier.${info.tier.name}'),
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 11,
                  color: warna,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ringkasan kalibrasi di halaman profil. Detailnya dibuka lewat [onTap].
class _KartuKalibrasi extends StatelessWidget {
  const _KartuKalibrasi({
    required this.outcome,
    required this.kamus,
    required this.tones,
    this.onTap,
  });

  final CycleOutcome? outcome;
  final L10n kamus;
  final AppTones tones;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return JbCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KotakIkon(
                ikon: Icons.tune_rounded,
                warna: tones.aksenDeep,
                ukuran: 44,
                ukuranIkon: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kamus.t('profil.ambang_judul'),
                      style: AppTeks.judulKartu(tones).copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      outcome == null
                          ? kamus.t('profil.kalibrasi_kosong')
                          : kamus.t('profil.kalibrasi_kartu_sub'),
                      style: AppTeks.isiSoft(tones).copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: tones.inkSoft),
            ],
          ),
          if (outcome != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                InfoChip(
                  teks: kamus.t('profil.ambang_n', {
                    'n': '${outcome!.ambang.provenance.length}',
                  }),
                  ikon: Icons.list_alt_rounded,
                ),
                InfoChip(
                  teks: kamus.t('beranda.keyakinan_ringkas', {
                    'level': outcome!.snapshot.confidence,
                  }),
                  ikon: Icons.verified_outlined,
                  warna: outcome!.snapshot.confidence == 'HIGH'
                      ? tones.aman
                      : tones.waspada,
                ),
                InfoChip(
                  teks: kamus.t('beranda.ambang_ringkas_2', {
                    'tier': kamus.t(
                      'tier.${outcome!.ambang.tierAmbangSuhu.name}',
                    ),
                  }),
                  ikon: Icons.device_thermostat_rounded,
                  warna: tones.tier(outcome!.ambang.tierAmbangSuhu.name),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Lembar detail kalibrasi: ambang, kecukupan data, dan sumber angka.
class _LembarKalibrasi extends StatelessWidget {
  const _LembarKalibrasi({
    required this.judul,
    required this.sub,
    required this.anak,
  });

  final String judul;
  final String sub;
  final Widget anak;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final kamus = L10n.of(context);
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.92,
      decoration: BoxDecoration(
        color: tones.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: tones.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(judul, style: AppTeks.judulHalaman(tones)),
                      const SizedBox(height: 4),
                      Text(
                        sub,
                        style: AppTeks.isiSoft(tones).copyWith(fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                JbIconButton(
                  icon: Icons.close_rounded,
                  tooltip: kamus.t('umum.tutup'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [anak],
            ),
          ),
        ],
      ),
    );
  }
}
