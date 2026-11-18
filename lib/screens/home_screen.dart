import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../l10n/l10n.dart';
import '../models/condition_result.dart';
import '../models/health_profile.dart';
import '../models/pemeriksaan.dart';
import '../models/sensor_snapshot.dart';
import '../services/alert_orchestrator.dart';
import '../services/health_services.dart';
import 'level_style.dart';

/// Beranda tanpa input manual.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.orchestrator,
    required this.healthService,
    super.key,
  });

  final AlertOrchestrator orchestrator;
  final HealthService healthService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HealthProfile? _profil;
  CycleOutcome? _outcome;
  bool _sedangCek = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _outcome = widget.orchestrator.hasilTerakhir;
    widget.orchestrator.addListener(_senyapkanOutcome);
    _loadProfil();
  }

  @override
  void dispose() {
    widget.orchestrator.removeListener(_senyapkanOutcome);
    super.dispose();
  }

  void _senyapkanOutcome() {
    if (!mounted) return;
    setState(() => _outcome = widget.orchestrator.hasilTerakhir);
  }

  Future<void> _loadProfil() async {
    final profil = await HealthProfile.load();
    if (!mounted) return;
    setState(() => _profil = profil);
  }

  Future<void> _jalanCek({bool paksaCuaca = false}) async {
    setState(() {
      _sedangCek = true;
      _error = null;
    });
    try {
      final outcome = await widget.orchestrator.runCycle(
        profil: _profil,
        forceRefreshCuaca: paksaCuaca,
      );
      if (!mounted) return;
      setState(() {
        _outcome = outcome;
        _sedangCek = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _sedangCek = false;
      });
    }
  }

  Future<void> _mintaIzin() async {
    final diberikan = await widget.healthService.requestPermissions();
    if (!mounted) return;
    final kamus = L10n.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          diberikan
              ? kamus.t('beranda.izin_selesai')
              : kamus.t('beranda.izin_gagal'),
        ),
      ),
    );
    if (diberikan) await _jalanCek();
  }

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    final tones = AppTones.of(context);
    final nama = _profil?.nama.trim();
    final adaNama = nama != null && nama.isNotEmpty;
    final alert = (_outcome?.results ?? const <ConditionResult>[]).where(
      (r) => AlertLevels.levelButuhAlert(r.level),
    );
    return Scaffold(
      // Header sticky diletakkan di SliverAppBar pinned agar tetap terlihat
      // saat pengguna menggulir konten ke bawah.
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadProfil();
          await _jalanCek();
        },
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              // ── Sticky app-bar: judul + notif + avatar ────────────────────
              SliverAppBar(
                pinned: true,
                floating: false,
                snap: false,
                expandedHeight: 0,
                toolbarHeight: 62,
                backgroundColor: tones.canvas.withValues(alpha: 0.97),
                surfaceTintColor: Colors.transparent,
                shadowColor: tones.bayangan.withValues(alpha: 0.12),
                elevation: 1,
                automaticallyImplyLeading: false,
                flexibleSpace: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: KepalaHalaman(
                      judul: kamus.t('beranda.judul_app'),
                      ikon: Icons.notifications_outlined,
                      jumlah: alert.isEmpty ? null : alert.length,
                      onKetukIkon: () =>
                          Navigator.pushNamed(context, '/history'),
                      onKetukAvatar: () =>
                          Navigator.pushNamed(context, '/profile'),
                      namaAvatar: adaNama ? nama : null,
                    ),
                  ),
                ),
              ),
              // ── Konten yang bisa di-scroll ────────────────────────────────
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  AppLayout.bawahKonten(context),
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Sapaan ringkas satu baris
                    if (adaNama)
                      _SapaanRingkas(nama: nama)
                    else
                      Text(
                        kamus.t('beranda.subtitle'),
                        style: AppTeks.labelSeksi(tones)
                            .copyWith(color: tones.inkSoft),
                      ),
                    const SizedBox(height: 12),
                    if (!AppConfig.ENABLE_NOTIFICATIONS)
                      const _ObservationBanner(),
                    if (_error != null)
                      _ErrorBanner(
                        pesan: kamus.t('beranda.gagal', {'error': _error!}),
                      ),
                    _StatusHero(
                      outcome: _outcome,
                      sumberData: widget.healthService.sourceLabel,
                      sedangCek: _sedangCek,
                      onCek: _sedangCek ? null : _jalanCek,
                      onCekPaksa: _sedangCek
                          ? null
                          : () => _jalanCek(paksaCuaca: true),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      kamus.t('beranda.tombol_jelas', {
                        'menit': '${AppConfig.CYCLE_INTERVAL_MINUTES}',
                      }),
                      textAlign: TextAlign.center,
                      style: AppTeks.labelSeksi(tones),
                    ),
                    // ─── Hasil kondisi ───────────────────────────────────────
                    _SeksiHeader(
                      judul: kamus.t('beranda.seksi_kondisi'),
                      info: kamus.t('beranda.seksi_kondisi_info'),
                      ikon: Icons.medical_services_outlined,
                      trailing: _outcome == null
                          ? null
                          : InfoChip(
                              teks: kamus.t('umum.jam', {
                                'waktu': _jam(_outcome!.at),
                              }),
                              ikon: Icons.schedule_rounded,
                            ),
                    ),
                    if (_outcome == null)
                      EmptyState(
                        ikon: Icons.monitor_heart_outlined,
                        judul: kamus.t('beranda.kosong_judul'),
                        pesan: kamus.t('beranda.kosong_pesan'),
                      )
                    else
                      ..._outcome!.results.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: HasilKartu(hasil: r),
                        ),
                      ),
                    // ─── Status izin ─────────────────────────────────────────
                    if (_outcome != null) ...[
                      _SeksiHeader(
                        judul: kamus.t('beranda.grup_sumber'),
                        info: kamus.t('beranda.sumber_data_info'),
                        ikon: Icons.sensors_outlined,
                      ),
                      _StatusSinyal(
                        snapshot: _outcome!.snapshot,
                        onMintaIzin: _mintaIzin,
                      ),
                    ],
                    // ─── Sensor tubuh terkelompok ────────────────────────────
                    if (_outcome?.snapshot != null) ...[
                      _SeksiHeader(
                        judul: kamus.t('beranda.seksi_sensor'),
                        info: kamus.t('beranda.seksi_sensor_info'),
                        ikon: Icons.watch_outlined,
                      ),
                      _GrupSensor(snapshot: _outcome!.snapshot),
                    ],
                    // ─── Kalibrasi ambang ────────────────────────────────────
                    if (_outcome != null) ...[
                      const SizedBox(height: 6),
                      _KalibrasiKartu(outcome: _outcome!),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _jam(DateTime waktu) =>
      '${waktu.hour.toString().padLeft(2, '0')}:'
      '${waktu.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────── Sapaan ringkas satu baris di bawah header
class _SapaanRingkas extends StatelessWidget {
  const _SapaanRingkas({required this.nama});
  final String nama;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final kamus = L10n.of(context);
    // Potong nama ke maksimal 18 karakter agar tetap satu baris
    final pendek = nama.length > 18 ? '${nama.substring(0, 16)}…' : nama;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${kamus.t('beranda.sapaan')} $pendek 👋',
          style: AppTeks.labelSeksi(tones).copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: tones.ink,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────── Header seksi dengan info tooltip ─
class _SeksiHeader extends StatelessWidget {
  const _SeksiHeader({
    required this.judul,
    required this.info,
    required this.ikon,
    this.trailing,
  });

  final String judul;
  final String info;
  final IconData ikon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Row(
        children: [
          Icon(ikon, size: 16, color: tones.inkSoft),
          const SizedBox(width: 7),
          Expanded(
            child: Text(judul.toUpperCase(), style: AppTeks.labelSeksi(tones)),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          const SizedBox(width: 4),
          Tooltip(
            message: info,
            triggerMode: TooltipTriggerMode.tap,
            showDuration: const Duration(seconds: 5),
            child: Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: tones.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── Observation banner
class _ObservationBanner extends StatelessWidget {
  const _ObservationBanner();

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    final tones = AppTones.of(context);
    final accent = tones.waspada;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tones.card,
        borderRadius: BorderRadius.circular(AppLayout.radiusKartu),
        boxShadow: tones.softShadow(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KotakIkon(
            ikon: Icons.notifications_off_outlined,
            warna: accent,
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
                  kamus.t('beranda.observasi_judul'),
                  style: AppTeks.judulBaris(tones).copyWith(color: accent),
                ),
                const SizedBox(height: 4),
                Text(
                  kamus.t('beranda.observasi_pesan', {
                    'menit': '${AppConfig.CYCLE_INTERVAL_MINUTES}',
                  }),
                  style: AppTeks.isi(tones)
                      .copyWith(fontSize: 14, color: tones.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── Error banner
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.pesan});
  final String pesan;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final accent = tones.level(AlertLevels.bahaya);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tones.card,
        borderRadius: BorderRadius.circular(AppLayout.radiusKartu),
        boxShadow: tones.softShadow(),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KotakIkon(
            ikon: Icons.error_outline_rounded,
            warna: accent,
            ukuran: 44,
            ukuranIkon: 22,
            tertutup: true,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              pesan,
              style: AppTeks.isi(tones).copyWith(fontSize: 14, color: accent),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────── Status hero
class _StatusHero extends StatelessWidget {
  const _StatusHero({
    required this.outcome,
    required this.sumberData,
    required this.sedangCek,
    this.onCek,
    this.onCekPaksa,
  });

  final CycleOutcome? outcome;
  final String sumberData;
  final bool sedangCek;
  final VoidCallback? onCek;
  final VoidCallback? onCekPaksa;

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    final tones = AppTones.of(context);
    final level = outcome?.levelTertinggi ?? AlertLevels.tidakDievaluasi;
    final hasil = outcome?.results ?? const <ConditionResult>[];
    final skorTertinggi = hasil.isEmpty
        ? 0
        : hasil.map((r) => r.skor).reduce((a, b) => a > b ? a : b);
    final tinta = AppTones.onGradien;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppLayout.radiusKartu),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tones.gradasiLevel(level),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 4,
            offset: Offset(4, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KotakIkon(
                ikon: LevelStyle.iconOf(level),
                warna: tinta,
                ukuran: 50,
                ukuranIkon: 28,
                lingkaran: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kamus.t('beranda.kondisi_saat_ini'),
                      style: AppTeks.labelSeksi(tones)
                          .copyWith(color: tinta.withValues(alpha: 0.75)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      outcome == null
                          ? kamus.t('beranda.belum_diperiksa')
                          : kamus.t('beranda.level_tertinggi', {
                              'level': level,
                            }),
                      style: AppTeks.judulHero(tones),
                    ),
                  ],
                ),
              ),
              if (outcome != null)
                _InfoSkorButton(
                  skor: skorTertinggi,
                  level: level,
                  tinta: tinta,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            LevelStyle.deskripsi(level, kamus),
            style: AppTeks.isi(tones)
                .copyWith(color: tinta.withValues(alpha: 0.85), fontSize: 14.5),
          ),
          if (outcome != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: BilasProgres(pct: skorTertinggi / 100, warna: tinta),
                ),
                const SizedBox(width: 10),
                Text(
                  '$skorTertinggi/100',
                  style: AppTeks.judulBaris(tones).copyWith(color: tinta),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _RingkasanKondisi(results: hasil),
          ],
          const SizedBox(height: 14),
          // sumber data chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.40),
              borderRadius: BorderRadius.circular(AppLayout.radiusPil),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_done_outlined,
                  size: 15,
                  color: tinta.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    kamus.t('beranda.sumber_otomatis', {
                      'sumber': kamus.sumberData(sumberData),
                    }),
                    style: AppTeks.labelSeksi(tones).copyWith(
                      color: tinta.withValues(alpha: 0.85),
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: onCek,
                    icon: sedangCek
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.monitor_heart_outlined, size: 20),
                    label: Text(
                      sedangCek
                          ? kamus.t('beranda.tombol_cek_sibuk')
                          : kamus.t('beranda.tombol_cek'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Lato',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: tinta.withValues(alpha: 0.92),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: kamus.t('beranda.tooltip_sinkron'),
                child: SizedBox(
                  height: 46,
                  width: 46,
                  child: IconButton(
                    onPressed: sedangCek ? null : onCekPaksa,
                    icon: const Icon(Icons.sync_rounded, size: 22),
                    color: tinta,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.40),
                      disabledBackgroundColor: Colors.white.withValues(
                        alpha: 0.18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppLayout.radiusPil,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────── Tombol bulat info skor di hero card
class _InfoSkorButton extends StatelessWidget {
  const _InfoSkorButton({
    required this.skor,
    required this.level,
    required this.tinta,
  });

  final int skor;
  final String level;
  final Color tinta;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _tampilkanInfoSkor(context, skor, level),
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.40),
          shape: BoxShape.circle,
        ),
        child: Text(
          '?',
          style: TextStyle(
            fontFamily: 'Lato',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: tinta,
          ),
        ),
      ),
    );
  }

  static void _tampilkanInfoSkor(BuildContext context, int skor, String level) {
    final kamus = L10n.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          LevelStyle.iconOf(level),
          size: 36,
          color: AppTones.of(ctx).level(level),
        ),
        title: Text(kamus.t('beranda.info_skor_judul')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(kamus.t('beranda.info_skor_isi')),
              const SizedBox(height: 12),
              _levelBaris('AMAN', AlertLevels.aman, ctx),
              _levelBaris('WASPADA', AlertLevels.waspada, ctx),
              _levelBaris('PERHATIAN', AlertLevels.perhatian, ctx),
              _levelBaris('BAHAYA', AlertLevels.bahaya, ctx),
              const SizedBox(height: 12),
              Text(
                kamus.t('beranda.info_skor_nol'),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(kamus.t('umum.tutup')),
          ),
        ],
      ),
    );
  }

  static Widget _levelBaris(String label, String level, BuildContext ctx) {
    final color = AppTones.of(ctx).level(level);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(LevelStyle.iconOf(level), size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────── Ringkasan tiga kondisi mini
class _RingkasanKondisi extends StatelessWidget {
  const _RingkasanKondisi({required this.results});
  final List<ConditionResult> results;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < results.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _KondisiRingkas(hasil: results[i])),
        ],
      ],
    );
  }
}

class _KondisiRingkas extends StatelessWidget {
  const _KondisiRingkas({required this.hasil});
  final ConditionResult hasil;

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    final tones = AppTones.of(context);
    final accent = tones.level(hasil.level);
    final tinta = AppTones.onGradien;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(AppLayout.radiusGrup),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(KondisiStyle.iconOf(hasil.kondisi), size: 14, color: accent),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  KondisiStyle.shortLabel(hasil.kondisi, kamus),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: tinta,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${hasil.skor}',
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1,
                  color: tinta,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  kamus.t('beranda.dari_seratus'),
                  style: TextStyle(
                    fontFamily: 'Lato',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: tinta.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              hasil.level,
              style: TextStyle(
                fontFamily: 'Lato',
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────── Hasil kondisi lengkap
/// Kartu hasil satu kondisi — bisa diekspansi untuk melihat sinyal yang diperiksa.
class HasilKartu extends StatefulWidget {
  const HasilKartu({required this.hasil, super.key});
  final ConditionResult hasil;

  @override
  State<HasilKartu> createState() => _HasilKartuState();
}

class _HasilKartuState extends State<HasilKartu> {
  bool _ekspansi = false;

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    final tones = AppTones.of(context);
    final accent = tones.level(widget.hasil.level);
    final intervensi = widget.hasil.intervensi.trim();
    final alasan = widget.hasil.alasanTeks(kamus);

    return Container(
      decoration: BoxDecoration(
        color: tones.card,
        borderRadius: BorderRadius.circular(AppLayout.radiusKartu),
        boxShadow: tones.softShadow(),
      ),
      child: Column(
        children: [
          // ── Header kartu ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KotakIkon(
                      ikon: KondisiStyle.iconOf(widget.hasil.kondisi),
                      warna: accent,
                      ukuran: 44,
                      ukuranIkon: 22,
                      tertutup: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.hasil.kondisi,
                            style: AppTeks.judulKartu(tones)
                                .copyWith(fontSize: 17),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            KondisiStyle.subtitle(widget.hasil.kondisi, kamus),
                            style: AppTeks.labelSeksi(tones),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: [
                              LevelChip(level: widget.hasil.level),
                              KalibrasiChip(kalibrasi: widget.hasil.kalibrasi),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    ScoreGauge(
                      skor: widget.hasil.skor,
                      level: widget.hasil.level,
                      size: 50,
                    ),
                  ],
                ),
                // ── Kenapa skor ─────────────────────────────────────────────
                const SizedBox(height: 12),
                Text(
                  alasan.isEmpty
                      ? kamus.t('umum.semua_normal_kapital')
                      : kamus.t('umum.skor_naik'),
                  style: AppTeks.labelSeksi(tones)
                      .copyWith(color: accent, fontSize: 11),
                ),
                const SizedBox(height: 5),
                if (alasan.isEmpty)
                  _SkorNolPenjelasan(hasil: widget.hasil)
                else
                  ...alasan.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              a,
                              style: AppTeks.isi(tones).copyWith(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // ── Saran tindakan ───────────────────────────────────────────
                if (intervensi.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: tones.levelSurface(widget.hasil.level),
                      borderRadius: BorderRadius.circular(AppLayout.radiusGrup),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 16,
                          color: accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kamus.t('umum.saran_tindakan'),
                                style: AppTeks.labelSeksi(tones)
                                    .copyWith(color: accent),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                intervensi,
                                style: AppTeks.isi(tones)
                                    .copyWith(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // ── Ekspansi toggle ──────────────────────────────────────────
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => setState(() => _ekspansi = !_ekspansi),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _ekspansi
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: tones.aksen,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        kamus.t('beranda.sinyal_diperiksa'),
                        style: AppTeks.labelSeksi(tones)
                            .copyWith(color: tones.aksen, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Detail sinyal yang diperiksa ────────────────────────────────────
          if (_ekspansi) ...[
            Divider(height: 1, thickness: 1, color: tones.line),
            _DetailPemeriksaan(
              pemeriksaan: widget.hasil.pemeriksaan,
              level: widget.hasil.level,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────── Penjelasan ketika skor 0 (semua normal)
class _SkorNolPenjelasan extends StatelessWidget {
  const _SkorNolPenjelasan({required this.hasil});
  final ConditionResult hasil;

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    final tones = AppTones.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tones.aman.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppLayout.radiusGrup),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: tones.aman),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kamus.t('beranda.tidak_ada_pemicu'),
                  style: AppTeks.isi(tones).copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                Text(
                  kamus.t('beranda.skor_nol_ringkas'),
                  style: AppTeks.labelSeksi(tones)
                      .copyWith(color: tones.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────── Daftar sinyal yang diperiksa (ekspansi kartu)
class _DetailPemeriksaan extends StatelessWidget {
  const _DetailPemeriksaan({required this.pemeriksaan, required this.level});

  final List<Pemeriksaan> pemeriksaan;
  final String level;

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    final tones = AppTones.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in pemeriksaan)
            _BarisPemeriksaan(periksa: p, tones: tones, kamus: kamus),
        ],
      ),
    );
  }
}

class _BarisPemeriksaan extends StatelessWidget {
  const _BarisPemeriksaan({
    required this.periksa,
    required this.tones,
    required this.kamus,
  });

  final Pemeriksaan periksa;
  final AppTones tones;
  final L10n kamus;

  @override
  Widget build(BuildContext context) {
    final tersedia = periksa.tersedia;
    final terpicu = periksa.terpicu;
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (!tersedia) {
      statusColor = tones.inkSoft;
      statusIcon = Icons.remove_circle_outline;
      statusLabel = kamus.t('beranda.sinyal_tidak_ada');
    } else if (terpicu) {
      statusColor = tones.waspada;
      statusIcon = Icons.warning_amber_rounded;
      statusLabel = kamus.t('beranda.sinyal_terpicu');
    } else {
      statusColor = tones.aman;
      statusIcon = Icons.check_circle_outline;
      statusLabel = kamus.t('beranda.sinyal_normal');
    }

    final nilaiTeks = periksa.nilai != null
        ? '${periksa.nilai!.toStringAsFixed(periksa.nilai! == periksa.nilai!.roundToDouble() ? 0 : 1)}${periksa.satuan}'
        : (periksa.nilaiTeks != null
              ? kamus.t('fase.${periksa.nilaiTeks}', const <String, String>{})
              : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kamus.t(periksa.labelKey),
                  style: AppTeks.isi(tones).copyWith(fontSize: 13.5),
                ),
                if (periksa.ambang != null)
                  Text(
                    kamus.t('beranda.sinyal_ambang', {
                      'nilai':
                          '${periksa.ambang!.toStringAsFixed(periksa.ambang! == periksa.ambang!.roundToDouble() ? 0 : 1)}${periksa.satuan}',
                    }),
                    style: AppTeks.labelSeksi(tones),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (nilaiTeks != null)
                Text(
                  nilaiTeks,
                  style: AppTeks.judulBaris(tones).copyWith(
                    fontSize: 13.5,
                    color: tersedia ? tones.ink : tones.inkSoft,
                  ),
                ),
              Text(
                statusLabel,
                style: AppTeks.labelSeksi(tones)
                    .copyWith(color: statusColor, fontSize: 10.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────── Status sinyal dari snapshot (izin/kosong)
class _StatusSinyal extends StatelessWidget {
  const _StatusSinyal({required this.snapshot, required this.onMintaIzin});

  final SensorSnapshot snapshot;
  final VoidCallback onMintaIzin;

  static final List<(String, String, IconData)> _sinyal = [
    ('heart_rate', 'sensor.jantung', Icons.favorite_rounded),
    ('hrv', 'sensor.hrv', Icons.show_chart_rounded),
    ('spo2', 'sensor.oksigen', Icons.water_drop_rounded),
    ('resp_rate', 'sensor.napas', Icons.air_rounded),
    ('sleep', 'sensor.tidur', Icons.bedtime_rounded),
    ('exercise', 'sensor.aktivitas', Icons.directions_run_rounded),
    ('steps', 'sensor.aktivitas', Icons.directions_walk_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    final tones = AppTones.of(context);
    final adaIzinKurang = _sinyal.any((s) => snapshot.status(s.$1) == 'izin');
    final okCount = _sinyal.where((s) => snapshot.status(s.$1) == 'ok').length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tones.card,
        borderRadius: BorderRadius.circular(AppLayout.radiusKartu),
        boxShadow: tones.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  kamus.t('beranda.sumber_data_ringkas', {
                    'ok': '$okCount',
                    'total': '${_sinyal.length}',
                  }),
                  style: AppTeks.judulBaris(tones).copyWith(fontSize: 15),
                ),
              ),
              if (adaIzinKurang)
                TextButton.icon(
                  onPressed: onMintaIzin,
                  icon: const Icon(Icons.lock_open_rounded, size: 16),
                  label: Text(
                    kamus.t('beranda.minta_izin'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _sinyal)
                _SinyalChip(
                  kunci: s.$1,
                  label: kamus.t(s.$2),
                  ikon: s.$3,
                  status: snapshot.status(s.$1),
                  jumlah: snapshot.jumlah(s.$1),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            kamus.t('beranda.sinkron_tips'),
            style: AppTeks.labelSeksi(tones)
                .copyWith(color: tones.inkSoft, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SinyalChip extends StatelessWidget {
  const _SinyalChip({
    required this.kunci,
    required this.label,
    required this.ikon,
    required this.status,
    this.jumlah,
  });

  final String kunci;
  final String label;
  final IconData ikon;
  final String status;
  final int? jumlah;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    Color color;
    IconData statusIcon;
    switch (status) {
      case 'ok':
        color = tones.aman;
        statusIcon = Icons.check_circle_rounded;
      case 'izin':
        color = tones.waspada;
        statusIcon = Icons.lock_outline_rounded;
      case 'gagal':
        color = tones.bahaya;
        statusIcon = Icons.error_outline_rounded;
      case 'kosong':
      default:
        color = tones.inkSoft;
        statusIcon = Icons.radio_button_unchecked_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Lato',
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Icon(statusIcon, size: 12, color: color),
          if (jumlah != null && jumlah! > 0) ...[
            const SizedBox(width: 3),
            Text(
              '$jumlah',
              style: TextStyle(fontFamily: 'Lato', fontSize: 10, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────── Sensor terkelompok (3 grup)
class _GrupSensor extends StatelessWidget {
  const _GrupSensor({required this.snapshot});
  final SensorSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    return Column(
      children: [
        _KartuGrupSensor(
          judul: kamus.t('beranda.grup_jantung'),
          ikon: Icons.favorite_border_rounded,
          tiles: _tileJantung(context, snapshot, kamus),
        ),
        const SizedBox(height: 12),
        _KartuGrupSensor(
          judul: kamus.t('beranda.grup_tidur'),
          ikon: Icons.bedtime_outlined,
          tiles: _tileTidur(context, snapshot, kamus),
        ),
        const SizedBox(height: 12),
        _KartuGrupSensor(
          judul: kamus.t('beranda.grup_lingkungan'),
          ikon: Icons.eco_outlined,
          tiles: _tileLingkungan(context, snapshot, kamus),
        ),
      ],
    );
  }

  List<_TileData> _tileJantung(
    BuildContext context,
    SensorSnapshot snap,
    L10n kamus,
  ) {
    final hr = snap.heartRate;
    final spo2 = snap.spo2;
    final rr = snap.respRate;
    final hrv = snap.hrv;
    return [
      _TileData(
        label: kamus.t('sensor.grid.jantung'),
        value: hr == null ? null : '${hr.latestBpm}',
        unit: 'bpm',
        ikon: Icons.favorite_rounded,
        detail: hr == null
            ? kamus.t('sensor.jantung_kosong')
            : kamus.t('sensor.jantung_detail', {
                'min': '${hr.minBpm}',
                'max': '${hr.maxBpm}',
                'n': '${hr.sampleCount}',
              }),
        status: snap.status('heart_rate'),
        metrikInfo: _metrikInfo(context, 'jantung', kamus),
      ),
      _TileData(
        label: kamus.t('sensor.grid.hrv'),
        value: hrv?.avgMs.toStringAsFixed(0),
        unit: 'ms',
        ikon: Icons.ssid_chart_rounded,
        detail: hrv == null
            ? kamus.t('sensor.hrv_kosong')
            : kamus.t('sensor.hrv_detail', {
                'min': hrv.minMs.toStringAsFixed(0),
              }),
        status: snap.status('hrv'),
        metrikInfo: _metrikInfo(context, 'hrv', kamus),
      ),
      _TileData(
        label: kamus.t('sensor.grid.oksigen'),
        value: spo2?.latestPct.toStringAsFixed(0),
        unit: '%',
        ikon: Icons.water_drop_rounded,
        detail: spo2 == null
            ? kamus.t('sensor.oksigen_kosong')
            : kamus.t('sensor.oksigen_detail', {
                'avg': spo2.avgPct.toStringAsFixed(1),
                'n': '${spo2.sampleCount}',
              }),
        status: snap.status('spo2'),
        metrikInfo: _metrikInfo(context, 'oksigen', kamus),
      ),
      _TileData(
        label: kamus.t('sensor.grid.napas'),
        value: rr?.latestPerMenit.toStringAsFixed(0),
        unit: '/${kamus.t('sensor.menit_singkat')}',
        ikon: Icons.air_rounded,
        detail: rr == null
            ? kamus.t('sensor.napas_kosong')
            : kamus.t('sensor.napas_detail', {
                'max': rr.maxPerMenit.toStringAsFixed(0),
              }),
        status: snap.status('resp_rate'),
        metrikInfo: _metrikInfo(context, 'napas', kamus),
      ),
    ];
  }

  List<_TileData> _tileTidur(
    BuildContext context,
    SensorSnapshot snap,
    L10n kamus,
  ) {
    final tidur = snap.sleep;
    final aktivitas = snap.activity;
    return [
      _TileData(
        label: kamus.t('sensor.grid.tidur'),
        value: tidur == null
            ? null
            : (tidur.durationMinutes / 60).toStringAsFixed(1),
        unit: kamus.satuan('jam'),
        ikon: Icons.bedtime_rounded,
        detail: tidur == null
            ? kamus.t('sensor.tidur_kosong')
            : kamus.t('sensor.tidur_detail', {
                'efisiensi': tidur.efficiencyPct?.toStringAsFixed(0) ?? '—',
              }),
        status: snap.status('sleep'),
        metrikInfo: _metrikInfo(context, 'tidur', kamus),
      ),
      _TileData(
        label: kamus.t('sensor.efisiensi_tidur'),
        value: tidur?.efficiencyPct?.toStringAsFixed(0),
        unit: '%',
        ikon: Icons.nightlight_round_rounded,
        detail: tidur?.efficiencyPct == null
            ? kamus.t('sensor.tidur_kosong')
            : kamus.t('sensor.tidur_efisiensi_detail', {
                'waso': '${tidur?.wasoMinutes ?? 0}',
              }),
        status: tidur == null ? snap.status('sleep') : 'ok',
        metrikInfo: _metrikInfo(context, 'efisiensi_tidur', kamus),
      ),
      _TileData(
        label: kamus.t('sensor.olahraga'),
        value: aktivitas?.exerciseMinutes.toStringAsFixed(0),
        unit: kamus.satuan('mnt'),
        ikon: Icons.fitness_center_rounded,
        detail: aktivitas == null
            ? kamus.t('sensor.aktivitas_kosong')
            : kamus.t('sensor.olahraga_detail', {
                'sesi': '${aktivitas.sessionCount}',
              }),
        status: snap.status('exercise'),
        metrikInfo: _metrikInfo(context, 'olahraga', kamus),
      ),
      _TileData(
        label: kamus.t('sensor.label_langkah'),
        value: aktivitas?.steps?.toString(),
        unit: kamus.satuan('langkah'),
        ikon: Icons.directions_walk_rounded,
        detail: aktivitas?.steps == null
            ? kamus.t('sensor.aktivitas_kosong')
            : kamus.t('sensor.langkah_detail'),
        status: snap.status('steps'),
        metrikInfo: _metrikInfo(context, 'langkah', kamus),
      ),
    ];
  }

  List<_TileData> _tileLingkungan(
    BuildContext context,
    SensorSnapshot snap,
    L10n kamus,
  ) {
    return [
      _TileData(
        label: kamus.t('sensor.grid.suhu'),
        value: snap.suhu?.toStringAsFixed(1),
        unit: '°C',
        ikon: Icons.device_thermostat_rounded,
        detail: snap.suhu == null
            ? kamus.t('sensor.suhu_kosong')
            : kamus.t('sensor.suhu_detail', {
                'rh': snap.kelembapan?.toStringAsFixed(0) ?? '—',
                'angin': snap.angin?.toStringAsFixed(1) ?? '—',
              }),
        status: snap.suhu == null ? 'kosong' : 'ok',
        metrikInfo: _metrikInfo(context, 'suhu', kamus),
      ),
      _TileData(
        label: kamus.t('sensor.kelembapan'),
        value: snap.kelembapan?.toStringAsFixed(0),
        unit: '%',
        ikon: Icons.water_outlined,
        detail: snap.kelembapan == null
            ? kamus.t('sensor.suhu_kosong')
            : kamus.t('sensor.kelembapan_detail', {
                'rh': snap.kelembapan!.toStringAsFixed(0),
              }),
        status: snap.kelembapan == null ? 'kosong' : 'ok',
        metrikInfo: _metrikInfo(context, 'kelembapan', kamus),
      ),
      _TileData(
        label: kamus.t('label.angin'),
        value: snap.angin?.toStringAsFixed(1),
        unit: 'm/s',
        ikon: Icons.wind_power_rounded,
        detail: snap.angin == null
            ? kamus.t('sensor.suhu_kosong')
            : kamus.t('sensor.angin_detail', {
                'angin': snap.angin!.toStringAsFixed(1),
              }),
        status: snap.angin == null ? 'kosong' : 'ok',
        metrikInfo: _metrikInfo(context, 'angin', kamus),
      ),
      _TileData(
        label: kamus.t('sensor.grid.pm25'),
        value: snap.pm25?.toStringAsFixed(0),
        unit: 'µg/m³',
        ikon: Icons.blur_on_rounded,
        detail: snap.pm25 == null
            ? kamus.t('sensor.udara_kosong')
            : kamus.t('sensor.pm25_detail'),
        status: snap.pm25 == null ? 'kosong' : 'ok',
        metrikInfo: _metrikInfo(context, 'pm25', kamus),
      ),
    ];
  }

  static Map<String, String> _metrikInfo(
    BuildContext context,
    String metrik,
    L10n kamus,
  ) {
    return {
      'normal': kamus.t('metrik.$metrik.normal'),
      'penjelasan': kamus.t('metrik.$metrik.penjelasan'),
      'dampak': kamus.t('metrik.$metrik.dampak'),
    };
  }
}

// ─────────────────────────────────────────────── Kartu grup sensor (2 kolom)
class _KartuGrupSensor extends StatelessWidget {
  const _KartuGrupSensor({
    required this.judul,
    required this.ikon,
    required this.tiles,
  });

  final String judul;
  final IconData ikon;
  final List<_TileData> tiles;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tones.card,
        borderRadius: BorderRadius.circular(AppLayout.radiusKartu),
        boxShadow: tones.softShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 16, color: tones.aksen),
              const SizedBox(width: 7),
              Text(
                judul,
                style: AppTeks.judulBaris(tones).copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.0,
            children: [for (final t in tiles) _TileSensor(data: t)],
          ),
        ],
      ),
    );
  }
}

class _TileData {
  const _TileData({
    required this.label,
    required this.value,
    required this.unit,
    required this.ikon,
    required this.detail,
    required this.status,
    required this.metrikInfo,
  });

  final String label;
  final String? value;
  final String unit;
  final IconData ikon;
  final String detail;
  final String status;
  final Map<String, String> metrikInfo;
}

class _TileSensor extends StatelessWidget {
  const _TileSensor({required this.data});
  final _TileData data;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final ada = data.value != null;
    Color statusColor;
    switch (data.status) {
      case 'ok':
        statusColor = tones.aman;
      case 'izin':
        statusColor = tones.waspada;
      case 'gagal':
        statusColor = tones.bahaya;
      default:
        statusColor = tones.inkSoft;
    }

    return GestureDetector(
      onTap: () => _tampilkanDetail(context, data),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tones.panel,
          borderRadius: BorderRadius.circular(AppLayout.radiusGrup + 2),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(data.ikon, size: 18, color: statusColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTeks.labelSeksi(tones).copyWith(fontSize: 10.5),
                  ),
                  const SizedBox(height: 2),
                  ada
                      ? Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: data.value!,
                                style: TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: tones.ink,
                                  height: 1.1,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              TextSpan(
                                text: ' ${data.unit}',
                                style: TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 10,
                                  color: tones.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Text(
                          _statusLabel(data.status, context),
                          style: AppTeks.labelSeksi(tones)
                              .copyWith(color: statusColor, fontSize: 11),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(String status, BuildContext ctx) {
    final kamus = L10n.of(ctx);
    return switch (status) {
      'izin' => kamus.t('beranda.status_izin'),
      'gagal' => kamus.t('beranda.status_gagal'),
      _ => kamus.t('beranda.status_kosong'),
    };
  }

  static void _tampilkanDetail(BuildContext context, _TileData data) {
    final kamus = L10n.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final tones = AppTones.of(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tones.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  KotakIkon(
                    ikon: data.ikon,
                    warna: tones.aksen,
                    ukuran: 46,
                    ukuranIkon: 24,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.label, style: AppTeks.judulKartu(tones)),
                      if (data.value != null)
                        Text(
                          '${data.value} ${data.unit}',
                          style: AppTeks.judulHalaman(tones)
                              .copyWith(color: tones.aksen),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                data.metrikInfo['penjelasan'] ?? '',
                style: AppTeks.isi(tones).copyWith(fontSize: 15),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                ikon: Icons.straighten_rounded,
                label: kamus.t('beranda.metrik_normal'),
                nilai: data.metrikInfo['normal'] ?? '',
                tones: tones,
              ),
              const SizedBox(height: 8),
              _InfoRow(
                ikon: Icons.hub_outlined,
                label: kamus.t('beranda.metrik_dampak'),
                nilai: data.metrikInfo['dampak'] ?? '',
                tones: tones,
              ),
              const SizedBox(height: 14),
              Text(data.detail, style: AppTeks.labelSeksi(tones)),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.ikon,
    required this.label,
    required this.nilai,
    required this.tones,
  });

  final IconData ikon;
  final String label;
  final String nilai;
  final AppTones tones;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(ikon, size: 16, color: tones.aksen),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTeks.isi(tones).copyWith(fontSize: 13.5),
              children: [
                TextSpan(
                  text: '$label ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: nilai),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────── Kalibrasi ambang ringkas
class _KalibrasiKartu extends StatelessWidget {
  const _KalibrasiKartu({required this.outcome});
  final CycleOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    final tones = AppTones.of(context);
    final ambang = outcome.ambang;
    final data = outcome.snapshot;

    return SectionCard(
      judul: kamus.t('beranda.ambang_judul'),
      ikon: Icons.tune_rounded,
      deskripsi: kamus.t('beranda.ambang_deskripsi', {
        'hari': '${ambang.baseline.jendelaHari}',
      }),
      children: [
        for (final info in ambang.provenance)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: tones.tier(info.tier.name),
                    borderRadius: BorderRadius.circular(AppLayout.radiusGrup),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.label(kamus),
                        style: AppTeks.isi(tones).copyWith(fontSize: 14.5),
                      ),
                      if (info.detailKey != null)
                        Text(
                          info.detail(kamus),
                          style: AppTeks.labelSeksi(tones),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${info.nilaiTeks}${kamus.satuan(info.satuan)}',
                  style: AppTeks.angka(tones).copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: tones.tier(info.tier.name),
                  ),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            InfoChip(teks: kamus.t('beranda.tier_personal'), warna: tones.aman),
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
        const SizedBox(height: 16),
        Divider(height: 1, thickness: 1, color: tones.line),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final sumber in data.sumberAktif)
              InfoChip(teks: kamus.sumberData(sumber), berat: FontWeight.w600),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          kamus.t('beranda.status_siklus', {
            'sumber': '${data.sumberAktif.length}',
            'sinyal': '${data.jumlahSinyal}',
            'keyakinan': data.confidence,
            'ambang': kamus.t('tier.${ambang.tierAmbangSuhu.name}'),
          }),
          style: AppTeks.isi(tones)
              .copyWith(fontSize: 13, color: tones.inkSoft),
        ),
      ],
    );
  }
}
