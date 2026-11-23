import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/alert_record.dart';
import '../models/condition_result.dart';
import '../models/health_sample.dart';
import '../services/database_helpers.dart';
import '../widgets/jb.dart';
import 'level_style.dart';

/// Ringkasan statistik dari riwayat pemeriksaan.
///
/// Layar ini menggantikan tab Sumber di navigasi bawah: sumber sudah punya
/// halaman sendiri lewat kartu di Profil, sedangkan statistik dipakai setiap
/// hari untuk melihat tren dan kondisi yang paling sering muncul.
class StatsScreen extends StatefulWidget {
  const StatsScreen({required this.store, this.pengamat, super.key});

  final DatabaseHelper store;

  /// Berlangganan ke orkestrator supaya angka ikut berubah setelah siklus
  /// latar belakang selesai.
  final Listenable? pengamat;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<_StatsData> _future;

  Future<_StatsData> _loadStats() async {
    final alertsFuture = widget.store.getRecentAlerts(limit: 3000);
    final samplesFuture = widget.store.getSamples(days: 8);
    final alerts = await alertsFuture;
    final samples = await samplesFuture;
    return _StatsData(alerts: alerts, samples: samples);
  }

  @override
  void initState() {
    super.initState();
    _future = _loadStats();
    widget.pengamat?.addListener(_uatUlang);
  }

  @override
  void dispose() {
    widget.pengamat?.removeListener(_uatUlang);
    super.dispose();
  }

  void _uatUlang() {
    setState(() {
      _future = _loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    final tones = AppTones.of(context);
    final bisaKembali = Navigator.canPop(context);

    Widget kepala() => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kamus.t('statistik.judul'),
                  style: AppTeks.judulHalaman(tones),
                ),
                const SizedBox(height: 2),
                Text(
                  kamus.t('statistik.sub'),
                  style: AppTeks.isiSoft(tones).copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          JbIconButton(
            icon: Icons.refresh_rounded,
            tooltip: kamus.t('statistik.muat_ulang'),
            onTap: _uatUlang,
          ),
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<_StatsData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  AppLayout.bawahKonten(context),
                ),
                children: [
                  kepala(),
                  const SizedBox(height: 40),
                  const Center(child: CircularProgressIndicator()),
                ],
              );
            }
            if (snapshot.hasError) {
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  AppLayout.bawahKonten(context),
                ),
                children: [
                  kepala(),
                  EmptyState(
                    ikon: Icons.error_outline_rounded,
                    judul: kamus.t('riwayat.gagal'),
                    pesan: '${snapshot.error}',
                  ),
                ],
              );
            }

            final data = snapshot.data ?? _StatsData.empty;
            final sekarang = DateTime.now();
            final awalMinggu = DateTime(
              sekarang.year,
              sekarang.month,
              sekarang.day,
            ).subtract(const Duration(days: 6));
            final rows = data.alerts
                .where((r) => !r.timestamp.isBefore(awalMinggu))
                .toList();
            final siklusMinggu = data.samples
                .where((sample) => !sample.at.isBefore(awalMinggu))
                .toList();
            if (rows.isEmpty && siklusMinggu.isEmpty) {
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  AppLayout.bawahKonten(context),
                ),
                children: [
                  kepala(),
                  EmptyState(
                    ikon: Icons.insights_rounded,
                    judul: kamus.t('statistik.kosong_judul'),
                    pesan: kamus.t('statistik.kosong_pesan'),
                  ),
                ],
              );
            }

            final total = rows.length;
            final perluPerhatian = siklusMinggu
                .where((sample) => AlertLevels.levelButuhAlert(
                      sample.levelTertinggi ?? AlertLevels.aman,
                    ))
                .length;
            final cekMinggu = rows;
            final hariMinggu = siklusMinggu
                .map((sample) => DateTime(sample.at.year, sample.at.month, sample.at.day))
                .toSet()
                .length;
            final rataMinggu = cekMinggu.isEmpty
                ? 0
                : (cekMinggu.fold<int>(0, (a, r) => a + r.skor) / cekMinggu.length).round();
            final minggu = _mingguIni(rows, kamus);
            final adaMinggu = minggu.where((d) => d.jumlah > 0).toList();
            final terbaik = adaMinggu.isEmpty
                ? null
                : adaMinggu.reduce((a, b) => a.skor <= b.skor ? a : b);
            final terburuk = adaMinggu.isEmpty
                ? null
                : adaMinggu.reduce((a, b) => a.skor >= b.skor ? a : b);

            return ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                AppLayout.bawahKonten(context),
              ),
              children: [
                kepala(),
                const SizedBox(height: 4),
                JbCard(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.air_rounded, size: 20, color: tones.aksenDeep),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              kamus.t('statistik.tren'),
                              style: AppTeks.judulBaris(tones).copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                            decoration: BoxDecoration(
                              color: tones.aksenSoft.withValues(alpha: 0.28),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              kamus.t('statistik.tujuh_hari'),
                              style: AppTeks.labelSeksi(tones).copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: tones.aksenDeep,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 180,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final d in minggu)
                              Expanded(
                                child: _BatangHari(
                                  hari: d,
                                  tones: tones,
                                  terbaik: terbaik?.label == d.label,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (terbaik != null && terburuk != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: tones.aksenSoft.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _CatatanHari(
                                  label: kamus.t('statistik.terbaik'),
                                  hari: terbaik,
                                  warna: tones.aman,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: tones.line,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _CatatanHari(
                                  label: kamus.t('statistik.terburuk'),
                                  hari: terburuk,
                                  warna: tones.waspada,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                kamus.t('statistik.ringkasan_minggu'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTeks.judulKartu(tones).copyWith(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.35,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1EB6F0),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: tones.card.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: tones.line.withValues(alpha: 0.55)),
                        ),
                        child: Text(
                          kamus.t('statistik.tujuh_hari').toUpperCase(),
                          style: AppTeks.labelSeksi(tones).copyWith(
                            fontSize: 9.5,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w800,
                            color: tones.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final lebar = (constraints.maxWidth - 14) / 2;
                    final rataWarna = cekMinggu.isEmpty
                        ? tones.inkSoft
                        : tones.level(
                            rataMinggu <= 25
                                ? AlertLevels.aman
                                : (rataMinggu <= 50
                                    ? AlertLevels.waspada
                                    : AlertLevels.perhatian),
                          );
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        SizedBox(
                          width: lebar,
                          child: _MetricCard(
                            label: kamus.t('statistik.rata'),
                            value: cekMinggu.isEmpty ? '—' : '$rataMinggu',
                            unit: cekMinggu.isEmpty ? '' : '/100',
                            badge: cekMinggu.isEmpty
                                ? kamus.t('statistik.tidak_ada')
                                : (rataMinggu <= 25
                                    ? kamus.t('statistik.status_aman')
                                    : (rataMinggu <= 50
                                        ? kamus.t('statistik.status_waspada')
                                        : kamus.t('statistik.status_perhatian'))),
                            color: rataWarna,
                            visual: _MiniTrend(
                              values: minggu
                                  .where((d) => d.jumlah > 0)
                                  .map((d) => d.skor.toDouble())
                                  .toList(),
                              color: tones.aksenDeep,
                            ),
                            footer: kamus.t('statistik.rata_minggu_footer'),
                          ),
                        ),
                        SizedBox(
                          width: lebar,
                          child: _MetricCard(
                            label: kamus.t('statistik.total_cek'),
                            value: '${siklusMinggu.length}',
                            unit: kamus.t('statistik.siklus_unit'),
                            badge: kamus.t('statistik.minggu_ini'),
                            color: tones.aman,
                            visual: _WeekBars(days: minggu, color: tones.aman),
                            footer: kamus.t('statistik.total_cek_footer', {'n': '$hariMinggu'}),
                          ),
                        ),
                        SizedBox(
                          width: lebar,
                          child: _MetricCard(
                            label: kamus.t('statistik.hari'),
                            value: '$hariMinggu',
                            unit: '/7',
                            badge: kamus.t('statistik.hari_aktif'),
                            color: tones.aksenDeep,
                            visual: _RadialMetric(
                              progress: hariMinggu / 7,
                              color: tones.aksen,
                              icon: Icons.eco_outlined,
                            ),
                            footer: kamus.t('statistik.hari_footer'),
                          ),
                        ),
                        SizedBox(
                          width: lebar,
                          child: _MetricCard(
                            label: kamus.t('statistik.alert_7'),
                            value: '$perluPerhatian',
                            unit: kamus.t('statistik.siklus_unit'),
                            badge: perluPerhatian == 0
                                ? kamus.t('statistik.status_aman')
                                : kamus.t('statistik.status_perhatian'),
                            color: perluPerhatian == 0 ? tones.aman : tones.waspada,
                            visual: _AlertWeekStrip(
                              samples: siklusMinggu,
                              color: tones.waspada,
                            ),
                            footer: kamus.t('statistik.alert_footer'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                JbSectionTitle(
                  title: kamus.t('statistik.distribusi'),
                  padding: const EdgeInsets.only(top: 22, bottom: 12),
                ),
                JbCard(
                  child: Column(
                    children: [
                      for (final level in AlertLevels.urutan)
                        _BarisDistribusi(
                          level: level,
                          jumlah: rows.where((r) => r.level == level).length,
                          total: total,
                          tones: tones,
                        ),
                    ],
                  ),
                ),
                JbSectionTitle(
                  title: kamus.t('statistik.per_kondisi'),
                  padding: const EdgeInsets.only(top: 22, bottom: 12),
                ),
                JbCard(
                  child: Column(
                    children: [
                      for (final kondisi in _kondisiUnik(rows)) ...[
                        _BarisKondisiStat(
                          kondisi: kondisi,
                          rows: rows
                              .where((r) => r.kondisi == kondisi)
                              .toList(),
                          tones: tones,
                        ),
                        if (kondisi != _kondisiUnik(rows).last)
                          Divider(height: 22, color: tones.line),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                JbCard(
                  color: tones.aksenSoft.withValues(alpha: 0.35),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 20,
                        color: tones.aksenDeep,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kamus.t('statistik.insight'),
                              style: AppTeks.judulBaris(tones)
                                  .copyWith(fontSize: 14.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              perluPerhatian == 0
                                  ? kamus.t('statistik.insight_aman')
                                  : kamus.t('statistik.insight_alert', {
                                      'n': '$perluPerhatian',
                                    }),
                              style: AppTeks.isiSoft(tones)
                                  .copyWith(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static List<String> _kondisiUnik(List<AlertRecord> rows) {
    final unik = <String>[];
    for (final r in rows) {
      if (!unik.contains(r.kondisi)) unik.add(r.kondisi);
    }
    return unik;
  }

  /// Tujuh hari terakhir (termasuk hari ini) dengan skor tertinggi per hari.
  static List<_HariStat> _mingguIni(List<AlertRecord> rows, L10n kamus) {
    final sekarang = DateTime.now();
    final awal = DateTime(
      sekarang.year,
      sekarang.month,
      sekarang.day,
    ).subtract(const Duration(days: 6));
    final namaHari = kamus.kode == 'en'
        ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return List<_HariStat>.generate(7, (i) {
      final tanggal = awal.add(Duration(days: i));
      final hariIni = rows.where((r) {
        final t = r.timestamp;
        return t.year == tanggal.year &&
            t.month == tanggal.month &&
            t.day == tanggal.day;
      }).toList();
      if (hariIni.isEmpty) {
        return _HariStat(
          label: namaHari[tanggal.weekday - 1],
          jumlah: 0,
          skor: 0,
          level: AlertLevels.aman,
        );
      }
      final tertinggi = hariIni.reduce((a, b) => a.skor >= b.skor ? a : b);
      return _HariStat(
        label: namaHari[tanggal.weekday - 1],
        jumlah: hariIni.length,
        skor: tertinggi.skor,
        level: tertinggi.level,
      );
    });
  }
}

class _StatsData {
  const _StatsData({required this.alerts, required this.samples});

  static const empty = _StatsData(
    alerts: <AlertRecord>[],
    samples: <HealthSample>[],
  );

  final List<AlertRecord> alerts;
  final List<HealthSample> samples;
}

class _HariStat {
  const _HariStat({
    required this.label,
    required this.jumlah,
    required this.skor,
    required this.level,
  });

  final String label;
  final int jumlah;
  final int skor;
  final String level;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.badge,
    required this.color,
    required this.visual,
    required this.footer,
  });

  final String label;
  final String value;
  final String unit;
  final String badge;
  final Color color;
  final Widget visual;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 226),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: tones.card.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tones.line.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0877AE).withValues(alpha: 0.075),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTeks.labelSeksi(tones).copyWith(
                        fontSize: 11.5,
                        letterSpacing: 0.65,
                        color: tones.inkSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        badge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 36,
                          height: 1.08,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                          color: tones.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        unit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 11,
                          color: tones.inkSoft,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 38, child: visual),
              const SizedBox(height: 8),
              Text(
                footer,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTeks.isiSoft(tones).copyWith(
                  fontSize: 10.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniTrend extends StatelessWidget {
  const _MiniTrend({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _TrendPainter(values: values, color: color),
    child: const SizedBox.expand(),
  );
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.fold<double>(1, (a, b) => b > a ? b : a);
    final minValue = values.fold<double>(0, (a, b) => b < a ? b : a);
    final range = (maxValue - minValue).abs();
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width / 2 : i / (values.length - 1) * size.width;
      final normalized = range == 0 ? 0.5 : (values[i] - minValue) / range;
      points.add(Offset(x, size.height - 4 - normalized * (size.height - 10)));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final current = points[i];
      final mid = (prev.dx + current.dx) / 2;
      path.cubicTo(mid, prev.dy, mid, current.dy, current.dx, current.dy);
    }
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    canvas.drawCircle(points.last, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days, required this.color});
  final List<_HariStat> days;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final maxCount = days.fold<int>(1, (m, d) => d.jumlah > m ? d.jumlah : m);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final day in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: day.jumlah == 0 ? 5 : 8 + (day.jumlah / maxCount) * 23,
                  decoration: BoxDecoration(
                    color: day.jumlah == 0
                        ? tones.line.withValues(alpha: 0.75)
                        : color.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RadialMetric extends StatelessWidget {
  const _RadialMetric({
    required this.progress,
    required this.color,
    required this.icon,
  });
  final double progress;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Row(
      children: [
        SizedBox(
          width: 42,
          height: 42,
          child: CustomPaint(
            painter: _RingPainter(progress: progress, color: color, track: tones.line),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
        const Spacer(),
        Text(
          '${(progress * 100).round()}%',
          style: AppTeks.labelSeksi(tones).copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: tones.inkSoft,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });
  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(3), 0, 2 * 3.141592653589793, false, p..color = track.withValues(alpha: 0.65));
    canvas.drawArc(
      rect.deflate(3),
      -3.141592653589793 / 2,
      2 * 3.141592653589793 * progress.clamp(0.0, 1.0),
      false,
      p..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.track != track;
}

class _AlertWeekStrip extends StatelessWidget {
  const _AlertWeekStrip({
    required this.samples,
    required this.color,
  });
  final List<HealthSample> samples;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final english = L10n.of(context).kode == 'en';
    final labels = english
        ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
        : const ['S', 'S', 'R', 'K', 'J', 'S', 'M'];
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                labels[first.add(Duration(days: i)).weekday - 1],
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: tones.inkSoft,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: samples.any((sample) {
                    final date = first.add(Duration(days: i));
                    return sample.at.year == date.year &&
                        sample.at.month == date.month &&
                        sample.at.day == date.day &&
                        AlertLevels.levelButuhAlert(
                          sample.levelTertinggi ?? AlertLevels.aman,
                        );
                  })
                      ? color
                      : tones.aksenSoft.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _BatangHari extends StatelessWidget {
  const _BatangHari({
    required this.hari,
    required this.tones,
    this.terbaik = false,
  });

  final _HariStat hari;
  final AppTones tones;
  final bool terbaik;

  IconData get _mood => switch (hari.level) {
        'AMAN' => Icons.sentiment_very_satisfied_rounded,
        'WASPADA' => Icons.sentiment_satisfied_rounded,
        'PERHATIAN' => Icons.sentiment_dissatisfied_rounded,
        'BAHAYA' => Icons.masks_rounded,
        _ => Icons.sentiment_neutral_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final warna = tones.level(hari.level);
    final tinggiIsi = hari.jumlah == 0
        ? 4.0
        : (hari.skor / 100 * 124).clamp(9.0, 124.0);

    return Semantics(
      label: '${hari.label}, skor ${hari.skor}, ${hari.jumlah} pemeriksaan',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 140,
            child: Center(
              child: Container(
                width: 34,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: tones.aksenSoft.withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 550),
                        curve: Curves.easeOutCubic,
                        height: tinggiIsi,
                        decoration: BoxDecoration(
                          color: hari.jumlah == 0 ? tones.line : warna,
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: hari.jumlah == 0
                              ? null
                              : [
                                  BoxShadow(
                                    color: warna.withValues(alpha: 0.26),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                      ),
                    ),
                    if (hari.jumlah > 0)
                      Positioned(
                        top: 4,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: tones.card,
                            shape: BoxShape.circle,
                            boxShadow: tones.softShadow(),
                          ),
                          child: Icon(_mood, size: 14, color: warna),
                        ),
                      ),
                    if (terbaik && hari.jumlah > 0)
                      Positioned(
                        top: 0,
                        right: -1,
                        child: Icon(
                          Icons.auto_awesome,
                          size: 10,
                          color: tones.aman,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            hari.label,
            maxLines: 1,
            style: AppTeks.labelSeksi(tones).copyWith(
              fontSize: 11,
              color: terbaik ? tones.aksenDeep : tones.inkSoft,
              fontWeight: terbaik ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hari.jumlah == 0 ? '·' : '${hari.skor}',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: hari.jumlah == 0 ? tones.inkSoft : warna,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatatanHari extends StatelessWidget {
  const _CatatanHari({
    required this.label,
    required this.hari,
    required this.warna,
  });

  final String label;
  final _HariStat hari;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTeks.labelSeksi(tones).copyWith(fontSize: 10.5)),
        const SizedBox(height: 3),
        Text(
          '${hari.label} · ${hari.skor}',
          style: AppTeks.judulBaris(tones).copyWith(fontSize: 13, color: warna),
        ),
      ],
    );
  }
}

class _BarisDistribusi extends StatelessWidget {
  const _BarisDistribusi({
    required this.level,
    required this.jumlah,
    required this.total,
    required this.tones,
  });

  final String level;
  final int jumlah;
  final int total;
  final AppTones tones;

  @override
  Widget build(BuildContext context) {
    final warna = tones.level(level);
    final porsi = total == 0 ? 0.0 : jumlah / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              level,
              style: AppTeks.labelSeksi(tones)
                  .copyWith(fontSize: 10.5, color: warna),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Stack(
                children: [
                  Container(height: 8, color: tones.line),
                  FractionallySizedBox(
                    widthFactor: porsi.clamp(0.0, 1.0),
                    child: Container(height: 8, color: warna),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 28,
            child: Text(
              '$jumlah',
              textAlign: TextAlign.right,
              style: AppTeks.judulBaris(tones).copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarisKondisiStat extends StatelessWidget {
  const _BarisKondisiStat({
    required this.kondisi,
    required this.rows,
    required this.tones,
  });

  final String kondisi;
  final List<AlertRecord> rows;
  final AppTones tones;

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    final rata = (rows.fold<int>(0, (a, r) => a + r.skor) / rows.length)
        .round();
    final level = rows
        .map((r) => r.level)
        .reduce((a, b) => _bobot(b) > _bobot(a) ? b : a);
    final warna = tones.level(level);
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: warna.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(KondisiStyle.iconOf(kondisi), size: 19, color: warna),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kondisi,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTeks.judulBaris(tones).copyWith(fontSize: 14.5),
              ),
              const SizedBox(height: 3),
              Text(
                kamus.t('statistik.cek_n', {'n': '${rows.length}'}),
                style: AppTeks.isiSoft(tones).copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          kamus.t('statistik.skor', {'n': '$rata'}),
          style: AppTeks.judulBaris(tones)
              .copyWith(fontSize: 12.5, color: warna),
        ),
      ],
    );
  }

  static int _bobot(String level) {
    final i = AlertLevels.urutan.indexOf(level);
    return i < 0 ? -1 : i;
  }
}
