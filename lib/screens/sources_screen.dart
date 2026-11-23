import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import '../models/sumber_riset.dart';
import '../services/rule_config.dart';
import 'level_style.dart';

/// Daftar isi kepala dari setiap angka yang dipakai aplikasi ini.
///
/// Layar ini hanya membaca `sumber_riset` dari rule_config.json — tidak ada
/// satu pun judul, tahun, atau tautan yang ditulis di Dart, supaya daftar ini
/// tidak bisa menyimpang dari angka yang benar-benar dipakai rule engine.
class SourcesScreen extends StatefulWidget {
  const SourcesScreen({required this.config, super.key});

  final RuleConfig config;

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  /// Tipe yang sedang disaring. Kosong = tampilkan semua rujukan.
  final Set<String> _tipeAktif = <String>{};

  Future<void> _buka(SumberRiset sumber) async {
    final kamus = L10n.of(context);
    final uri = Uri.tryParse(sumber.url.trim());
    if (uri == null || !uri.hasAbsolutePath) {
      debugPrint('Sumber "${sumber.judul}" punya URL cacat: ${sumber.url}');
      return;
    }
    try {
      final terbuka = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!terbuka) throw StateError('launchUrl mengembalikan false');
    } catch (e, s) {
      // Web bisa menolak popup-blocker, Android kalau tidak ada browser aktif.
      debugPrint('Gagal membuka ${sumber.url}: $e — $s');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kamus.t('sumber.gagal_buka', {'url': sumber.url})),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _saring(String? tipe) {
    setState(() {
      _tipeAktif
        ..clear()
        ..addAll(tipe == null ? const <String>[] : {tipe});
    });
  }

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final kamus = L10n.of(context);
    final semua = widget.config.sumberRiset;
    final total = semua.fold<int>(0, (a, k) => a + k.jumlah);
    final perluCek = semua
        .expand((k) => k.sumber)
        .where((s) => s.status != 'terverifikasi')
        .length;
    final catatan = widget.config.sumberRisetCatatan(locale: kamus.kode);

    final kelompok = [
      for (final k in semua)
        if (_tipeAktif.isEmpty)
          k
        else ...[
          if (k.sumber.any((s) => _tipeAktif.contains(s.tipe)))
            KelompokSumber(
              judul: k.judul,
              deskripsi: k.deskripsi,
              judulEn: k.judulEn,
              deskripsiEn: k.deskripsiEn,
              sumber: k.sumber
                  .where((s) => _tipeAktif.contains(s.tipe))
                  .toList(),
            ),
        ],
    ];

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
          Row(
            children: [
              if (bisaKembali) ...[
                _TombolKembaliSumber(onTap: () => Navigator.pop(context)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: KepalaHalaman(
                  judul: kamus.t('sumber.judul'),
                  ikon: Icons.menu_book_rounded,
                ),
              ),
            ],
          ),
          AppLayout.jarak,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.format_quote_rounded, size: 20, color: tones.aksen),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  kamus.t('sumber.pengantar'),
                  style: AppTeks.isi(tones)
                      .copyWith(fontSize: 14.5, color: tones.inkSoft),
                ),
              ),
            ],
          ),
          AppLayout.jarak,
          if (semua.isEmpty)
            EmptyState(
              ikon: Icons.menu_book_outlined,
              judul: kamus.t('sumber.kosong_judul'),
              pesan: kamus.t('sumber.kosong_pesan'),
            )
          else ...[
            _Ringkasan(
              total: total,
              topik: semua.length,
              perluCek: perluCek,
              kelompok: semua,
              tipeAktif: _tipeAktif,
              onPilih: _saring,
            ),
            if (kelompok.isEmpty)
              EmptyState(
                ikon: Icons.filter_alt_outlined,
                judul: kamus.t('sumber.filter_kosong_judul'),
                pesan: kamus.t('sumber.filter_kosong_pesan', {'n': '$total'}),
              )
            else
              for (final k in kelompok)
                _KelompokKartu(kelompok: k, onBuka: _buka),
            SectionCard(
              judul: kamus.t('sumber.verifikasi_judul'),
              ikon: Icons.verified_outlined,
              children: [
                Text(
                  catatan == ''
                      ? kamus.t('sumber.verifikasi_default')
                      : catatan,
                  style: AppTeks.isi(tones)
                      .copyWith(fontSize: 14, color: tones.inkSoft),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Kartu ringkasan + filter tipe. Filter hanya menyaring tampilan; tidak ada
/// angka klinis yang bisa diubah di layar ini.
class _Ringkasan extends StatelessWidget {
  const _Ringkasan({
    required this.total,
    required this.topik,
    required this.perluCek,
    required this.kelompok,
    required this.tipeAktif,
    required this.onPilih,
  });

  final int total;
  final int topik;
  final int perluCek;
  final List<KelompokSumber> kelompok;
  final Set<String> tipeAktif;
  final void Function(String?) onPilih;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final kamus = L10n.of(context);
    final tipe = <String, int>{};
    for (final k in kelompok) {
      for (final s in k.sumber) {
        tipe[s.tipe] = (tipe[s.tipe] ?? 0) + 1;
      }
    }
    final urut = tipe.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SectionCard(
      judul: kamus.t('sumber.ringkasan_judul'),
      ikon: Icons.library_books_outlined,
      ukuranJudul: 18,
      children: [
        Row(
          children: [
            Expanded(
              child: MiniStat(
                nilai: '$total',
                label: kamus.t('sumber.label_rujukan'),
              ),
            ),
            Expanded(
              child: MiniStat(
                nilai: '$topik',
                label: kamus.t('sumber.label_topik'),
              ),
            ),
            Expanded(
              child: MiniStat(
                nilai: '$perluCek',
                label: kamus.t('sumber.label_perlu_cek'),
                warna: perluCek == 0 ? tones.aman : tones.waspada,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                kamus.t('sumber.filter_judul'),
                style: AppTeks.labelSeksi(tones),
              ),
            ),
            InfoChip(teks: kamus.t('sumber.n_rujukan', {'n': '$total'})),
          ],
        ),
        const SizedBox(height: 10),
        // Pil filter gaya `PrimaryTabButton`: radius 50, aktif biru penuh,
        // sisanya bidang panel; daftar panjang bisa digeser mendatar seperti
        // baris `Container(height: 120, ListView(horizontal))` template.
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              PilTab(
                teks: kamus.t('sumber.filter_semua'),
                aktif: tipeAktif.isEmpty,
                onTap: () => onPilih(null),
              ),
              for (final entry in urut)
                PilTab(
                  teks: '${_labelTipe(kamus, entry.key)} · ${entry.value}',
                  aktif: tipeAktif.contains(entry.key),
                  onTap: () =>
                      onPilih(tipeAktif.contains(entry.key) ? null : entry.key),
                ),
            ],
          ),
        ),
        if (perluCek > 0) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 20, color: tones.waspada),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  kamus.t('sumber.filter_catatan', {'n': '$perluCek'}),
                  style: AppTeks.isi(tones)
                      .copyWith(fontSize: 13.5, color: tones.inkSoft),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _KelompokKartu extends StatelessWidget {
  const _KelompokKartu({required this.kelompok, required this.onBuka});

  final KelompokSumber kelompok;
  final void Function(SumberRiset) onBuka;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final kamus = L10n.of(context);
    final locale = kamus.kode;
    return SectionCard(
      judul: kelompok.judulDalam(locale),
      // Ikon dicocokkan dari judul Indonesia karena kata kuncinya berbahasa
      // Indonesia, jadi pemetaan ikon tidak berubah saat bahasa diganti.
      ikon: _ikonTopik(kelompok.judul),
      deskripsi: kelompok.deskripsiDalam(locale),
      trailing: InfoChip(
        teks: kamus.t('sumber.n_rujukan', {'n': '${kelompok.jumlah}'}),
      ),
      children: [
        // Daftar baris di dalam satu bidang `#20222A`/lavender dengan
        // pembatas 1 px — anatomi `ProfileTextOption`, bukan kartu per baris.
        GrupBaris(
          warna: tones.panel,
          paddingTombol: false,
          children: [
            for (final sumber in kelompok.sumber)
              _RujukanBaris(sumber: sumber, onBuka: onBuka),
          ],
        ),
      ],
    );
  }

  /// Ikon topik dipilih dari kata kunci judul supaya tetap cocok kalau judul
  /// di rule_config.json berubah.
  static IconData _ikonTopik(String judul) {
    final t = judul.toLowerCase();
    if (t.contains('oksigen') || t.contains('napas')) {
      return Icons.air_rounded;
    }
    if (t.contains('jantung') || t.contains('denyut')) {
      return Icons.favorite_rounded;
    }
    if (t.contains('tidur')) return Icons.bedtime_rounded;
    if (t.contains('dingin') || t.contains('angin')) {
      return Icons.ac_unit_rounded;
    }
    if (t.contains('udara')) return Icons.wb_cloudy_outlined;
    if (t.contains('aktivitas') || t.contains('siklus')) {
      return Icons.directions_run_rounded;
    }
    if (t.contains('baseline') ||
        t.contains('metode') ||
        t.contains('statistik')) {
      return Icons.insights_outlined;
    }
    if (t.contains('data') || t.contains('perangkat')) {
      return Icons.cloud_download_outlined;
    }
    return Icons.menu_book_outlined;
  }
}

/// Satu rujukan dalam [GrupBaris], dengan anatomi `BadgedContainer`: kotak
/// ikon 44 bersudut 10 di kiri, judul 17 bold, kredit kecil muted, pil jenis,
/// lalu kotak tautan di kanan.
class _RujukanBaris extends StatelessWidget {
  const _RujukanBaris({required this.sumber, required this.onBuka});

  final SumberRiset sumber;
  final void Function(SumberRiset) onBuka;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final kamus = L10n.of(context);
    final bisaDibuka = sumber.punyaTautan && sumber.status != 'tidak_ditemukan';
    final warnaTipe = _TipeStyle.warna(sumber.tipe, tones);
    final menetapkan = sumber.menetapkanDalam(kamus.kode);
    final catatan = sumber.catatanDalam(kamus.kode);

    return InkWell(
      onTap: bisaDibuka ? () => onBuka(sumber) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KotakIkon(ikon: _TipeStyle.ikon(sumber.tipe), warna: warnaTipe),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sumber.judul,
                        style: AppTeks.judulBaris(tones)
                            .copyWith(fontSize: 16, height: 1.3),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        sumber.kredit,
                        style: AppTeks.isi(tones)
                            .copyWith(fontSize: 13, color: tones.inkSoft),
                      ),
                      const SizedBox(height: 8),
                      InfoChip(
                        teks: _labelTipe(kamus, sumber.tipe),
                        warna: warnaTipe,
                      ),
                    ],
                  ),
                ),
                if (bisaDibuka) ...[
                  const SizedBox(width: 10),
                  KotakIkon(
                    ikon: Icons.open_in_new_rounded,
                    warna: tones.aksen,
                    ukuran: 40,
                    ukuranIkon: 18,
                  ),
                ],
              ],
            ),
            if (menetapkan.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final angka in menetapkan)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.arrow_right_rounded,
                        size: 18,
                        color: warnaTipe,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          angka,
                          style: AppTeks.isi(tones).copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (catatan != null && catatan.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: tones.card,
                  borderRadius: BorderRadius.circular(AppLayout.radiusGrup),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 16,
                      color: tones.inkSoft,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        catatan,
                        style: AppTeks.isi(tones)
                            .copyWith(fontSize: 13, color: tones.inkSoft),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (sumber.status != 'terverifikasi') ...[
              const SizedBox(height: 12),
              _StatusChip(status: sumber.status),
            ],
          ],
        ),
      ),
    );
  }
}

/// Label jenis rujukan. `jurnal` dan sejenisnya adalah kunci data di
/// rule_config.json, jadi hanya labelnya yang ikut bahasa.
String _labelTipe(L10n kamus, String tipe) {
  const dikenal = {
    'jurnal',
    'pedoman',
    'standar',
    'buku',
    'api',
    'dataset',
    'paket',
    'web',
  };
  return dikenal.contains(tipe) ? kamus.t('sumber.tipe_$tipe') : tipe;
}

/// Warna + ikon kecil per jenis rujukan, dipakai di chip filter dan baris.
///
/// Hue-nya diambil dari palet template Taskez; mode gelap memakai versi
/// pastelnya supaya tetap terbaca di atas kartu navy.
class _TipeStyle {
  const _TipeStyle._();

  static const Map<String, Color> _terang = {
    'jurnal': Color(0xFF246CFD),
    'pedoman': Color(0xFF2E9E63),
    'standar': Color(0xFF8B3FCB),
    'buku': Color(0xFF8D6748),
    'api': Color(0xFF0E8FA0),
    'dataset': Color(0xFFDC6B2E),
    'paket': Color(0xFF55606E),
    'web': Color(0xFF00796B),
  };

  static const Map<String, Color> _gelap = {
    'jurnal': Color(0xFF7FA8FF),
    'pedoman': Color(0xFF94D57B),
    'standar': Color(0xFFC25FFF),
    'buku': Color(0xFFD2A679),
    'api': Color(0xFF8CE0DF),
    'dataset': Color(0xFFFC946E),
    'paket': Color(0xFF9AA6B8),
    'web': Color(0xFF87D3DF),
  };

  static Color warna(String tipe, AppTones tones) {
    final tabel = identical(tones, AppTones.gelap) ? _gelap : _terang;
    return tabel[tipe] ?? tones.netral;
  }

  static IconData ikon(String tipe) => switch (tipe) {
    'jurnal' => Icons.article_outlined,
    'pedoman' => Icons.policy_outlined,
    'standar' => Icons.fact_check_outlined,
    'buku' => Icons.book_outlined,
    'api' => Icons.wifi_tethering_rounded,
    'dataset' => Icons.storage_rounded,
    'paket' => Icons.inventory_2_outlined,
    'web' => Icons.public_rounded,
    _ => Icons.description_outlined,
  };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final kamus = L10n.of(context);
    final (teks, color, ikon) = switch (status) {
      'perlu_cek' => (
        kamus.t('sumber.status_perlu_cek'),
        tones.waspada,
        Icons.visibility_outlined,
      ),
      'tidak_ditemukan' => (
        kamus.t('sumber.status_tidak_ditemukan'),
        tones.netral,
        Icons.help_outline_rounded,
      ),
      _ => (status, tones.netral, Icons.info_outline_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
        borderRadius: BorderRadius.circular(AppLayout.radiusKartu),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              teks,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TombolKembaliSumber extends StatelessWidget {
  const _TombolKembaliSumber({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tones.panel,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: tones.ink,
        ),
      ),
    );
  }
}
