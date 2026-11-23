import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../l10n/l10n.dart';
import '../models/condition_result.dart';
import '../models/health_profile.dart';
import '../models/pemeriksaan.dart';
import '../models/air_quality.dart';
import '../models/sensor_snapshot.dart';
import '../models/weather_forecast.dart';
import '../services/alert_orchestrator.dart';
import '../services/health_services.dart';
import '../widgets/jb.dart';
import 'breathe_screen.dart';
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
    final outcome = _outcome;
    final hasil = outcome?.results ?? const <ConditionResult>[];
    final alert = hasil.where((r) => AlertLevels.levelButuhAlert(r.level));
    final udara = outcome?.udara;
    final cuaca = outcome?.cuaca;
    final aqi = udara?.usAqi ?? _aqiDariPm25(udara?.pm25);
    final status = _statusAqi(aqi);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadProfil();
          await _jalanCek();
        },
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  32,
                  20,
                  AppLayout.bawahKonten(context),
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _sapaan(kamus, tones, nama, alert.length),
                    const SizedBox(height: 16),
                    _HeroAqi(
                      aqi: aqi,
                      status: status,
                      kamus: kamus,
                      tones: tones,
                      diperbarui: outcome?.at,
                    ),
                    if (alert.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _AlertBanner(
                        hasil: alert.reduce((a, b) => a.skor >= b.skor ? a : b),
                        kamus: kamus,
                        tones: tones,
                        onTap: () => Navigator.pushNamed(context, '/notifications'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _tombolSinkron(kamus, tones),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(
                        pesan: kamus.t('beranda.gagal', {'error': _error!}),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _MiniStats(
                      udara: udara,
                      cuaca: cuaca,
                      kamus: kamus,
                      tones: tones,
                    ),
                    if (!AppConfig.ENABLE_NOTIFICATIONS) ...[
                      const SizedBox(height: 16),
                      const _ObservationBanner(),
                    ],
                    const SizedBox(height: 16),
                    _KondisiRingkas(
                      hasil: hasil,
                      outcome: outcome,
                      kamus: kamus,
                      tones: tones,
                      onTap: outcome == null
                          ? null
                          : () => _bukaKondisi(context, outcome),
                    ),
                    const SizedBox(height: 16),
                    _PemantauanKartu(
                      outcome: outcome,
                      kamus: kamus,
                      tones: tones,
                      onTap: outcome == null
                          ? null
                          : () => _bukaPemantauan(context, outcome),
                    ),
                    JbSectionTitle(
                      title: kamus.t('beranda.kebiasaan_judul'),
                      trailing: TextButton(
                        onPressed: () => _bukaNapas(context),
                        child: Text(kamus.t('beranda.lihat_semua')),
                      ),
                    ),
                    _KartuKebiasaan(
                      cuaca: cuaca,
                      status: status,
                      kamus: kamus,
                      tones: tones,
                      onNapas: () => _bukaNapas(context),
                      onSinkron: _sedangCek
                          ? null
                          : () => _jalanCek(paksaCuaca: true),
                    ),
                    const SizedBox(height: 8),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Detail kondisi dibuka dari kartu ringkas: alasan skor, sinyal yang
  /// diperiksa, dan saran tindakan tidak lagi memenuhi Beranda.
  void _bukaKondisi(BuildContext context, CycleOutcome outcome) {
    final kamus = L10n.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LembarDetail(
        judul: kamus.t('beranda.kondisi_saat_ini'),
        sub: kamus.t('beranda.kondisi_sheet_sub'),
        anak: Column(
          children: [
            for (final r in outcome.results) ...[
              HasilKartu(hasil: r),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  /// Data sensor, status sumber, dan kalibrasi ambang dibuka dari satu kartu
  /// "Pemantauan" agar Beranda tetap ringkas.
  void _bukaPemantauan(BuildContext context, CycleOutcome outcome) {
    final kamus = L10n.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LembarDetail(
        judul: kamus.t('beranda.pemantauan_judul'),
        sub: kamus.t('beranda.pemantauan_sub'),
        anak: Column(
          children: [
            _StatusSinyal(
              snapshot: outcome.snapshot,
              onMintaIzin: () {
                Navigator.pop(context);
                _mintaIzin();
              },
            ),
            const SizedBox(height: 14),
            _GrupSensor(snapshot: outcome.snapshot),
            const SizedBox(height: 14),
            _KalibrasiKartu(outcome: outcome),
            const SizedBox(height: 14),
            _SumberCatatan(
              sumber: widget.healthService.sourceLabel,
              kamus: kamus,
            ),
          ],
        ),
      ),
    );
  }

  void _bukaNapas(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const BreatheScreen()));
  }

  /// Sapaan + pintasan profil. Tinggi tetap supaya tanggal tidak melompat
  /// saat nama pengguna kosong.
  Widget _sapaan(L10n kamus, AppTones tones, String? nama, int jumlahAlert) {
    final jam = DateTime.now().hour;
    final kunci = jam < 11
        ? 'beranda.selamat_pagi'
        : (jam < 15
              ? 'beranda.selamat_siang'
              : (jam < 19 ? 'beranda.selamat_sore' : 'beranda.selamat_malam'));
    final adaNama = nama != null && nama.trim().isNotEmpty;
    final pendek = !adaNama
        ? ''
        : (nama.length > 20 ? '${nama.substring(0, 18)}…' : nama);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (adaNama) ...[
                Text(
                  kamus.t(kunci),
                  style: AppTeks.labelSeksi(tones)
                      .copyWith(fontSize: 12.5, color: tones.inkSoft),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                adaNama ? pendek : kamus.t(kunci),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTeks.sapaan(tones).copyWith(fontSize: 24),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        JbIconButton(
          icon: Icons.account_circle_rounded,
          tooltip: kamus.t('nav.profil'),
          onTap: () => Navigator.pushNamed(context, '/profile'),
        ),
      ],
    );
  }

  Widget _tombolSinkron(L10n kamus, AppTones tones) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _sedangCek ? null : _jalanCek,
              icon: _sedangCek
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync_rounded, size: 20),
              label: Text(
                _sedangCek
                    ? kamus.t('beranda.tombol_cek_sibuk')
                    : kamus.t('beranda.tombol_cek'),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: kamus.t('beranda.tooltip_sinkron'),
          child: SizedBox(
            height: 48,
            width: 48,
            child: IconButton(
              onPressed: _sedangCek ? null : () => _jalanCek(paksaCuaca: true),
              icon: const Icon(Icons.refresh_rounded, size: 21),
              style: IconButton.styleFrom(
                backgroundColor: tones.card,
                foregroundColor: tones.aksenDeep,
                shape: const CircleBorder(),
                elevation: 2,
                shadowColor: tones.bayangan.withValues(alpha: 0.2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// US AQI perkiraan dari PM2.5 bila API tidak mengirim `us_aqi` langsung.
  /// Breakpoint-nya breakpoint EPA 2024, bukan angka karangan.
  static double? _aqiDariPm25(double? pm25) {
    if (pm25 == null) return null;
    const batas = [
      (0.0, 12.0, 0.0, 50.0),
      (12.1, 35.4, 51.0, 100.0),
      (35.5, 55.4, 101.0, 150.0),
      (55.5, 150.4, 151.0, 200.0),
      (150.5, 250.4, 201.0, 300.0),
      (250.5, 500.4, 301.0, 500.0),
    ];
    for (final b in batas) {
      if (pm25 <= b.$2) {
        final rasio = (pm25 - b.$1) / (b.$2 - b.$1);
        return (b.$3 + rasio * (b.$4 - b.$3)).clamp(0, 500);
      }
    }
    return 500;
  }

  static _StatusAqi _statusAqi(double? aqi) {
    if (aqi == null) {
      return const _StatusAqi(
        'beranda.aqi_status_kosong',
        'beranda.aqi_kosong',
        AppPalette.netral,
        null,
      );
    }
    if (aqi <= 50) {
      return const _StatusAqi(
        'beranda.status_baik',
        'beranda.status_baik_desc',
        AppPalette.aqiGood,
        50,
      );
    }
    if (aqi <= 100) {
      return const _StatusAqi(
        'beranda.status_sedang',
        'beranda.status_sedang_desc',
        AppPalette.aqiModerate,
        100,
      );
    }
    if (aqi <= 150) {
      return const _StatusAqi(
        'beranda.status_sensitif',
        'beranda.status_sensitif_desc',
        AppPalette.aqiSensitive,
        150,
      );
    }
    if (aqi <= 200) {
      return const _StatusAqi(
        'beranda.status_tidak_sehat',
        'beranda.status_tidak_sehat_desc',
        AppPalette.aqiUnhealthy,
        200,
      );
    }
    return const _StatusAqi(
      'beranda.status_berbahaya',
      'beranda.status_berbahaya_desc',
      AppPalette.aqiHazardous,
      null,
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
    return JbCard(
      color: accent.withValues(alpha: 0.08),
      border: Border.all(color: accent.withValues(alpha: 0.20)),
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
                  style: AppTeks.isiSoft(tones).copyWith(fontSize: 13),
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
    return JbCard(
      color: accent.withValues(alpha: 0.07),
      border: Border.all(color: accent.withValues(alpha: 0.20)),
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
              style: AppTeks.isi(tones).copyWith(fontSize: 13, color: accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Status satu nilai AQI: kunci label, kunci deskripsi, warna, dan ambang
/// berikutnya (null untuk pita terakhir).
class _StatusAqi {
  const _StatusAqi(this.labelKey, this.descKey, this.color, this.next);

  final String labelKey;
  final String descKey;
  final Color color;
  final int? next;
}

// ────────────────────────────────────────────────────────── Kartu hero AQI
class _HeroAqi extends StatelessWidget {
  const _HeroAqi({
    required this.aqi,
    required this.status,
    required this.kamus,
    required this.tones,
    this.diperbarui,
  });

  final double? aqi;
  final _StatusAqi status;
  final L10n kamus;
  final AppTones tones;
  final DateTime? diperbarui;

  String _waktu() {
    if (diperbarui == null) return kamus.t('umum.belum_ada');
    final selisih = DateTime.now().difference(diperbarui!);
    if (selisih.inMinutes < 1) return kamus.t('beranda.aqi_baru');
    return kamus.t('beranda.aqi_menit_lalu', {'n': '${selisih.inMinutes}'});
  }

  @override
  Widget build(BuildContext context) {
    final nilai = aqi?.round();
    final menuju = status.next == null || aqi == null
        ? null
        : (status.next! - aqi!).clamp(0, 999).round();
    return JbCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.air_rounded, size: 17, color: tones.aksenDeep),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  kamus.t('beranda.aqi_judul'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTeks.judulBaris(tones).copyWith(fontSize: 14.5),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.schedule_rounded, size: 13, color: tones.inkSoft),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  kamus.t('beranda.aqi_diperbarui', {'waktu': _waktu()}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTeks.labelSeksi(tones).copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                nilai?.toString() ?? '--',
                style: AppTeks.displayAngka(tones),
              ),
              const SizedBox(width: 7),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  kamus.t('beranda.aqi_unit'),
                  style: AppTeks.labelSeksi(tones)
                      .copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Flexible(
                child: JbStatusPill(
                  label: nilai == null
                      ? kamus.t(status.descKey)
                      : '${kamus.t(status.labelKey)} • ${kamus.t(status.descKey)}',
                  color: status.color,
                  icon: nilai == null
                      ? Icons.help_outline_rounded
                      : Icons.eco_rounded,
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          JbAqiBar(aqi: aqi ?? 0, tampilPenanda: aqi != null),
          const SizedBox(height: 9),
          Row(
            children: [
              Text(
                '0–50',
                style: AppTeks.labelSeksi(tones).copyWith(fontSize: 11),
              ),
              Expanded(
                child: Text(
                  menuju == null
                      ? ''
                      : kamus.t('beranda.aqi_menuju', {
                          'n': '$menuju',
                          'status': kamus.t(
                            status.next == 50
                                ? 'beranda.status_sedang'
                                : (status.next == 100
                                      ? 'beranda.status_sensitif'
                                      : (status.next == 150
                                            ? 'beranda.status_tidak_sehat'
                                            : 'beranda.status_berbahaya')),
                          ),
                        }),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTeks.labelSeksi(tones).copyWith(fontSize: 11),
                ),
              ),
              Text(
                kamus.t('beranda.aqi_skala_atas'),
                style: AppTeks.labelSeksi(tones).copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────── Banner saran tindakan
class _AlertBanner extends StatelessWidget {
  const _AlertBanner({
    required this.hasil,
    required this.kamus,
    required this.tones,
    required this.onTap,
  });

  final ConditionResult hasil;
  final L10n kamus;
  final AppTones tones;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final warna = tones.level(hasil.level);
    final alasan = hasil.alasanTeks(kamus);
    return JbCard(
      color: tones.waspada.withValues(alpha: 0.09),
      border: Border.all(color: tones.waspada.withValues(alpha: 0.22)),
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          KotakIkon(
            ikon: LevelStyle.iconOf(hasil.level),
            warna: warna,
            ukuran: 44,
            ukuranIkon: 22,
            tertutup: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                JbStatusPill(
                  label: '${hasil.level} • ${hasil.kondisi}',
                  color: warna,
                  compact: true,
                ),
                const SizedBox(height: 6),
                Text(
                  alasan.isEmpty
                      ? kamus.t('beranda.alert_banner')
                      : alasan.first,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTeks.isi(tones).copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, size: 20, color: tones.inkSoft),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────── Tiga kartu statistik mini
class _MiniStats extends StatelessWidget {
  const _MiniStats({
    required this.udara,
    required this.cuaca,
    required this.kamus,
    required this.tones,
  });

  final AirQuality? udara;
  final WeatherForecast? cuaca;
  final L10n kamus;
  final AppTones tones;

  @override
  Widget build(BuildContext context) {
    final pm25 = udara?.pm25;
    final pm10 = udara?.pm10;
    final suhu = cuaca?.temperature;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: JbMiniStat(
            label: 'PM2.5',
            value: pm25 == null ? '--' : _angka(pm25),
            unit: 'µg/m³',
            color: pm25 == null
                ? tones.netral
                : (pm25 <= 12
                      ? AppPalette.aman
                      : (pm25 <= 35 ? AppPalette.aksenDeep : tones.waspada)),
            status: pm25 == null
                ? kamus.t('umum.belum_ada')
                : (pm25 <= 12
                      ? kamus.t('beranda.mini_optimal')
                      : (pm25 <= 35
                            ? kamus.t('beranda.mini_normal')
                            : kamus.t('beranda.mini_tinggi'))),
            progress: pm25 == null ? 0.02 : (pm25 / 60).clamp(0.02, 1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: JbMiniStat(
            label: 'PM10',
            value: pm10 == null ? '--' : _angka(pm10),
            unit: 'µg/m³',
            color: pm10 == null
                ? tones.netral
                : (pm10 <= 54
                      ? AppPalette.aman
                      : (pm10 <= 154 ? AppPalette.aksenDeep : tones.waspada)),
            status: pm10 == null
                ? kamus.t('umum.belum_ada')
                : (pm10 <= 54
                      ? kamus.t('beranda.mini_optimal')
                      : (pm10 <= 154
                            ? kamus.t('beranda.mini_normal')
                            : kamus.t('beranda.mini_tinggi'))),
            progress: pm10 == null ? 0.02 : (pm10 / 200).clamp(0.02, 1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: JbMiniStat(
            label: kamus.t('beranda.mini_suhu'),
            value: suhu == null ? '--' : _angka(suhu),
            unit: '°C',
            color: suhu == null
                ? tones.netral
                : (suhu >= 20 && suhu <= 27
                      ? AppPalette.aman
                      : (suhu >= 16 && suhu <= 32
                            ? AppPalette.aksenDeep
                            : tones.waspada)),
            status: suhu == null
                ? kamus.t('umum.belum_ada')
                : (suhu >= 20 && suhu <= 27
                      ? kamus.t('beranda.mini_optimal')
                      : (suhu < 20
                            ? kamus.t('beranda.mini_rendah')
                            : (suhu <= 32
                                  ? kamus.t('beranda.mini_normal')
                                  : kamus.t('beranda.mini_tinggi')))),
            progress: suhu == null ? 0.02 : (suhu / 45).clamp(0.02, 1),
          ),
        ),
      ],
    );
  }

  static String _angka(double nilai) => nilai >= 100
      ? nilai.round().toString()
      : nilai.toStringAsFixed(nilai.truncateToDouble() == nilai ? 0 : 1);
}

// ────────────────────────────────────────────────── Kartu kebiasaan napas
class _KartuKebiasaan extends StatelessWidget {
  const _KartuKebiasaan({
    required this.cuaca,
    required this.status,
    required this.kamus,
    required this.tones,
    required this.onNapas,
    required this.onSinkron,
  });

  final WeatherForecast? cuaca;
  final _StatusAqi status;
  final L10n kamus;
  final AppTones tones;
  final VoidCallback onNapas;
  final VoidCallback? onSinkron;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 212,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: 252,
            child: JbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      JbStatusPill(
                        label: kamus.t('beranda.napas_durasi'),
                        color: tones.aksenDeep,
                        compact: true,
                      ),
                      const Spacer(),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: tones.aksenSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.self_improvement_rounded,
                          size: 21,
                          color: tones.aksenDeep,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    kamus.t('beranda.napas_judul'),
                    style: AppTeks.judulKartu(tones).copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    kamus.t('beranda.napas_sub'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTeks.isiSoft(tones).copyWith(fontSize: 12),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 42,
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onNapas,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(kamus.t('beranda.napas_cta')),
                      style: FilledButton.styleFrom(
                        backgroundColor: tones.aksenDeep,
                        textStyle: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 252,
            child: JbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      JbStatusPill(
                        label: kamus.t('beranda.sinkron'),
                        color: tones.aksenDeep,
                        compact: true,
                      ),
                      const Spacer(),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: tones.panel,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.wb_sunny_outlined,
                          size: 20,
                          color: tones.aksenDeep,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    kamus.t('beranda.udara_sekarang_judul'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTeks.judulKartu(tones).copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    cuaca == null
                        ? kamus.t('umum.belum_ada')
                        : '${kamus.t('beranda.udara_sekarang_sub', {'status': kamus.t(status.labelKey)})} · ${cuaca!.temperature.toStringAsFixed(0)}°C',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTeks.isiSoft(tones).copyWith(fontSize: 12),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 42,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onSinkron,
                      icon: const Icon(Icons.cloud_sync_outlined, size: 17),
                      label: Text(kamus.t('beranda.sinkron')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tones.aksenDeep,
                        side: BorderSide(color: tones.line),
                        textStyle: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Icon(statusIcon, size: 12, color: color),
          if (jumlah != null && jumlah! > 0) ...[
            const SizedBox(width: 3),
            Text(
              '$jumlah',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 10,
                color: color,
              ),
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
                                  fontFamily: 'Plus Jakarta Sans',
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
                                  fontFamily: 'Plus Jakarta Sans',
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

// ────────────────────────────────────────── Ringkasan kondisi (kartu tunggal)
/// Beranda hanya menampilkan level dan skor tiap kondisi. Alasan skor dan
/// saran tindakan ada di lembar detail yang dibuka dari kartu ini.
class _KondisiRingkas extends StatelessWidget {
  const _KondisiRingkas({
    required this.hasil,
    required this.outcome,
    required this.kamus,
    required this.tones,
    this.onTap,
  });

  final List<ConditionResult> hasil;
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
                ikon: Icons.monitor_heart_outlined,
                warna: tones.aksenDeep,
                ukuran: 40,
                ukuranIkon: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kamus.t('beranda.kondisi_saat_ini'),
                      style: AppTeks.judulKartu(tones).copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kamus.t('beranda.kondisi_ringkas_sub'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTeks.isiSoft(tones).copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: tones.inkSoft),
            ],
          ),
          const SizedBox(height: 14),
          if (outcome == null) ...[
            Row(
              children: [
                Icon(
                  Icons.hourglass_empty_rounded,
                  size: 18,
                  color: tones.inkSoft,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kamus.t('beranda.kosong_judul'),
                    style: AppTeks.isi(tones)
                        .copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              kamus.t('beranda.belum_diperiksa'),
              style: AppTeks.labelSeksi(tones),
            ),
          ] else ...[
            Row(
              children: [
                Icon(
                  Icons.flag_rounded,
                  size: 15,
                  color: tones.level(outcome!.levelTertinggi),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    kamus.t('beranda.level_tertinggi', {
                      'level': outcome!.levelTertinggi,
                    }),
                    style: AppTeks.labelSeksi(tones).copyWith(
                      color: tones.level(outcome!.levelTertinggi),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < hasil.length; i++) ...[
              if (i > 0) Divider(height: 18, color: tones.line),
              _BarisKondisi(hasil: hasil[i]),
            ],
          ],
        ],
      ),
    );
  }
}

class _BarisKondisi extends StatelessWidget {
  const _BarisKondisi({required this.hasil});

  final ConditionResult hasil;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final accent = tones.level(hasil.level);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            KondisiStyle.iconOf(hasil.kondisi),
            size: 18,
            color: accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasil.kondisi,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTeks.judulBaris(tones).copyWith(fontSize: 14.5),
              ),
              const SizedBox(height: 3),
              LevelChip(level: hasil.level),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ScoreGauge(skor: hasil.skor, level: hasil.level, size: 42),
      ],
    );
  }
}

// ─────────────────────────────────────────── Ringkasan pemantauan (kartu)
class _PemantauanKartu extends StatelessWidget {
  const _PemantauanKartu({
    required this.outcome,
    required this.kamus,
    required this.tones,
    this.onTap,
  });

  final CycleOutcome? outcome;
  final L10n kamus;
  final AppTones tones;
  final VoidCallback? onTap;

  static const List<String> _sinyal = [
    'heart_rate',
    'hrv',
    'spo2',
    'resp_rate',
    'sleep',
    'exercise',
    'steps',
  ];

  @override
  Widget build(BuildContext context) {
    final snapshot = outcome?.snapshot;
    final ok = snapshot == null
        ? 0
        : _sinyal.where((s) => snapshot.status(s) == 'ok').length;
    final keyakinan = snapshot?.confidence ?? '—';
    final ambang = outcome?.ambang.tierAmbangSuhu.name ?? 'literatur';
    return JbCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KotakIkon(
                ikon: Icons.sensors_rounded,
                warna: tones.aksenDeep,
                ukuran: 40,
                ukuranIkon: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kamus.t('beranda.pemantauan_judul'),
                      style: AppTeks.judulKartu(tones).copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kamus.t('beranda.pemantauan_sub'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTeks.isiSoft(tones).copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: tones.inkSoft),
            ],
          ),
          const SizedBox(height: 14),
          if (snapshot == null)
            Text(
              kamus.t('beranda.pemantauan_kosong'),
              style: AppTeks.isiSoft(tones).copyWith(fontSize: 13.5),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _PilRingkas(
                    ikon: Icons.check_circle_outline_rounded,
                    teks: kamus.t('beranda.sinyal_ringkas', {
                      'ok': '$ok',
                      'total': '${_sinyal.length}',
                    }),
                    warna: tones.aman,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PilRingkas(
                    ikon: Icons.verified_outlined,
                    teks: kamus.t('beranda.keyakinan_ringkas', {
                      'level': keyakinan,
                    }),
                    warna: keyakinan == 'HIGH' ? tones.aman : tones.waspada,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _PilRingkas(
              ikon: Icons.tune_rounded,
              teks: kamus.t('beranda.ambang_ringkas_2', {
                'tier': kamus.t('tier.$ambang'),
              }),
              warna: tones.tier(ambang),
            ),
          ],
        ],
      ),
    );
  }
}

class _PilRingkas extends StatelessWidget {
  const _PilRingkas({
    required this.ikon,
    required this.teks,
    required this.warna,
  });

  final IconData ikon;
  final String teks;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppLayout.radiusPil),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 14, color: warna),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              teks,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: warna,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────── Catatan sumber di lembar detail
class _SumberCatatan extends StatelessWidget {
  const _SumberCatatan({required this.sumber, required this.kamus});

  final String sumber;
  final L10n kamus;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return JbCard(
      color: tones.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_done_outlined, size: 18, color: tones.aksenDeep),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  kamus.t('beranda.sumber_otomatis', {
                    'sumber': kamus.sumberData(sumber),
                  }),
                  style: AppTeks.judulBaris(tones).copyWith(fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            kamus.t('beranda.tombol_jelas', {
              'menit': '${AppConfig.CYCLE_INTERVAL_MINUTES}',
            }),
            style: AppTeks.isiSoft(tones).copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Text(
            kamus.t('beranda.sumber_ajakan'),
            style: AppTeks.isiSoft(tones).copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/sources'),
            icon: const Icon(Icons.menu_book_rounded, size: 16),
            label: Text(kamus.t('profil.resource_judul')),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────── Lembar detail gaya Stitch
class _LembarDetail extends StatelessWidget {
  const _LembarDetail({
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
