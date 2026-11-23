import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/alert_record.dart';
import '../models/condition_result.dart';
import '../models/nilai_fisiologis.dart';
import '../services/database_helpers.dart';
import 'level_style.dart';
import '../widgets/jb.dart';

/// Riwayat hasil cek, dikelompokkan per tanggal.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({required this.store, this.pengamat, super.key});

  final DatabaseHelper store;

  /// Berlangganan ke orkestrator agar tab riwayat tidak menampilkan data basi
  /// setelah siklus 15 menit berjalan di latar belakang.
  final Listenable? pengamat;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<AlertRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.store.getRecentAlerts(limit: 50);
    widget.pengamat?.addListener(_uatUlang);
  }

  @override
  void dispose() {
    widget.pengamat?.removeListener(_uatUlang);
    super.dispose();
  }

  void _uatUlang() {
    setState(() {
      _future = widget.store.getRecentAlerts(limit: 50);
    });
  }

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    final tones = AppTones.of(context);
    final bisaKembali = Navigator.canPop(context);

    // Kepala halaman ada di dalam body (bukan AppBar), persis template, dan
    // ikut tergulir bersama daftarnya.
    Widget kepala() => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          if (bisaKembali) ...[
            JbIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: kamus.t('umum.tutup'),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  kamus.t('riwayat.judul'),
                  style: AppTeks.judulHalaman(tones),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF9F43),
                    shape: BoxShape.circle,
                  ),
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
      body: RefreshIndicator(
        onRefresh: () async {
          _uatUlang();
          await _future;
        },
        child: SafeArea(
          bottom: false,
          child: FutureBuilder<List<AlertRecord>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Stack(
                  children: [
                    ListView(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
                      children: [kepala()],
                    ),
                    const Center(child: CircularProgressIndicator()),
                  ],
                );
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    24,
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
                    24,
                    20,
                    AppLayout.bawahKonten(context),
                  ),
                  children: [
                    kepala(),
                    EmptyState(
                      ikon: Icons.history_outlined,
                      judul: kamus.t('riwayat.kosong_judul'),
                      pesan: kamus.t('riwayat.kosong_pesan'),
                    ),
                  ],
                );
              }

              final groups = <String, List<AlertRecord>>{};
              for (final r in rows) {
                groups
                    .putIfAbsent(_tanggalRiwayat(r.timestamp, kamus), () => [])
                    .add(r);
              }

              final items = groups.entries.toList();
              return ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  AppLayout.bawahKonten(context),
                ),
                itemCount: items.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        kepala(),
                        // Baris utilitas gaya Alerts: jumlah pembaruan + tandai
                        // semua sudah dibaca.
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: tones.aksen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${rows.length} pembaruan baru',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTeks.judulBaris(tones).copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _uatUlang,
                                icon: const Icon(
                                  Icons.done_all_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Tandai dibaca',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: tones.aksenDeep,
                                  textStyle: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Filter pills gaya Alerts.
                        SizedBox(
                          height: 46,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _FilterPill(
                                label: 'Semua',
                                jumlah: rows.length,
                                aktif: true,
                              ),
                              _FilterPill(
                                label: 'Kesehatan',
                                jumlah: rows
                                    .where(
                                      (r) =>
                                          AlertLevels.levelButuhAlert(r.level),
                                    )
                                    .length,
                              ),
                              _FilterPill(label: 'Udara', jumlah: rows.length),
                              _FilterPill(label: 'Pengingat', jumlah: 0),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _RingkasanRiwayat(rows: rows),
                      ],
                    );
                  }
                  final entri = items[i - 1];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 14, bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: tones.aksen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              entri.key.toUpperCase(),
                              style: AppTeks.labelSeksi(tones),
                            ),
                            const Spacer(),
                            InfoChip(
                              teks: kamus.t('umum.cek', {
                                'jumlah': '${entri.value.length}',
                              }),
                            ),
                          ],
                        ),
                      ),
                      for (var i = 0; i < entri.value.length; i++) ...[
                        _RiwayatBaris(
                          record: entri.value[i],
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (_) =>
                                _DetailDialog(record: entri.value[i]),
                          ),
                        ),
                        if (i < entri.value.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// Judul kelompok: "Hari ini" / "Kemarin" / tanggal penuh.
  static String _tanggalRiwayat(DateTime waktu, L10n kamus) {
    final sekarang = DateTime.now();
    final hari = DateTime(waktu.year, waktu.month, waktu.day);
    final hariIni = DateTime(sekarang.year, sekarang.month, sekarang.day);
    final selisih = hari.difference(hariIni).inDays;
    if (selisih == 0) return kamus.t('riwayat.hari_ini');
    if (selisih == -1) return kamus.t('riwayat.kemarin');
    return '${waktu.day}/${waktu.month}/${waktu.year}';
  }
}

/// Level paling tinggi dari sekumpulan record riwayat; sama logikanya dengan
/// headline di beranda tapi dibaca dari tabel, bukan dari hasil siklus.
String _levelTertinggi(List<AlertRecord> rows) {
  var indeks = -1;
  for (final r in rows) {
    final i = AlertLevels.urutan.indexOf(r.level);
    if (i > indeks) indeks = i;
  }
  return indeks < 0 ? AlertLevels.tidakDievaluasi : AlertLevels.urutan[indeks];
}

/// Tiga angka di atas daftar: seberapa sering dicek, level terburuk, dan
/// berapa hasil yang di atas ambang aman.
class _RingkasanRiwayat extends StatelessWidget {
  const _RingkasanRiwayat({required this.rows});

  final List<AlertRecord> rows;

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    final tones = AppTones.of(context);
    final tertinggi = _levelTertinggi(rows);
    final perlu = rows
        .where((r) => AlertLevels.levelButuhAlert(r.level))
        .length;
    return SectionCard(
      judul: kamus.t('riwayat.ringkasan'),
      ikon: Icons.insights_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: MiniStat(
                nilai: '${rows.length}',
                label: kamus.t('riwayat.pemeriksaan'),
              ),
            ),
            Expanded(
              child: MiniStat(
                nilai: '$perlu',
                label: kamus.t('riwayat.di_atas_aman'),
                warna: perlu == 0 ? tones.aman : tones.level(tertinggi),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LevelChip(level: tertinggi),
                  const SizedBox(height: 6),
                  Text(
                    kamus.t('riwayat.level_terburuk'),
                    style: AppTeks.labelSeksi(tones),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RiwayatBaris extends StatelessWidget {
  const _RiwayatBaris({required this.record, required this.onTap});

  final AlertRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final kamus = L10n.of(context);
    final accent = tones.level(record.level);
    final butuhAlert = AlertLevels.levelButuhAlert(record.level);
    return JbCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppLayout.radiusKartu),
        child: Stack(
          clipBehavior: Clip.antiAlias,
          children: [
            Positioned(
              left: 0,
              top: 2,
              bottom: 2,
              child: Container(
                width: 5,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      KondisiStyle.iconOf(record.kondisi),
                      size: 22,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    AppLayout.radiusPil,
                                  ),
                                ),
                                child: Text(
                                  '${record.level} • ${record.kondisi}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          record.kondisi,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTeks.judulBaris(tones)
                              .copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          record.intervensi.isNotEmpty
                              ? record.intervensi
                              : kamus.t('beranda.alert_banner'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTeks.isiSoft(tones)
                              .copyWith(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _jam(record.timestamp),
                        style: AppTeks.labelSeksi(tones).copyWith(fontSize: 11),
                      ),
                      if (butuhAlert) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: tones.inkSoft,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _jam(DateTime waktu) =>
      '${waktu.hour.toString().padLeft(2, '0')}:'
      '${waktu.minute.toString().padLeft(2, '0')}';
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.jumlah,
    this.aktif = false,
  });

  final String label;
  final int jumlah;
  final bool aktif;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          gradient: aktif
              ? LinearGradient(colors: [tones.aksen, tones.aksenDeep])
              : null,
          color: aktif ? null : tones.card,
          borderRadius: BorderRadius.circular(AppLayout.radiusPil),
          boxShadow: aktif ? tones.softShadow() : null,
          border: aktif ? null : Border.all(color: tones.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: aktif ? Colors.white : tones.inkSoft,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              decoration: BoxDecoration(
                color: aktif
                    ? Colors.white.withValues(alpha: 0.25)
                    : tones.panel,
                borderRadius: BorderRadius.circular(AppLayout.radiusPil),
              ),
              child: Text(
                '$jumlah',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: aktif ? Colors.white : tones.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailDialog extends StatelessWidget {
  const _DetailDialog({required this.record});

  final AlertRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kamus = L10n.of(context);
    final tones = AppTones.of(context);
    final accent = tones.level(record.level);
    final alasan = record.tampil(kamus);
    return AlertDialog(
      icon: Icon(KondisiStyle.iconOf(record.kondisi), color: accent, size: 26),
      title: Text('${record.kondisi} • ${record.level}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ScoreGauge(skor: record.skor, level: record.level, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LevelChip(level: record.level),
                      const SizedBox(height: 6),
                      Text(
                        kamus.t('riwayat.skor_keyakinan', {
                          'skor': '${record.skor}',
                          'confidence': record.confidence,
                        }),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _waktuLengkap(record.timestamp),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Text(
              alasan.isEmpty
                  ? kamus.t('umum.semua_normal_kapital')
                  : kamus.t('umum.skor_naik'),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: accent,
              ),
            ),
            const SizedBox(height: 7),
            if (alasan.isEmpty)
              Text(
                kamus.t('riwayat.tidak_ada_pemicu'),
                style: theme.textTheme.bodySmall,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final a in alasan)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(a, style: theme.textTheme.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            if (record.intervensi.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tones.levelSurface(record.level),
                  borderRadius: BorderRadius.circular(AppLayout.radiusGrup),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_rounded, size: 18, color: accent),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        record.intervensi,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (record.inputJson != null) ...[
              const SizedBox(height: 14),
              Text(
                kamus.t('riwayat.input_saat_itu'),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: tones.canvas,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _ringkasInput(record.inputJson!, kamus),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: Text(kamus.t('umum.tutup')),
        ),
      ],
    );
  }

  static String _waktuLengkap(DateTime waktu) =>
      '${waktu.day}/${waktu.month}/${waktu.year} '
      '${waktu.hour.toString().padLeft(2, '0')}:${waktu.minute.toString().padLeft(2, '0')}';

  static String _ringkasInput(Map<String, dynamic> input, L10n kamus) {
    final bagian = <String>[];
    void isi(String label, String kunci, {String satuan = ''}) {
      final nilai = input[kunci];
      if (nilai is! num) return;
      final presisi = nilai % 1 == 0 ? 0 : 1;
      bagian.add('$label ${nilai.toStringAsFixed(presisi)}$satuan');
    }

    isi('RHR', 'resting_hr', satuan: ' bpm');
    isi('HRV', 'hrv_rmssd', satuan: ' ms');
    final spo2 = normalisasiPersen(input['spo2'] as num?);
    if (spo2 != null) bagian.add('SpO2 ${formatPersen(spo2)}%');
    isi(kamus.t('label.napas'), 'resp_rate', satuan: '/mnt');
    isi(kamus.t('sensor.tidur'), 'tidur_menit', satuan: ' mnt');
    isi(kamus.t('label.suhu'), 'suhu_ambient', satuan: '°C');
    isi(kamus.t('label.angin'), 'angin_ms', satuan: ' m/s');
    isi('PM2.5', 'pm25', satuan: ' µg/m³');
    final kalibrasi = input['kalibrasi'];
    if (kalibrasi is String) {
      bagian.add(
        kamus.t('umum.ambang_kalibrasi', {
          'kalibrasi': kamus.t('kalibrasi.$kalibrasi'),
        }),
      );
    }
    return bagian.isEmpty
        ? kamus.t('riwayat.tidak_ada_input')
        : bagian.join(' • ');
  }
}
