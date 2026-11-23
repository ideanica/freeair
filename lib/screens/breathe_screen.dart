import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'level_style.dart';
import '../widgets/jb.dart';

/// Satu pola napas: durasi tiap fase dalam detik.
class PolaNapas {
  const PolaNapas({
    required this.kunci,
    required this.judul,
    required this.deskripsi,
    required this.masuk,
    required this.tahan,
    required this.keluar,
    required this.jeda,
  });

  final String kunci;
  final String judul;
  final String deskripsi;
  final int masuk;
  final int tahan;
  final int keluar;
  final int jeda;

  int get total => masuk + tahan + keluar + jeda;
}

const List<PolaNapas> polaNapas = [
  PolaNapas(
    kunci: 'napas.mode_478',
    judul: '4–7–8',
    deskripsi: 'napas.mode_478_desc',
    masuk: 4,
    tahan: 7,
    keluar: 8,
    jeda: 0,
  ),
  PolaNapas(
    kunci: 'napas.mode_box',
    judul: 'Box',
    deskripsi: 'napas.mode_box_desc',
    masuk: 4,
    tahan: 4,
    keluar: 4,
    jeda: 4,
  ),
  PolaNapas(
    kunci: 'napas.mode_pursed',
    judul: 'Pursed',
    deskripsi: 'napas.mode_pursed_desc',
    masuk: 4,
    tahan: 0,
    keluar: 6,
    jeda: 0,
  ),
];

/// Latihan napas terpandu: orb membesar saat menarik napas, mengecil saat
/// membuang. Tidak memakai sensor apa pun — murni timer + animasi.
class BreatheScreen extends StatefulWidget {
  const BreatheScreen({this.tertanam = false, super.key});

  /// Saat dipasang sebagai tab, tombol tutup tidak ditampilkan.
  final bool tertanam;

  @override
  State<BreatheScreen> createState() => _BreatheScreenState();
}

class _BreatheScreenState extends State<BreatheScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kontrol;
  int _pola = 0;
  int _fase = 0;
  int _siklus = 0;
  bool _jalan = false;

  static const _urutanFase = ['masuk', 'tahan', 'keluar', 'jeda'];

  PolaNapas get _aktif => polaNapas[_pola];

  int get _durasiFase => switch (_urutanFase[_fase]) {
    'masuk' => _aktif.masuk,
    'tahan' => _aktif.tahan,
    'keluar' => _aktif.keluar,
    _ => _aktif.jeda,
  };

  @override
  void initState() {
    super.initState();
    _kontrol = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addStatusListener(_faseSelesai);
    _siapkanFase();
  }

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  /// Fase dengan durasi 0 dilewati supaya pola 4–7–8 tidak berhenti di "jeda".
  void _siapkanFase() {
    var percobaan = 0;
    while (_durasiFase == 0 && percobaan < 4) {
      _fase = (_fase + 1) % _urutanFase.length;
      percobaan++;
    }
    _kontrol.duration = Duration(seconds: _durasiFase == 0 ? 1 : _durasiFase);
    if (_jalan) {
      _kontrol.forward(from: 0);
    } else {
      _kontrol.value = 0;
    }
  }

  void _faseSelesai(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_jalan) return;
    final berikut = (_fase + 1) % _urutanFase.length;
    setState(() {
      _fase = berikut;
      if (berikut == 0) _siklus++;
      _siapkanFase();
    });
  }

  void _toggle() {
    setState(() {
      _jalan = !_jalan;
      if (_jalan) {
        _kontrol.forward(from: _kontrol.value);
      } else {
        _kontrol.stop();
      }
    });
  }

  void _ulang() {
    setState(() {
      _fase = 0;
      _siklus = 0;
      _jalan = false;
      _siapkanFase();
    });
  }

  void _pilihPola(int i) {
    setState(() {
      _pola = i;
      _fase = 0;
      _siklus = 0;
      _jalan = false;
      _siapkanFase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    final tones = AppTones.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            AppLayout.bawahKonten(context),
          ),
          children: [
             const SizedBox(height: 16),
            _kepala(kamus, tones),
            const SizedBox(height: 18),
            _orb(kamus, tones),
            const SizedBox(height: 18),
            Center(
              child: Text(
                kamus.t('napas.judul'),
                style: AppTeks.judulHalaman(tones).copyWith(fontSize: 24),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '${_aktif.total} detik · ${kamus.t('napas.sub')}',
                textAlign: TextAlign.center,
                style: AppTeks.isiSoft(tones).copyWith(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            Center(child: _tombolMulai(kamus, tones)),
            const SizedBox(height: 26),
            JbSectionTitle(
              title: kamus.t('napas.pilih_mode'),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < polaNapas.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _KartuMode(
                      pola: polaNapas[i],
                      kamus: kamus,
                      aktif: i == _pola,
                      onTap: () => _pilihPola(i),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tones.aksenSoft.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(AppLayout.radiusKartu),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: tones.aksenDeep,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      kamus.t('napas.info'),
                      style: AppTeks.isiSoft(tones).copyWith(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kepala(L10n kamus, AppTones tones) {
    return Row(
      children: [
        if (!widget.tertanam)
          JbIconButton(
            icon: Icons.close_rounded,
            tooltip: kamus.t('umum.tutup'),
            onTap: () => Navigator.maybePop(context),
          )
        else
          const SizedBox(width: 44),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: tones.card,
            borderRadius: BorderRadius.circular(AppLayout.radiusPil),
            boxShadow: tones.softShadow(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.air_rounded, size: 16, color: tones.aksenDeep),
              const SizedBox(width: 7),
              Text(
                kamus.t('napas.siklus', {'n': '$_siklus'}),
                style: AppTeks.labelSeksi(tones)
                    .copyWith(color: tones.ink, fontSize: 12),
              ),
            ],
          ),
        ),
        const Spacer(),
        JbIconButton(
          icon: Icons.restart_alt_rounded,
          tooltip: kamus.t('napas.ulang'),
          onTap: _ulang,
        ),
      ],
    );
  }

  Widget _orb(L10n kamus, AppTones tones) {
    final fase = _urutanFase[_fase];
    final label = switch (fase) {
      'masuk' => kamus.t('napas.fase_masuk'),
      'tahan' => kamus.t('napas.fase_tahan'),
      'keluar' => kamus.t('napas.fase_keluar'),
      _ => kamus.t('napas.fase_jeda'),
    };
    return AnimatedBuilder(
      animation: _kontrol,
      builder: (context, _) {
        final t = _kontrol.value;
        // 0 → 1 saat masuk, tetap 1 saat tahan, 1 → 0 saat keluar.
        final skala = switch (fase) {
          'masuk' => 0.70 + 0.30 * Curves.easeInOut.transform(t),
          'keluar' => 1 - 0.30 * Curves.easeInOut.transform(t),
          'tahan' => 1.0,
          _ => 0.70,
        };
        final sisa = math.max(1, (_durasiFase * (1 - t)).ceil());
        return Center(
          child: SizedBox(
            width: 288,
            height: 288,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (final d in [288.0, 248.0])
                  Container(
                    width: d,
                    height: d,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: tones.aksen.withValues(alpha: 0.10),
                        width: 1.5,
                      ),
                    ),
                  ),
                Transform.scale(
                  scale: skala,
                  child: Container(
                    width: 216,
                    height: 216,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          tones.aksen.withValues(alpha: 0.92),
                          tones.aksenDeep.withValues(alpha: 0.96),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: tones.aksen.withValues(alpha: 0.35),
                          blurRadius: 40,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$sisa',
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 48,
                                height: 1.05,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const Text(
                              's',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 288,
                  height: 288,
                  child: CustomPaint(
                    painter: _CincinProgres(
                      nilai: t,
                      warna: tones.aksen,
                      jalur: tones.aksen.withValues(alpha: 0.16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tombolMulai(L10n kamus, AppTones tones) {
    final label = !_jalan && _siklus == 0 && _fase == 0
        ? kamus.t('napas.mulai')
        : (_jalan ? kamus.t('napas.jeda') : kamus.t('napas.lanjut'));
    return FilledButton.icon(
      onPressed: _toggle,
      icon: Icon(
        _jalan ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: 20,
      ),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: tones.card,
        foregroundColor: tones.ink,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        elevation: 3,
        shadowColor: tones.bayangan.withValues(alpha: 0.25),
        textStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _KartuMode extends StatelessWidget {
  const _KartuMode({
    required this.pola,
    required this.kamus,
    required this.aktif,
    required this.onTap,
  });

  final PolaNapas pola;
  final L10n kamus;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: aktif ? tones.aksenSoft : tones.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: aktif ? tones.aksen : Colors.transparent,
            width: 1.4,
          ),
          boxShadow: aktif ? null : tones.softShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: aktif ? tones.card : tones.panel,
                shape: BoxShape.circle,
              ),
              child: Icon(
                pola.kunci == 'napas.mode_box'
                    ? Icons.crop_square_rounded
                    : (pola.kunci == 'napas.mode_pursed'
                          ? Icons.air_rounded
                          : Icons.nightlight_round),
                size: 17,
                color: tones.aksenDeep,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              kamus.t(pola.kunci),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTeks.judulBaris(tones).copyWith(fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              kamus.t(pola.deskripsi),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTeks.labelSeksi(tones).copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cincin progres tipis di tepi orb.
class _CincinProgres extends CustomPainter {
  const _CincinProgres({
    required this.nilai,
    required this.warna,
    required this.jalur,
  });

  final double nilai;
  final Color warna;
  final Color jalur;

  @override
  void paint(Canvas canvas, Size size) {
    final tengah = size.center(Offset.zero);
    final radius = size.width / 2 - 5;
    final cat = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(tengah, radius, cat..color = jalur);
    canvas.drawArc(
      Rect.fromCircle(center: tengah, radius: radius),
      -math.pi / 2,
      2 * math.pi * nilai.clamp(0, 1),
      false,
      cat..color = warna,
    );
  }

  @override
  bool shouldRepaint(covariant _CincinProgres lama) =>
      lama.nilai != nilai || lama.warna != warna;
}
