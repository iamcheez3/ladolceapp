import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import 'package:ladolce/widgets/dispose_with.dart';
import 'package:ladolce/widgets/ticket_name_dialog.dart';

class _TrackedController extends TextEditingController {
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

/// A screen with one button that opens [open] and keeps what it returns.
Future<void> _pumpHost(
  WidgetTester tester,
  Future<Object?> Function(BuildContext) open,
  void Function(Object?) onResult,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => onResult(await open(context)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('ticket name dialog', () {
    Future<Object?> open(BuildContext c) =>
        showTicketNameDialog(c, title: 'Custom name', help: 'Save it.');

    testWidgets('Cancel closes cleanly and returns null', (tester) async {
      Object? result = 'unset';
      await _pumpHost(tester, open, (r) => result = r);
      await tester.enterText(find.byType(TextField), 'Noy');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TicketNameDialog), findsNothing);
      expect(result, isNull);
    });

    testWidgets('Save returns the trimmed name', (tester) async {
      Object? result;
      await _pumpHost(tester, open, (r) => result = r);
      await tester.enterText(find.byType(TextField), '  Table Noy  ');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(result, 'Table Noy');
    });

    testWidgets('Save is off until a name is typed', (tester) async {
      await _pumpHost(tester, open, (_) {});
      ElevatedButton save() =>
          tester.widget(find.widgetWithText(ElevatedButton, 'Save'));
      expect(save().onPressed, isNull);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(save().onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'A');
      await tester.pump();
      expect(save().onPressed, isNotNull);
    });
  });

  testWidgets('DisposeWith disposes an inline dialog field after it closes', (
    tester,
  ) async {
    final controller = _TrackedController();
    await _pumpHost(
      tester,
      (c) => showDialog<void>(
        context: c,
        builder: (ctx) => DisposeWith(
          onDispose: controller.dispose,
          child: AlertDialog(
            content: TextField(controller: controller, autofocus: true),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
      (_) {},
    );
    await tester.tap(find.text('Close'));
    await tester.pump();
    // Still closing: the field is on screen and the controller is alive.
    expect(controller.disposed, isFalse);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(controller.disposed, isTrue);
  });
}
