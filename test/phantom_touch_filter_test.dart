import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladolce/utils/phantom_touch_filter.dart';

void main() {
  test('a touch at (0, 0) is dropped from down to up', () {
    final f = PhantomTouchFilter();
    expect(f.shouldDrop(const PointerDownEvent(pointer: 7)), isTrue);
    expect(f.shouldDrop(const PointerMoveEvent(pointer: 7)), isTrue);
    expect(f.shouldDrop(const PointerUpEvent(pointer: 7)), isTrue);
    // The pointer is forgotten once it is lifted.
    expect(
      f.shouldDrop(const PointerUpEvent(pointer: 7, position: Offset(5, 5))),
      isFalse,
    );
  });

  test('real touches pass, including ones near the corner', () {
    final f = PhantomTouchFilter();
    for (final at in const [Offset(1344, 63), Offset(1, 0), Offset(12, 30)]) {
      expect(f.shouldDrop(PointerDownEvent(pointer: 1, position: at)), isFalse);
      expect(f.shouldDrop(PointerUpEvent(pointer: 1, position: at)), isFalse);
    }
  });

  test('a cancelled phantom touch is forgotten', () {
    final f = PhantomTouchFilter();
    expect(f.shouldDrop(const PointerDownEvent(pointer: 3)), isTrue);
    expect(f.shouldDrop(const PointerCancelEvent(pointer: 3)), isTrue);
    expect(
      f.shouldDrop(
        const PointerDownEvent(pointer: 3, position: Offset(50, 50)),
      ),
      isFalse,
    );
  });

  test('a mouse click at (0, 0) is left alone', () {
    final f = PhantomTouchFilter();
    expect(
      f.shouldDrop(const PointerDownEvent(kind: PointerDeviceKind.mouse)),
      isFalse,
    );
  });
}
