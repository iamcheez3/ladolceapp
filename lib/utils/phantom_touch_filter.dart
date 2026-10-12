import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Recognises the phantom touch iPadOS sends to the screen's top-left corner.
///
/// Right after a popup menu opens on iPad, a touch at exactly (0, 0) often
/// arrives that nobody made. It lands on the menu's barrier and closes the
/// menu at once (POS "..." menu). That point is under the status bar, so no
/// real tap is lost by ignoring touches that start there.
class PhantomTouchFilter {
  final Set<int> _ignored = {};

  /// Whether [event] belongs to a phantom touch and should be dropped.
  bool shouldDrop(PointerEvent event) {
    if (event.kind != PointerDeviceKind.touch) return false;
    if (event is PointerDownEvent) {
      if (event.position.distance >= 1) return false;
      _ignored.add(event.pointer);
      return true;
    }
    if (!_ignored.contains(event.pointer)) return false;
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _ignored.remove(event.pointer);
    }
    return true;
  }
}

/// The app's binding: [WidgetsFlutterBinding] with [PhantomTouchFilter] on
/// iOS.
class PosAppBinding extends WidgetsFlutterBinding {
  PosAppBinding._();

  static bool _created = false;

  /// Use in place of `WidgetsFlutterBinding.ensureInitialized()`, first thing
  /// in `main`.
  static void ensureInitialized() {
    if (_created) return;
    _created = true;
    PosAppBinding._();
  }

  final PhantomTouchFilter _filter = PhantomTouchFilter();

  @override
  void handlePointerEvent(PointerEvent event) {
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        _filter.shouldDrop(event)) {
      return;
    }
    super.handlePointerEvent(event);
  }
}
