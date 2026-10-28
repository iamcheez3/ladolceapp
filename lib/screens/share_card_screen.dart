import 'dart:io';
import 'dart:ui' as ui;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/ld.dart';

/// The bear from the app icon, white on transparent. Tint it with
/// [LdBearMark.color]; used as the LaDolce watermark on member cards.
const String kBearMarkAsset = 'assets/images/ladolce_bear_mark.png';

class LdBearMark extends StatelessWidget {
  final double width;
  final Color color;
  final double opacity;

  const LdBearMark({
    super.key,
    required this.width,
    this.color = Colors.white,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Opacity(
        opacity: opacity,
        child: Image.asset(
          kBearMarkAsset,
          width: width,
          color: color,
          colorBlendMode: BlendMode.srcIn,
          errorBuilder: (_, _, _) => SizedBox(width: width),
        ),
      ),
    );
  }
}

/// Colour sets for the shared card. Every set keeps the bear visible.
class _CardStyle {
  final Color background;
  final Color text;
  final Color soft;
  final Color accent;
  final Color mark;
  final Color chip;
  final Color swatchBorder;

  const _CardStyle({
    required this.background,
    required this.text,
    required this.soft,
    required this.accent,
    required this.mark,
    required this.chip,
    this.swatchBorder = Colors.transparent,
  });
}

const _cardStyles = <_CardStyle>[
  _CardStyle(
    background: Ld.navy,
    text: Colors.white,
    soft: Color(0xFFDDE2F5),
    accent: Ld.gold,
    mark: Colors.white,
    chip: Ld.navyRaised,
  ),
  _CardStyle(
    background: Ld.gold,
    text: Ld.navy,
    soft: Ld.ink,
    accent: Ld.navy,
    mark: Ld.navy,
    chip: Color(0xFFD9BD86),
  ),
  _CardStyle(
    background: Colors.white,
    text: Ld.navy,
    soft: Ld.muted,
    accent: Ld.goldInk,
    mark: Ld.navy,
    chip: Ld.ground,
    swatchBorder: Ld.line,
  ),
  _CardStyle(
    background: Ld.ink,
    text: Colors.white,
    soft: Color(0xFFDDE2F5),
    accent: Ld.gold,
    mark: Colors.white,
    chip: Color(0xFF262C55),
  ),
];

/// "Share my card": a story-sized member card (1080 × 1920 when exported)
/// with the LaDolce bear on it, shared to other apps or saved to Photos.
class ShareCardScreen extends StatefulWidget {
  final String name;
  final int points;

  /// Position in the Top 50; 0 when the customer is not ranked.
  final int rank;
  final ImageProvider? avatar;

  const ShareCardScreen({
    super.key,
    required this.name,
    required this.points,
    required this.rank,
    this.avatar,
  });

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  static const _channel = MethodChannel('ladolce/share');

  // Logical card size; exported at 4x = 1080 × 1920 (a phone story).
  static const double _cardW = 270;
  static const double _cardH = 480;

  final _cardKey = GlobalKey();
  int _style = 0;
  late bool _showRank = widget.rank > 0;
  bool _showPoints = true;
  bool _busy = false;

  AppLocalizations? get _l10n => AppLocalizations.of(context);

  Future<Uint8List?> _renderPng() async {
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 1080 / _cardW);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  /// Writes the card to cache/share (the folder the Android FileProvider
  /// exposes) and returns the file.
  Future<File?> _renderFile() async {
    final bytes = await _renderPng();
    if (bytes == null) return null;
    final dir = Directory('${(await getTemporaryDirectory()).path}/share');
    if (await dir.exists()) {
      // Keep only the newest card.
      for (final old in dir.listSync()) {
        try {
          old.deleteSync();
        } catch (_) {}
      }
    } else {
      await dir.create(recursive: true);
    }
    final file = File(
      '${dir.path}/ladolce_card_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// [androidPackage]: open that app directly (Android only); null or not
  /// installed → the system share sheet.
  Future<void> _share({String? androidPackage}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final text = _l10n?.shareCardText ??
        "I'm a LaDolce regular! Order with the LaDolce app.";
    try {
      final file = await _renderFile();
      if (file == null) throw StateError('card not rendered');
      if (androidPackage != null && Platform.isAndroid) {
        final opened = await _channel.invokeMethod<bool>('shareImageToApp', {
          'path': file.path,
          'package': androidPackage,
          'text': text,
        });
        if (opened == true) return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: text,
          sharePositionOrigin: _shareOrigin(),
        ),
      );
    } catch (e) {
      debugPrint('[ShareCard] share failed: $e');
      _snack(_l10n?.couldNotShare ?? 'Could not share. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _canSaveToPhotos() async {
    if (Platform.isIOS) {
      final status = await Permission.photosAddOnly.request();
      if (status.isGranted || status.isLimited) return true;
      if (!mounted) return false;
      final blocked = status.isPermanentlyDenied || status.isRestricted;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            blocked
                ? (_l10n?.photosPermissionBlocked ??
                    'Photos permission is blocked. Open Settings to allow access.')
                : (_l10n?.photoPermissionToSave ??
                    'Photo permission is needed to save the image'),
          ),
          action: blocked
              ? SnackBarAction(
                  label: _l10n?.settings ?? 'Settings',
                  onPressed: openAppSettings,
                )
              : null,
        ),
      );
      return false;
    }
    if (Platform.isAndroid) {
      // Android 13+ saves images without a storage permission.
      int sdk = 30;
      try {
        sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
      } catch (_) {}
      if (sdk < 33 && !(await Permission.storage.request()).isGranted) {
        _snack(_l10n?.photoPermissionToSave ??
            'Photo permission is needed to save the image');
        return false;
      }
    }
    return true;
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!await _canSaveToPhotos()) return;
      final bytes = await _renderPng();
      if (bytes == null) throw StateError('card not rendered');
      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: 'ladolce_card_${DateTime.now().millisecondsSinceEpoch}',
      );
      final ok = result is Map &&
          (result['isSuccess'] == true ||
              result['success'] == true ||
              (result['filePath'] ?? '').toString().isNotEmpty);
      _snack(ok
          ? (_l10n?.imageSavedToPhotos ?? 'Saved to your photos')
          : (_l10n?.couldNotSaveImage ?? 'Could not save the image'));
    } catch (e) {
      debugPrint('[ShareCard] save failed: $e');
      _snack(_l10n?.couldNotSaveImage ?? 'Could not save the image');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final bottomInset = Ld.navInset(context);
    return Scaffold(
      backgroundColor: Ld.ground,
      appBar: LdHeader(title: l10n?.shareMyCard ?? 'Share my card'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // The card takes what the controls leave, but never gets tiny:
          // on short screens the page scrolls instead.
          final previewH = (constraints.maxHeight - 300).clamp(260.0, 520.0);
          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
                SizedBox(
                  height: previewH,
                  child: Center(
                    child: FittedBox(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x47001460),
                              blurRadius: 40,
                              offset: Offset(0, 18),
                            ),
                          ],
                        ),
                        child: RepaintBoundary(
                          key: _cardKey,
                          child: MediaQuery.withNoTextScaling(
                            child: _MemberCard(
                              width: _cardW,
                              height: _cardH,
                              style: _cardStyles[_style],
                              name: widget.name,
                              points: widget.points,
                              rank: widget.rank,
                              avatar: widget.avatar,
                              showRank: _showRank && widget.rank > 0,
                              showPoints: _showPoints,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Semantics(
                  label: l10n?.cardColour ?? 'Card colour',
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    children: [
                      for (var i = 0; i < _cardStyles.length; i++)
                        _Swatch(
                          style: _cardStyles[i],
                          selected: i == _style,
                          label: '${l10n?.cardColour ?? 'Card colour'} ${i + 1}',
                          onTap: () => setState(() => _style = i),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.rank > 0)
                      _ToggleChip(
                        label: l10n?.showRank ?? 'Show rank',
                        selected: _showRank,
                        onTap: () => setState(() => _showRank = !_showRank),
                      ),
                    _ToggleChip(
                      label: l10n?.showPoints ?? 'Show points',
                      selected: _showPoints,
                      onTap: () => setState(() => _showPoints = !_showPoints),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Ld.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: EdgeInsets.fromLTRB(12, 18, 12, 20 + bottomInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          (l10n?.shareTo ?? 'Share to').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: Ld.muted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(children: _targets(l10n)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _targets(AppLocalizations? l10n) {
    final targets = <Widget>[
      // Straight-to-app buttons only where Android can open one app; iOS
      // offers the same apps inside its share sheet.
      if (Platform.isAndroid) ...[
        _ShareTarget(
          label: 'Instagram',
          icon: Icons.camera_alt_outlined,
          wash: Ld.goldWash,
          ink: Ld.goldInk,
          onTap: _busy ? null : () => _share(androidPackage: 'com.instagram.android'),
        ),
        _ShareTarget(
          label: 'Facebook',
          icon: Icons.people_alt_outlined,
          wash: Ld.lineSoft,
          ink: Ld.navy,
          onTap: _busy ? null : () => _share(androidPackage: 'com.facebook.katana'),
        ),
        _ShareTarget(
          label: 'WhatsApp',
          icon: Icons.chat_bubble_outline_rounded,
          wash: Ld.successWash,
          ink: Ld.success,
          onTap: _busy ? null : () => _share(androidPackage: 'com.whatsapp'),
        ),
      ] else
        _ShareTarget(
          label: l10n?.shareAction ?? 'Share',
          icon: Icons.ios_share_rounded,
          wash: Ld.lineSoft,
          ink: Ld.navy,
          onTap: _busy ? null : () => _share(),
        ),
      _ShareTarget(
        label: l10n?.save ?? 'Save',
        icon: Icons.download_rounded,
        wash: Ld.infoWash,
        ink: Ld.info,
        onTap: _busy ? null : _save,
      ),
      if (Platform.isAndroid)
        _ShareTarget(
          label: l10n?.shareMore ?? 'More',
          icon: Icons.more_horiz_rounded,
          wash: Ld.ground,
          ink: Ld.navy,
          onTap: _busy ? null : () => _share(),
        ),
    ];
    return [for (final t in targets) Expanded(child: t)];
  }
}

class _MemberCard extends StatelessWidget {
  final double width;
  final double height;
  final _CardStyle style;
  final String name;
  final int points;
  final int rank;
  final ImageProvider? avatar;
  final bool showRank;
  final bool showPoints;

  const _MemberCard({
    required this.width,
    required this.height,
    required this.style,
    required this.name,
    required this.points,
    required this.rank,
    required this.avatar,
    required this.showRank,
    required this.showPoints,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final firstName = name.trim().split(RegExp(r'\s+')).first;
    final pts = _formatPoints(points);
    final initial = firstName.isEmpty ? 'L' : firstName.characters.first.toUpperCase();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: width,
        height: height,
        color: style.background,
        child: Stack(
          children: [
            // Watermark: the bear, big and faint behind the rank.
            Positioned(
              left: (width - 270) / 2,
              top: 150,
              child: LdBearMark(width: 270, color: style.mark, opacity: 0.08),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                children: [
                  LdBearMark(width: 34, color: style.accent),
                  const SizedBox(height: 6),
                  Text(
                    'LA DOLCE',
                    style: TextStyle(
                      fontFamily: Ld.sans,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3.6,
                      color: style.accent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: style.accent,
                    ),
                    child: CircleAvatar(
                      backgroundColor: Ld.navyRaised,
                      backgroundImage: avatar,
                      child: avatar == null
                          ? Text(initial, style: Ld.title(30, color: Colors.white))
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: width - 40,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        firstName.isEmpty ? 'LaDolce' : firstName,
                        maxLines: 1,
                        style: Ld.title(24, color: style.text),
                      ),
                    ),
                  ),
                  Text(
                    l10n?.isLaDolceRegular ?? 'is a LaDolce regular',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: Ld.sans, fontSize: 13, color: style.soft),
                  ),
                  const SizedBox(height: 14),
                  if (showRank) ...[
                    Text(
                      '#$rank',
                      style: Ld.price(66, color: style.accent, weight: FontWeight.w800)
                          .copyWith(height: 1.05),
                    ),
                    Text(
                      l10n?.inTheTop50 ?? 'in the Top 50',
                      style: TextStyle(
                        fontFamily: Ld.sans,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: style.soft,
                      ),
                    ),
                    if (showPoints) ...[
                      const SizedBox(height: 12),
                      Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: style.chip,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$pts pts',
                          style: TextStyle(
                            fontFamily: Ld.sans,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: style.text,
                          ),
                        ),
                      ),
                    ],
                  ] else if (showPoints) ...[
                    SizedBox(
                      width: width - 40,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          pts,
                          style: Ld.price(58, color: style.accent, weight: FontWeight.w800)
                              .copyWith(height: 1.05),
                        ),
                      ),
                    ),
                    Text(
                      'pts',
                      style: TextStyle(
                        fontFamily: Ld.sans,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: style.soft,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Ld.ground,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const LdBearMark(width: 30, color: Ld.navy),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n?.laDolceApp ?? 'LaDolce app',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: Ld.sans,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Ld.ink,
                                ),
                              ),
                              Text(
                                l10n?.orderCoffeeInApp ?? 'Order your coffee in the app',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: Ld.sans,
                                  fontSize: 11,
                                  color: Ld.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
}

String _formatPoints(int points) {
  final s = points.abs().toString();
  final b = StringBuffer(points < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

class _Swatch extends StatelessWidget {
  final _CardStyle style;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _Swatch({
    required this.style,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Ld.ink : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: style.background,
              border: Border.all(color: style.swatchBorder, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: selected,
      child: Material(
        color: selected ? Ld.navy : Ld.surface,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? Ld.navy : Ld.line),
        ),
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
                  Icon(
                    selected ? Icons.check_rounded : Icons.add_rounded,
                    size: 16,
                    color: selected ? Colors.white : Ld.navy,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : Ld.navy,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareTarget extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color wash;
  final Color ink;
  final VoidCallback? onTap;

  const _ShareTarget({
    required this.label,
    required this.icon,
    required this.wash,
    required this.ink,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Ld.r),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: wash, shape: BoxShape.circle),
              child: Icon(icon, color: ink, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Ld.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
