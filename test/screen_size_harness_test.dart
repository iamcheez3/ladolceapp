// Screen-size layout survey harness (shared by test/screen_size_*_test.dart).
//
// Pumps a widget at a phone/tablet size, in en or lo, with optional large
// text, and records every layout problem instead of failing:
//   * overflow   - RenderFlex / RenderBox overflow errors (pixels + file:line)
//   * exception  - any other framework error raised while laying out
//   * clipped    - Text that hit maxLines and was ellipsised/clipped
//   * squeezed   - FittedBox that shrank its text below 75 %
//   * tap        - tappable semantics nodes smaller than 36 px, or off screen
//
// Real fonts are loaded so widths are realistic: Roboto (from the Flutter SDK
// cache) stands in for "Inter" (the app's en font is not bundled, so devices
// fall back to Roboto anyway) and the bundled Noto Serif Lao stands in for
// Noto Sans Lao (google_fonts, fetched at runtime on device).
//
// Results are printed as lines starting with "LAYOUT|" and, when the
// LAYOUT_REPORT environment variable names a file, appended to it.
//
// This file's own test only proves the harness catches a deliberate overflow.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:ladolce/theme/ld_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import 'package:ladolce/models/product.dart';

class LayoutCfg {
  final String name;
  final Size size;
  final double textScale;
  const LayoutCfg(this.name, this.size, [this.textScale = 1.0]);
}

const layoutConfigs = <LayoutCfg>[
  LayoutCfg('320x568', Size(320, 568)),
  LayoutCfg('360x640', Size(360, 640)),
  LayoutCfg('360x800', Size(360, 800)),
  LayoutCfg('390x844', Size(390, 844)),
  LayoutCfg('412x915', Size(412, 915)),
  LayoutCfg('600x960', Size(600, 960)),
  LayoutCfg('800x1280', Size(800, 1280)),
  LayoutCfg('1280x800', Size(1280, 800)),
  LayoutCfg('360x640@1.3', Size(360, 640), 1.3),
];

const layoutLocales = <String>['en', 'lo'];

class LayoutIssue {
  final String kind;
  final String detail;
  final String location;
  LayoutIssue(this.kind, this.detail, [this.location = '']);
  @override
  String toString() => '$kind: $detail ${location.isEmpty ? '' : '@ $location'}';
}

bool _fontsLoaded = false;

String _flutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && env.isNotEmpty) return env;
  for (final c in [r'C:\flutter', '/c/flutter']) {
    if (Directory(c).existsSync()) return c;
  }
  return r'C:\flutter';
}

Future<void> _loadFamily(String family, List<String> paths) async {
  final loader = FontLoader(family);
  var any = false;
  for (final p in paths) {
    final f = File(p);
    if (!f.existsSync()) continue;
    final bytes = f.readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    any = true;
  }
  if (any) await loader.load();
}

/// Loads Roboto as "Inter", Noto Serif Lao as "LaoUI", and Material icons.
Future<void> loadLayoutFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final mf = '${_flutterRoot()}/bin/cache/artifacts/material_fonts';
  await _loadFamily('Inter', [
    '$mf/roboto-regular.ttf',
    '$mf/roboto-medium.ttf',
    '$mf/roboto-bold.ttf',
    '$mf/roboto-black.ttf',
  ]);
  await _loadFamily('Roboto', [
    '$mf/roboto-regular.ttf',
    '$mf/roboto-medium.ttf',
    '$mf/roboto-bold.ttf',
  ]);
  await _loadFamily('LaoUI', [
    'assets/fonts/NotoSerifLao-Regular.ttf',
    'assets/fonts/NotoSerifLao-Bold.ttf',
  ]);
  // The real app fonts (bundled since the Oct 2026 redesign).
  await _loadFamily('NotoSansLao', [
    'assets/fonts/NotoSansLao-Regular.ttf',
    'assets/fonts/NotoSansLao-Medium.ttf',
    'assets/fonts/NotoSansLao-SemiBold.ttf',
    'assets/fonts/NotoSansLao-Bold.ttf',
  ]);
  await _loadFamily('NotoSerifLao', [
    'assets/fonts/NotoSerifLao-Regular.ttf',
    'assets/fonts/NotoSerifLao-Bold.ttf',
  ]);
  await _loadFamily('MaterialIcons', ['$mf/materialicons-regular.otf']);
}

/// The app's real theme (lib/theme/ld_theme.dart). Latin falls back to
/// Roboto, as on Android.
ThemeData layoutTheme(String locale) => buildLdTheme().copyWith(
      textTheme: buildLdTheme().textTheme.apply(fontFamilyFallback: const ['Roboto']),
    );

/// MaterialApp shaped like PosApp (localisations, clamped text scaling).
Widget layoutApp({
  required String locale,
  required double textScale,
  required Widget home,
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    debugShowCheckedModeBanner: false,
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: layoutTheme(locale),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.85,
        maxScaleFactor: 1.35,
        child: child ?? const SizedBox.shrink(),
      ),
    ),
    home: home,
  );
}

final _fileLoc = RegExp(r'file:///[^\s]+?\.dart:\d+:\d+');

String _shortLoc(String s) {
  final m = _fileLoc.firstMatch(s);
  if (m == null) return '';
  var p = m.group(0)!;
  final i = p.indexOf('/lib/');
  if (i >= 0) p = p.substring(i + 1);
  final t = p.indexOf('/test/');
  if (t >= 0) p = p.substring(t + 1);
  return p;
}

String _locOfElement(Element e) {
  try {
    final nodes = debugTransformDebugCreator(
        [DiagnosticsDebugCreator(DebugCreator(e))]);
    final text = nodes.map((n) => n.toStringDeep()).join('\n');
    return _shortLoc(text);
  } catch (_) {
    return '';
  }
}

String _oneLine(String s, [int max = 160]) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length > max ? '${t.substring(0, max)}...' : t;
}

LayoutIssue issueFromDetails(FlutterErrorDetails d) {
  final msg = d.exceptionAsString();
  final firstLine = msg.split('\n').first.trim();
  final full = d.toString();
  final loc = _shortLoc(full);
  if (firstLine.contains('overflowed')) {
    return LayoutIssue('overflow', firstLine, loc);
  }
  return LayoutIssue('exception', _oneLine(firstLine), loc);
}

/// Scan the current tree for ellipsised text, squeezed FittedBoxes and
/// unusable tap targets.
List<LayoutIssue> scanTree(WidgetTester tester, Size screen,
    {bool tapTargets = true}) {
  final out = <LayoutIssue>[];
  final seen = <String>{};
  void add(LayoutIssue i) {
    final k = '${i.kind}|${i.detail}|${i.location}';
    if (seen.add(k)) out.add(i);
  }

  for (final e in find.byType(RichText, skipOffstage: true).evaluate()) {
    final ro = e.renderObject;
    if (ro is! RenderParagraph || !ro.hasSize) continue;
    if (ro.didExceedMaxLines) {
      final txt = _oneLine(ro.text.toPlainText(), 60);
      if (txt.isEmpty) continue;
      add(LayoutIssue('clipped', '"$txt" (w=${ro.size.width.toStringAsFixed(0)})',
          _locOfElement(e)));
    }
  }

  for (final e in find.byType(FittedBox, skipOffstage: true).evaluate()) {
    final ro = e.renderObject;
    if (ro is! RenderFittedBox || !ro.hasSize) continue;
    final child = ro.child;
    if (child == null || !child.hasSize) continue;
    final cs = child.size;
    if (cs.width <= 0 || cs.height <= 0) continue;
    final scale = [ro.size.width / cs.width, ro.size.height / cs.height]
        .reduce((a, b) => a < b ? a : b);
    if (scale < 0.75) {
      final texts = <String>[];
      void visit(RenderObject r) {
        if (r is RenderParagraph) texts.add(r.text.toPlainText());
        r.visitChildren(visit);
      }

      visit(child);
      final t = _oneLine(texts.join(' / '), 50);
      add(LayoutIssue('squeezed',
          '"$t" scaled to ${(scale * 100).round()}%', _locOfElement(e)));
    }
  }

  if (tapTargets) {
    final owner = tester.binding.renderViews.first.owner!;
    void walk(SemanticsNode n, Matrix4 parentTransform) {
      final m = n.transform == null
          ? parentTransform
          : (parentTransform.clone()..multiply(n.transform!));
      final rect = MatrixUtils.transformRect(m, n.rect);
      final data = n.getSemanticsData();
      final tappable = data.hasAction(SemanticsAction.tap) ||
          data.hasAction(SemanticsAction.longPress);
      if (tappable && !n.isInvisible && !data.flagsCollection.isHidden) {
        final label = _oneLine(
            data.label.isNotEmpty ? data.label : (data.tooltip.isNotEmpty ? data.tooltip : '(no label)'),
            40);
        // rect is in physical pixels; convert to logical.
        final dpr = tester.view.devicePixelRatio;
        final r = Rect.fromLTRB(rect.left / dpr, rect.top / dpr,
            rect.right / dpr, rect.bottom / dpr);
        // Small in both directions, or a thin strip. A wide row that is only
        // short because a scroll view clips it is not reported.
        final small = (r.width < 36 && r.height < 36) ||
            (r.height < 30 && r.width < 120) ||
            (r.width < 30 && r.height < 120);
        if (small && r.width > 0 && r.height > 0) {
          add(LayoutIssue('tap',
              '"$label" ${r.width.toStringAsFixed(0)}x${r.height.toStringAsFixed(0)}'));
        }
        final scr = Offset.zero & screen;
        if (r.width > 0 && r.height > 0 && !scr.overlaps(r)) {
          // Off screen: normally just scrolled away, so not an issue.
        } else if (r.right > screen.width + 1 || r.left < -1) {
          add(LayoutIssue('tap', '"$label" sticks out horizontally ($r)'));
        }
      }
      n.visitChildren((c) {
        walk(c, m);
        return true;
      });
    }

    final root = owner.semanticsOwner?.rootSemanticsNode;
    if (root != null) walk(root, Matrix4.identity());
  }
  return out;
}

void reportLayout(
    String target, LayoutCfg cfg, String locale, List<LayoutIssue> issues) {
  final lines = <String>[];
  if (issues.isEmpty) {
    lines.add('LAYOUT|$target|${cfg.name}|$locale|OK||');
  } else {
    for (final i in issues) {
      lines.add('LAYOUT|$target|${cfg.name}|$locale|${i.kind}|${i.detail}|${i.location}');
    }
  }
  for (final l in lines) {
    // ignore: avoid_print
    print(l);
  }
  final path = Platform.environment['LAYOUT_REPORT'];
  if (path != null && path.isNotEmpty) {
    File(path).writeAsStringSync('${lines.join('\n')}\n',
        mode: FileMode.append, flush: true);
  }
}

/// Pump [build] at [cfg]/[locale], run [interact] (optional: open a sheet,
/// scroll...), scan, report, and return the issues. Never fails the test on
/// a layout issue.
Future<List<LayoutIssue>> surveyLayout(
  WidgetTester tester, {
  required String target,
  required LayoutCfg cfg,
  required String locale,
  required Widget Function() build,
  Future<void> Function(WidgetTester tester)? interact,
  List<Duration> pumps = const [
    Duration.zero,
    Duration(milliseconds: 100),
    Duration(milliseconds: 500),
    Duration(seconds: 1),
  ],
  bool wrapApp = true,
  bool tapTargets = true,
  bool emitReport = true,
  String? probe,
  bool scanAfter = true,
}) async {
  await loadLayoutFonts();
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = Size(cfg.size.width * 2, cfg.size.height * 2);
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
  Product.useLaoNames = locale == 'lo';
  final semantics = tapTargets ? tester.ensureSemantics() : null;

  final issues = <LayoutIssue>[];
  final orig = FlutterError.onError;
  FlutterError.onError = (d) => issues.add(issueFromDetails(d));
  try {
    final child = build();
    await tester.pumpWidget(wrapApp
        ? layoutApp(locale: locale, textScale: cfg.textScale, home: child)
        : child);
    for (final d in pumps) {
      await tester.pump(d);
    }
    if (probe != null &&
        find.textContaining(probe, findRichText: true).evaluate().isEmpty) {
      issues.add(LayoutIssue('no-data', 'fixture text "$probe" not on screen'));
    }
    if (interact != null) await interact(tester);
    if (scanAfter) {
      issues.addAll(scanTree(tester, cfg.size, tapTargets: tapTargets));
    }
  } catch (e) {
    issues.add(LayoutIssue('could-not-test', _oneLine(e.toString())));
  } finally {
    FlutterError.onError = orig;
  }
  final ex = tester.takeException();
  if (ex != null) {
    issues.add(LayoutIssue('exception', _oneLine(ex.toString())));
  }
  // Tear the tree down so timers in State.dispose are cancelled.
  final orig2 = FlutterError.onError;
  FlutterError.onError = (_) {};
  try {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  } catch (_) {
  } finally {
    FlutterError.onError = orig2;
  }
  tester.takeException();
  semantics?.dispose();
  Product.useLaoNames = false;
  if (emitReport) reportLayout(target, cfg, locale, issues);
  return issues;
}

void main() {
  testWidgets('harness catches a deliberate overflow', (tester) async {
    final issues = await surveyLayout(
      tester,
      target: 'harness-self-test',
      cfg: layoutConfigs.first,
      locale: 'en',
      emitReport: false,
      build: () => const Scaffold(
        body: Row(children: [SizedBox(width: 400, height: 10)]),
      ),
    );
    expect(issues.where((i) => i.kind == 'overflow'), isNotEmpty,
        reason: issues.join('\n'));
    expect(issues.first.detail, contains('80 pixels'));
    expect(issues.first.location, contains('screen_size_harness_test.dart'));
  });

  testWidgets('harness flags a 20x20 tap target', (tester) async {
    final issues = await surveyLayout(
      tester,
      target: 'harness-self-test',
      cfg: layoutConfigs.first,
      locale: 'en',
      emitReport: false,
      build: () => Scaffold(
        body: Center(
          child: Semantics(
            label: 'tiny',
            button: true,
            onTap: () {},
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
      ),
    );
    expect(issues.where((i) => i.kind == 'tap' && i.detail.contains('20x20')),
        isNotEmpty,
        reason: issues.join('\n'));
  });
}
