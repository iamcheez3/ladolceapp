import 'package:flutter/material.dart';

/// LaDolce design system ("paper ticket on navy", Oct 2026 redesign).
///
/// One place for colors, type and the small pieces every screen shares.
/// Screens use these instead of raw values so the look stays consistent.
/// Mockups: claude.ai canvas "LaDolce POS redesign".
class Ld {
  Ld._();

  // ── Colors ────────────────────────────────────────────────────────────
  /// Brand navy: headers, rails, primary buttons.
  static const Color navy = Color(0xFF001460);
  /// Raised navy (keypad panel, cards on navy).
  static const Color navyRaised = Color(0xFF0A1F78);
  /// Outlines and dividers on navy.
  static const Color navyLine = Color(0xFF3A4A9A);
  /// Secondary text on navy.
  static const Color onNavyMuted = Color(0xFFAEB6D9);

  /// Gold accent: totals on navy, the main action on navy, badges.
  /// Never as text on white (too little contrast).
  static const Color gold = Color(0xFFC6A15B);
  static const Color goldInk = Color(0xFF8A6A2E);
  static const Color goldWash = Color(0xFFF7F3EA);
  static const Color goldWashInk = Color(0xFF5C4718);

  /// App background (cool porcelain) and surfaces.
  static const Color ground = Color(0xFFEEF1F6);
  static const Color surface = Colors.white;
  static const Color line = Color(0xFFD7DCE8);
  static const Color lineSoft = Color(0xFFE3E7F0);

  /// Text.
  static const Color ink = Color(0xFF13183A);
  static const Color muted = Color(0xFF5A6180);
  static const Color faint = Color(0xFF9AA3C4);

  /// Status (always with a label or icon, never color alone).
  static const Color success = Color(0xFF0F6B44);
  static const Color successStrong = Color(0xFF0F7B4E);
  static const Color successWash = Color(0xFFE7F5EE);
  static const Color warning = Color(0xFF8A5A00);
  static const Color warningWash = Color(0xFFFDF3E1);
  static const Color danger = Color(0xFFB42318);
  static const Color dangerWash = Color(0xFFFDF1F0);
  static const Color dangerLine = Color(0xFFE7B4AE);
  static const Color info = Color(0xFF1D4E9E);
  static const Color infoWash = Color(0xFFE7F0FD);

  // ── Type ──────────────────────────────────────────────────────────────
  /// UI font (bundled). Latin falls back to the system font.
  static const String sans = 'NotoSansLao';
  /// Prices, totals and titles: the same font the receipt prints in.
  static const String serif = 'NotoSerifLao';

  /// A price or a big number, in the receipt font.
  static TextStyle price(double size, {Color color = navy, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontFamily: serif, fontSize: size, fontWeight: weight, color: color, height: 1.2);

  /// Screen / section title, in the receipt font.
  static TextStyle title(double size, {Color color = navy}) =>
      TextStyle(fontFamily: serif, fontSize: size, fontWeight: FontWeight.w700, color: color, height: 1.25);

  static const TextStyle body = TextStyle(fontSize: 16, color: ink, height: 1.4);
  static const TextStyle label = TextStyle(fontSize: 14, color: muted, height: 1.35);
  static const TextStyle small = TextStyle(fontSize: 13, color: muted, height: 1.35);

  // ── Shape & spacing ───────────────────────────────────────────────────
  static const double rSm = 10;
  static const double r = 12;
  static const double rMd = 14;
  static const double rLg = 16;
  static const double rXl = 18;

  /// Minimum touch target.
  static const double tap = 48;

  static BorderRadius br(double r) => BorderRadius.circular(r);

  /// White card with a hairline border and no shadow.
  static BoxDecoration card({double radius = rLg, Color color = surface, Color border = line}) =>
      BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius), border: Border.all(color: border));

  /// Bottom inset for the system navigation (3-button bar or gesture handle).
  static double navInset(BuildContext context) => MediaQuery.viewPaddingOf(context).bottom;

  /// Bottom padding for a sheet: keyboard + navigation bar.
  static double sheetInset(BuildContext context) =>
      MediaQuery.viewInsetsOf(context).bottom + MediaQuery.viewPaddingOf(context).bottom;

  /// Phone vs tablet split used by every screen (shortest side, so rotating
  /// a phone never turns it into a "tablet").
  static bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).shortestSide >= 600;
}

/// Navy screen header with a 44 px outlined leading button (back or menu).
class LdHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;
  final double height;

  const LdHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.bottom,
    this.height = 68,
  });

  @override
  Size get preferredSize => Size.fromHeight(height + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Ld.navy,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    if (leading != null) leading! else _autoLeading(context),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Ld.title(22, color: Colors.white),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: Ld.onNavyMuted),
                            ),
                        ],
                      ),
                    ),
                    ...actions.map((a) => Padding(padding: const EdgeInsets.only(left: 8), child: a)),
                  ],
                ),
              ),
            ),
            if (bottom != null) bottom!,
          ],
        ),
      ),
    );
  }

  Widget _autoLeading(BuildContext context) {
    final route = ModalRoute.of(context);
    final scaffold = Scaffold.maybeOf(context);
    if (route?.canPop ?? false) {
      return LdNavIconButton(
        icon: Icons.arrow_back_rounded,
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => Navigator.maybePop(context),
      );
    }
    if (scaffold?.hasDrawer ?? false) {
      return LdNavIconButton(
        icon: Icons.menu_rounded,
        tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
        onPressed: () => scaffold!.openDrawer(),
      );
    }
    return const SizedBox(width: 4);
  }
}

/// 44 px square icon button outlined for use on navy.
class LdNavIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Widget? badge;

  const LdNavIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Ld.r),
          side: const BorderSide(color: Ld.navyLine),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Ld.r),
          onTap: onPressed,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
    return Tooltip(
      message: tooltip,
      child: badge == null
          ? button
          : Stack(clipBehavior: Clip.none, children: [button, Positioned(top: -6, right: -6, child: badge!)]),
    );
  }
}

/// Small rounded count / status badge.
class LdBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const LdBadge(this.text, {super.key, this.color = Ld.danger, this.textColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// Status / tag pill with a soft background.
class LdPill extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  final IconData? icon;

  const LdPill(this.text, {super.key, this.background = Ld.ground, this.foreground = Ld.navy, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: foreground), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Choice chip used for category / filter rows (navy when selected).
class LdChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final String? count;

  const LdChoiceChip({super.key, required this.label, required this.selected, this.onTap, this.count});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Ld.navy : Ld.surface,
      shape: StadiumBorder(side: BorderSide(color: selected ? Ld.navy : Ld.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? Colors.white : Ld.ink,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Text(count!, style: TextStyle(fontSize: 13, color: selected ? Ld.gold : Ld.muted)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Square soft-tinted icon holder used at the start of list rows.
class LdIconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color background;
  final Color color;

  const LdIconTile(this.icon, {super.key, this.size = 44, this.background = Ld.ground, this.color = Ld.navy});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(Ld.r)),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// The torn bottom edge of a paper ticket / receipt.
class LdTicketEdge extends StatelessWidget {
  final Color color;
  final double height;

  const LdTicketEdge({super.key, this.color = Colors.white, this.height = 10});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _TicketEdgePainter(color)),
    );
  }
}

class _TicketEdgePainter extends CustomPainter {
  final Color color;
  _TicketEdgePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const tooth = 10.0;
    final count = (size.width / tooth).ceil();
    final step = size.width / count;
    final path = Path()..moveTo(0, 0)..lineTo(size.width, 0)..lineTo(size.width, 2);
    for (var i = count; i > 0; i--) {
      final x = i * step;
      path.lineTo(x - step / 2, size.height);
      path.lineTo(x - step, 2);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TicketEdgePainter old) => old.color != color;
}

/// Section of white content with a hairline border (forms, lists).
class LdSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? title;

  const LdSection({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: Ld.card(),
      padding: padding,
      child: title == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Ld.ink)),
                const SizedBox(height: 12),
                child,
              ],
            ),
    );
  }
}
