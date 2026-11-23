import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/alert_record.dart';
import '../models/condition_result.dart';
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
  late Future<List<AlertRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.store.getRecentAlerts(limit: 200);
    widget.pengamat?.addListener(_uatUlang);
  }

  @override
  void dispose() {
    widget.pengamat?.removeListener(_uatUlang);
    super.dispose();
  }

  void _uatUlang() {
    setState(() {
      _future = widget.store.getRecentAlerts(limit: 200);
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
        child: FutureBuilder<List<AlertRecord>>(
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

            final rows = snapshot.data ?? const <AlertRecord>[];
            if (rows.isEmpty) {
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
            final hari = rows
                .map(
                  (r) => DateTime(
                    r.timestamp.year,
                    r.timestamp.month,
                    r.timestamp.day,
                  ),
                )
                .toSet()
                .length;
            final sekarang = DateTime.now();
            final awalMinggu = DateTime(
              sekarang.year,
              sekarang.month,
              sekarang.day,
            ).subtract(const Duration(days: 6));
            final perluPerhatian = rows
                .where(
                  (r) =>
                      !r.timestamp.isBefore(awalMinggu) &&
                      AlertLevels.levelButuhAlert(r.level),
                )
                .length;
            final rata = (rows.fold<int>(0, (a, r) => a + r.skor) / total)
                .round();
            final cekMinggu = rows.where((r) => !r.timestamp.isBefore(awalMinggu)).toList();
            final hariMinggu = cekMinggu
                .map((r) => DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day))
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
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: tones.aksenSoft.withValues(alpha: 0.24),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _RentangChart(label: 'D', aktif: false, tones: tones),
                                _RentangChart(label: 'W', aktif: true, tones: tones),
                                _RentangChart(label: 'Y', aktif: false, tones: tones),
                              ],
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
                  padding: const EdgeInsets.only(top: 24, bottom: 12),
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
                                style: AppTeks.judulKartu(tones).copyWith(fontSize: 17),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: tones.aksen,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final lebar = (constraints.maxWidth - 14) / 2;
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        SizedBox(
                          width: lebar,
                          child: _MetricCard(
                            label: kamus.t('statistik.rata'),
                            value: '$rataMinggu',
                            unit: '/100',
                            status: rataMinggu <= 25
                                ? kamus.t('statistik.status_aman')
                                : (rataMinggu <= 50
                                    ? kamus.t('statistik.status_waspada')
                                    : kamus.t('statistik.status_perhatian')),
                            color: tones.level(
                              rataMinggu <= 25
                                  ? AlertLevels.aman
                                  : (rataMinggu <= 50
                                      ? AlertLevels.waspada
                                      : AlertLevels.perhatian),
                            ),
                            visual: _MiniTrend(values: minggu.map((d) => d.skor.toDouble()).toList(), color: tones.aksenDeep),
                            footer: kamus.t('statistik.rata_minggu_footer'),
                          ),
                        ),
                        SizedBox(
                          width: lebar,
                          child: _MetricCard(
                            label: kamus.t('statistik.total_cek'),
                            value: '${cekMinggu.length}',
                            unit: kamus.t('statistik.cek_unit'),
                            status: kamus.t('statistik.minggu_ini'),
                            color: tones.aman,
                            visual: _ProgressTrack(progress: (cekMinggu.length / (cekMinggu.length < 7 ? 7 : cekMinggu.length)).clamp(0.0, 1.0), color: tones.aman),
                            footer: kamus.t('statistik.total_cek_footer', {'n': '$hariMinggu'}),
                          ),
                        ),
                        SizedBox(
                          width: lebar,
                          child: _MetricCard(
                            label: kamus.t('statistik.hari'),
                            value: '$hariMinggu',
                            unit: '/7',
                            status: kamus.t('statistik.hari_aktif'),
                            color: tones.aksen,
                            visual: _WeekDots(days: minggu, color: tones.aksen),
                            footer: kamus.t('statistik.hari_footer'),
                          ),
                        ),
                        SizedBox(
                          width: lebar,
                          child: _MetricCard(
                            label: kamus.t('statistik.alert_7'),
                            value: '$perluPerhatian',
                            unit: kamus.t('statistik.cek_unit'),
                            status: perluPerhatian == 0
                                ? kamus.t('statistik.status_aman')
                                : kamus.t('statistik.status_perhatian'),
                            color: perluPerhatian == 0 ? tones.aman : tones.waspada,
                            visual: _WeekDots(
                              days: minggu,
                              color: tones.waspada,
                              alertOnly: true,
                              rows: cekMinggu,
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
    required this.status,
    required this.color,
    required this.visual,
    required this.footer,
  });

  final String label;
  final String value;
  final String unit;
  final String status;
  final Color color;
  final Widget visual;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 206),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: tones.card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tones.line.withValues(alpha: 0.45)),
        boxShadow: tones.softShadow(),
      ),
      child: Column(
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
                    color: tones.inkSoft,
                    letterSpacing: 0.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Flexible(child: JbStatusPill(label: status, color: color, compact: true)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 31,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    color: tones.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: tones.inkSoft, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(height: 36, child: visual),
          const SizedBox(height: 9),
          Text(
            footer,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTeks.isiSoft(tones).copyWith(fontSize: 10.5),
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

class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: 7,
        backgroundColor: tones.line.withValues(alpha: 0.65),
        color: color,
      ),
    );
  }
}

class _WeekDots extends StatelessWidget {
  const _WeekDots({
    required this.days,
    required this.color,
    this.alertOnly = false,
    this.rows = const [],
  });
  final List<_HariStat> days;
  final Color color;
  final bool alertOnly;
  final List<AlertRecord> rows;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 6));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < days.length; i++)
          Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: alertOnly
                  ? (rows.any((r) {
                      final date = start.add(Duration(days: i));
                      return r.timestamp.year == date.year &&
                          r.timestamp.month == date.month &&
                          r.timestamp.day == date.day &&
                          AlertLevels.levelButuhAlert(r.level);
                    }) ? color : tones.line)
                  : (days[i].jumlah > 0
                      ? color.withValues(alpha: 0.8)
                      : tones.line),
            ),
          ),
      ],
    );
  }
}

class _RentangChart extends StatelessWidget {
  const _RentangChart({
    required this.label,
    required this.aktif,
    required this.tones,
  });

  final String label;
  final bool aktif;
  final AppTones tones;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 30, minHeight: 28),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: aktif ? tones.aksenSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        boxShadow: aktif ? tones.softShadow() : null,
      ),
      child: Text(
        label,
        style: AppTeks.labelSeksi(tones).copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: aktif ? tones.aksenDeep : tones.inkSoft,
        ),
      ),
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
