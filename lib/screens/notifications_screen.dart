import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/alert_record.dart';
import '../services/database_helpers.dart';
import '../widgets/jb.dart';
import 'level_style.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({required this.store, super.key});
  final DatabaseHelper store;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AlertRecord>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.store.getRecentAlerts(limit: 100);
  }

  Future<void> _muatUlang() async {
    setState(() => _future = widget.store.getRecentAlerts(limit: 100));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final kamus = L10n.of(context);
    final tones = AppTones.of(context);
    final id = kamus.kode == 'id';
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _muatUlang,
          child: FutureBuilder<List<AlertRecord>>(
            future: _future,
            builder: (context, snapshot) {
              final records = snapshot.data ?? const <AlertRecord>[];
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20, 32, 20, AppLayout.bawahKonten(context)),
                children: [
                  Row(children: [
                    JbIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      tooltip: kamus.t('umum.kembali'),
                      onTap: () => Navigator.maybePop(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(id ? 'Notifikasi' : 'Notifications', style: AppTeks.judulHalaman(tones))),
                    JbIconButton(icon: Icons.refresh_rounded, tooltip: id ? 'Muat ulang' : 'Refresh', onTap: _muatUlang),
                  ]),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 18),
                    child: Text(
                      id ? 'Pembaruan dari hasil pemantauan kesehatanmu.' : 'Updates from your health monitoring activity.',
                      style: AppTeks.isiSoft(tones).copyWith(fontSize: 12.5),
                    ),
                  ),
                  if (snapshot.connectionState != ConnectionState.done)
                    const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: CircularProgressIndicator()))
                  else if (snapshot.hasError)
                    EmptyState(
                      ikon: Icons.error_outline_rounded,
                      judul: id ? 'Notifikasi gagal dimuat' : 'Could not load notifications',
                      pesan: id ? 'Coba tarik layar ke bawah untuk memuat ulang.' : 'Pull down to try again.',
                    )
                  else if (records.isEmpty)
                    EmptyState(
                      ikon: Icons.notifications_none_rounded,
                      judul: id ? 'Belum ada notifikasi' : 'No notifications yet',
                      pesan: id ? 'Hasil pemantauan yang tersimpan akan muncul di sini.' : 'Saved monitoring updates will appear here.',
                    )
                  else ...[
                    Row(children: [
                      Expanded(child: Text(id ? 'Aktivitas terbaru' : 'Recent activity', style: AppTeks.judulKartu(tones).copyWith(fontSize: 16))),
                      Text('${records.length} ${id ? 'item' : 'items'}', style: AppTeks.labelSeksi(tones)),
                    ]),
                    const SizedBox(height: 12),
                    for (final record in records)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _NotificationTile(
                          record: record,
                          onTap: () => _showDetail(context, record, kamus, tones),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, AlertRecord record, L10n kamus, AppTones tones) {
    final accent = tones.level(record.level);
    final alasan = record.tampil(kamus);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.notifications_active_rounded, color: accent),
        title: Text(record.kondisi),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [LevelChip(level: record.level), const SizedBox(width: 8), Text('${record.skor}/100')]),
              const SizedBox(height: 12),
              Text(
                '${record.timestamp.day.toString().padLeft(2, '0')}/${record.timestamp.month.toString().padLeft(2, '0')}/${record.timestamp.year}  '
                '${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}',
                style: AppTeks.labelSeksi(tones),
              ),
              if (alasan.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final item in alasan) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• $item')),
              ],
              if (record.intervensi.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(record.intervensi, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(kamus.t('umum.tutup')))],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.record, required this.onTap});
  final AlertRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final accent = tones.level(record.level);
    final id = L10n.of(context).kode == 'id';
    return JbCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppLayout.radiusKartu),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
                child: Icon(Icons.notifications_active_outlined, color: accent, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(record.kondisi, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTeks.judulBaris(tones))),
                      const SizedBox(width: 6),
                      Text('${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}', style: AppTeks.labelSeksi(tones).copyWith(fontSize: 10)),
                    ]),
                    const SizedBox(height: 5),
                    Text('${record.level} · ${record.skor}/100', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      record.intervensi.isNotEmpty ? record.intervensi : (id ? 'Ketuk untuk melihat detail pemantauan.' : 'Tap to view monitoring details.'),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: AppTeks.isiSoft(tones).copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: tones.inkSoft, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
