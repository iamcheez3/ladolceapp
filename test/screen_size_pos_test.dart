// Layout survey of the POS screen and its sheets at many screen sizes:
//   pos_screen/main          catalog (+ inline cart rail at width >= 800)
//   pos_screen/topping_sheet the "Select toppings" bottom sheet
//   pos_screen/cart          inline rail, or the phone cart sheet
//   pos_screen/charge        the charge (payment) sheet
//   pos_screen/charge_split  the charge sheet in split-payment mode
// Fake backend + caches come from screen_size_screens_test.dart.
// Never fails on a layout issue; read the "LAYOUT|" lines.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ladolce/l10n/app_localizations.dart';
import 'package:ladolce/screens/pos_screen.dart';
import 'package:ladolce/widgets/topping_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screen_size_harness_test.dart';
import 'screen_size_screens_test.dart' as fx;

/// Products 2 (Latte) and 4 (Croissant) have no toppings so a tap adds them
/// straight to the cart.
List<Map<String, dynamic>> posProducts() => [
      for (final p in fx.fxProducts)
        {
          ...p,
          if (p['id'] == 2 || p['id'] == 4) 'toppings': <dynamic>[],
        },
    ];

Future<void> seedPosPrefs() async {
  SharedPreferences.setMockInitialValues({
    'cached_user_data': jsonEncode(fx.cachedUser),
    'cached_user_session': 'test-session',
    'cached_products': jsonEncode(posProducts()),
    'cached_toppings': jsonEncode(fx.fxToppings),
    'cached_categories': jsonEncode(fx.fxCategories),
    'cached_payment_methods': jsonEncode([
      {'id': 1, 'name': 'Cash', 'open_cash_drawer': true},
      {'id': 2, 'name': 'BCEL OnePay QR (Bank transfer)'},
      {'id': 3, 'name': 'ເງິນໂອນ ທະນາຄານການຄ້າຕ່າງປະເທດລາວ'},
    ]),
  });
}

/// Runs [action], then scans and reports the tree as pos_screen/[name].
/// Returns false when the stage could not be reached. Scan findings already
/// reported by an earlier stage of the same run (the catalog still visible
/// behind a sheet) are left out via [seen].
Future<bool> stage(WidgetTester t, String name, LayoutCfg cfg, String loc,
    Set<String> seen, Future<void> Function() action) async {
  final issues = <LayoutIssue>[];
  final prev = FlutterError.onError;
  FlutterError.onError = (d) => issues.add(issueFromDetails(d));
  var ok = true;
  try {
    await action();
    for (final i in scanTree(t, cfg.size)) {
      final key = '${i.kind}|${i.detail.replaceAll(RegExp(r' \(w=\d+\)'), '')}|${i.location}';
      if (seen.add(key)) issues.add(i);
    }
  } catch (e) {
    ok = false;
    final msg = e.toString().replaceAll(RegExp(r'\s+'), ' ');
    issues.add(LayoutIssue(
        'could-not-test', msg.length > 300 ? msg.substring(0, 300) : msg));
  } finally {
    FlutterError.onError = prev;
  }
  final ex = t.takeException();
  if (ex != null) issues.add(LayoutIssue('exception', '$ex'.split('\n').first));
  reportLayout('pos_screen/$name', cfg, loc, issues);
  return ok;
}

Future<void> settle(WidgetTester t) async {
  for (final d in const [
    Duration(milliseconds: 50),
    Duration(milliseconds: 300),
    Duration(milliseconds: 500),
  ]) {
    await t.pump(d);
  }
}

Future<void> tapText(WidgetTester t, String text) async {
  final f = find.text(text, findRichText: true);
  if (f.evaluate().isEmpty) throw StateError('"$text" not found');
  await t.ensureVisible(f.first);
  await t.pump();
  await t.tap(f.first);
  await settle(t);
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(
        envString: 'API_KEY=x\nAPI_BASE_URL=http://127.0.0.1:1/api\nAPI_DB=x');
  });

  for (final cfg in layoutConfigs) {
    for (final loc in layoutLocales) {
      testWidgets('pos_screen ${cfg.name} $loc', (t) async {
        await seedPosPrefs();
        final l10n = lookupAppLocalizations(Locale(loc));
        final latte = loc == 'lo' ? 'ລາເຕ້' : 'Latte';
        final croissant = loc == 'lo' ? 'ຄົວຊອງ' : 'Croissant';
        final longName = loc == 'lo' ? fx.longLo : fx.longEn;

        await http.runWithClient(
          () => surveyLayout(
            t,
            target: 'pos_screen/boot',
            cfg: cfg,
            locale: loc,
            scanAfter: false,
            tapTargets: true,
            emitReport: true, // errors outside the stages
            build: () => const PosScreen(
                cashierName: 'Khamphoui Sengdara Phommavong (Senior Cashier)'),
            pumps: const [
              Duration.zero,
              Duration(milliseconds: 300),
              Duration(seconds: 1),
              Duration(seconds: 4), // past the 3 s app-update check
            ],
            interact: (t) async {
              final seen = <String>{};
              await stage(t, 'main', cfg, loc, seen, () async {
                if (find.text(latte).evaluate().isEmpty) {
                  throw StateError('catalog did not load');
                }
              });

              await stage(t, 'topping_sheet', cfg, loc, seen, () async {
                await tapText(t, longName);
                if (find.byType(ToppingPicker).evaluate().isEmpty) {
                  throw StateError('topping sheet did not open');
                }
              });
              // Add it with its defaults, so the cart has a topping line.
              final add = find.text(l10n.addToOrder);
              if (add.evaluate().isNotEmpty) {
                await t.ensureVisible(add.first);
                await t.tap(add.first, warnIfMissed: false);
                await settle(t);
              }
              if (find.byType(ToppingPicker).evaluate().isNotEmpty) {
                Navigator.of(t.element(find.byType(ToppingPicker)))
                    .popUntil((r) => r.isFirst);
                await settle(t);
              }

              await t.pump(const Duration(seconds: 1));
              for (var i = 0; i < 3; i++) {
                try {
                  await tapText(t, latte);
                } catch (_) {}
              }
              try {
                await tapText(t, croissant);
              } catch (_) {}

              final reached = await stage(t, 'cart', cfg, loc, seen, () async {
                if (cfg.size.width < 800) {
                  await tapText(t, l10n.currentTicket);
                }
                if (find.text(l10n.charge2).evaluate().isEmpty) {
                  throw StateError('cart not shown; texts: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().take(40).join(" | ")}');
                }
              });
              if (!reached) return;

              final charged = await stage(t, 'charge', cfg, loc, seen, () async {
                await tapText(t, l10n.charge2);
                if (find.text(l10n.splitPayment).evaluate().isEmpty) {
                  throw StateError('charge sheet did not open');
                }
              });
              if (!charged) return;

              await stage(t, 'charge_split', cfg, loc, seen, () async {
                await tapText(t, l10n.splitPayment);
              });
            },
          ),
          () => fx.fakeBackend(posProducts()),
        );
      });
    }
  }
}
