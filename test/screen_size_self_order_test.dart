// Layout survey of the customer self-order screen (customer app) at many
// screen sizes, against the fake backend in screen_size_screens_test.dart.
// Never fails on a layout issue; read the "LAYOUT|" lines.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ladolce/models/product.dart';
import 'package:ladolce/screens/customer_self_order_screen.dart';

import 'screen_size_harness_test.dart';
import 'screen_size_screens_test.dart' as fx;

void main() {
  setUpAll(() {
    dotenv.loadFromString(
        envString: 'API_KEY=x\nAPI_BASE_URL=http://127.0.0.1:1/api\nAPI_DB=x');
  });
  tearDown(() => Product.isCustomerMode = false);

  for (final cfg in layoutConfigs) {
    for (final loc in layoutLocales) {
      for (final scrolled in [false, true]) {
        testWidgets(
            'customer_self_order_screen${scrolled ? ' (scrolled)' : ''} ${cfg.name} $loc',
            (t) async {
          await fx.seedPrefs();
          await http.runWithClient(
            () => surveyLayout(t,
                target: 'customer_self_order_screen${scrolled ? '/scrolled' : ''}',
                cfg: cfg,
                locale: loc,
                tapTargets: !scrolled,
                probe: '35,000',
                build: () => const CustomerSelfOrderScreen(
                      customerName: 'Souksavanh Phommachanh Vongsakda',
                      userId: 9,
                      partnerId: 7,
                    ),
                pumps: const [
                  Duration.zero,
                  Duration(milliseconds: 300),
                  Duration(seconds: 1),
                  Duration(seconds: 3),
                ],
                interact: scrolled ? fx.scrollAll : null),
            fx.fakeBackend,
          );
        });
      }
    }
  }
}
