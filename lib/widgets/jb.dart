import 'package:flutter/material.dart';

import '../screens/level_style.dart';

/// Komponen kecil yang dipakai berulang di layar Just Breathe.
///
/// Semuanya membaca [AppTones] dari tema, jadi terang/gelap tidak perlu
/// ditangani per layar.

/// Kartu putih radius 24 dengan bayangan biru tipis — bentuk dasar seluruh UI.
class JbCard extends StatelessWidget {
  const JbCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.gradient,
    this.onTap,
    this.border,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final isi = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? tones.card) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppLayout.radiusKartu),
        border: border,
        boxShadow: gradient == null ? tones.softShadow() : null,
      ),
      child: child,
    );
    if (onTap == null) return isi;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppLayout.radiusKartu),
        child: isi,
      ),
    );
  }
}

/// Pil status: ikon + label di atas bidang pastel.
///
/// Warna tidak pernah menjadi satu-satunya pembeda — selalu ada ikon dan teks.
class JbStatusPill extends StatelessWidget {
  const JbStatusPill({
    required this.label,
    required this.color,
    this.icon,
    this.compact = false,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppLayout.radiusPil),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 13 : 15, color: color),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bar skala AQI lima warna dengan penanda posisi nilai saat ini.
class JbAqiBar extends StatelessWidget {
  const JbAqiBar({required this.aqi, this.tampilPenanda = true, super.key});

  final double aqi;
  final bool tampilPenanda;

  static const List<Color> _bands = [
    AppPalette.aqiGood,
    AppPalette.aqiModerate,
    AppPalette.aqiSensitive,
    AppPalette.aqiUnhealthy,
    AppPalette.aqiHazardous,
  ];

  /// Skala dipetakan 0-300 ke lebar bar; nilai di atas 300 menempel di ujung.
  static double posisi(double nilai) => (nilai.clamp(0, 300)) / 300;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const tinggi = 10.0;
        const lebarPenanda = 16.0;
        final lebar = constraints.maxWidth;
        final x = (lebar - lebarPenanda) * posisi(aqi);
        return SizedBox(
          height: tinggi + 10,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 5,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppLayout.radiusPil),
                  child: Row(
                    children: [
                      for (final warna in _bands)
                        Expanded(
                          child: Container(height: tinggi, color: warna),
                        ),
                    ],
                  ),
                ),
              ),
              if (tampilPenanda)
                Positioned(
                  top: 0,
                  left: x,
                  child: Container(
                    width: lebarPenanda,
                    height: lebarPenanda,
                    decoration: BoxDecoration(
                      color: tones.card,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTones.aqiBand(aqi),
                        width: 3,
                      ),
                      boxShadow: tones.softShadow(tint: Colors.black),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Kartu statistik mini: label + titik status, angka besar, bar tipis.
class JbMiniStat extends StatelessWidget {
  const JbMiniStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.status,
    required this.progress,
    super.key,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;
  final String status;

  /// 0..1, panjang isi bar.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return JbCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTeks.labelSeksi(tones).copyWith(
                    fontSize: 12.5,
                    color: tones.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                    fontSize: 24,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    color: tones.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: tones.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              children: [
                Container(height: 5, color: tones.line),
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.02, 1),
                  child: Container(height: 5, color: color),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Judul seksi dengan aksi opsional di kanan.
class JbSectionTitle extends StatelessWidget {
  const JbSectionTitle({
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(top: 22, bottom: 12),
    super.key,
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTeks.judulKartu(tones).copyWith(fontSize: 17),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Tombol bulat putih untuk ikon di kepala layar.
class JbIconButton extends StatelessWidget {
  const JbIconButton({
    required this.icon,
    required this.onTap,
    this.badge,
    this.tooltip,
    this.size = 44,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final int? badge;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final tombol = SizedBox(
      width: size,
      height: size,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: size * 0.48),
        color: tones.ink,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: tones.card,
          shape: const CircleBorder(),
          shadowColor: tones.bayangan.withValues(alpha: 0.18),
          elevation: 2,
        ),
      ),
    );
    final denganBadge = badge == null || badge == 0
        ? tombol
        : Badge(
            label: Text('$badge'),
            backgroundColor: tones.bahaya,
            textColor: Colors.white,
            child: tombol,
          );
    if (tooltip == null) return denganBadge;
    return Tooltip(message: tooltip!, child: denganBadge);
  }
}

/// Avatar bulat dengan titik "online" di sudut kanan bawah.
class JbAvatar extends StatelessWidget {
  const JbAvatar({
    required this.name,
    this.size = 46,
    this.online = true,
    this.onTap,
    super.key,
  });

  final String? name;
  final double size;
  final bool online;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    final inisial = (name == null || name!.trim().isEmpty)
        ? 'JB'
        : name!
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((k) => k.substring(0, 1).toUpperCase())
              .join();
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tones.aksen, tones.aksenDeep],
        ),
        border: Border.all(color: tones.card, width: 2),
        boxShadow: tones.softShadow(),
      ),
      child: Text(
        inisial,
        style: TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
    final bertitik = Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        if (online)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.26,
              height: size * 0.26,
              decoration: BoxDecoration(
                color: AppPalette.aqiGood,
                shape: BoxShape.circle,
                border: Border.all(color: tones.card, width: 2),
              ),
            ),
          ),
      ],
    );
    if (onTap == null) return bertitik;
    return GestureDetector(onTap: onTap, child: bertitik);
  }
}
