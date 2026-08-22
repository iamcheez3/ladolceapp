import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the self-order coupon field.
///
/// The remove-X sits in the field's `suffixIcon`. When the field used
/// `enabled: false` while a coupon was applied, TextField wrapped itself — and
/// its decoration — in an IgnorePointer, so the X rendered but never received
/// the tap and customers could not clear a coupon. `readOnly: true` locks
/// editing while leaving the icon interactive.
void main() {
  Widget host({
    required bool useEnabledFalse,
    required VoidCallback onRemove,
    required TextEditingController controller,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: TextField(
          controller: controller,
          enabled: useEnabledFalse ? false : true,
          readOnly: useEnabledFalse ? false : true,
          decoration: InputDecoration(
            suffixIcon: IconButton(
              icon: const Icon(Icons.close),
              onPressed: onRemove,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('enabled:false swallows the suffixIcon tap (the original bug)', (
    tester,
  ) async {
    var removed = 0;
    final controller = TextEditingController(text: 'SAVE10');
    await tester.pumpWidget(
      host(
        useEnabledFalse: true,
        onRemove: () => removed++,
        controller: controller,
      ),
    );

    await tester.tap(find.byIcon(Icons.close), warnIfMissed: false);
    await tester.pump();

    expect(
      removed,
      0,
      reason: 'documents why enabled:false could not be used here',
    );
  });

  testWidgets('readOnly:true keeps the remove button tappable', (tester) async {
    var removed = 0;
    final controller = TextEditingController(text: 'SAVE10');
    await tester.pumpWidget(
      host(
        useEnabledFalse: false,
        onRemove: () => removed++,
        controller: controller,
      ),
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(removed, 1, reason: 'customer must be able to clear the coupon');
  });

  testWidgets('readOnly:true still blocks editing the applied code', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'SAVE10');
    await tester.pumpWidget(
      host(useEnabledFalse: false, onRemove: () {}, controller: controller),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'HACKED');
    await tester.pump();

    expect(
      controller.text,
      'SAVE10',
      reason: 'an applied coupon code must not be editable in place',
    );
  });
}
