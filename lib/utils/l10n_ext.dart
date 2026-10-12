import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

/// Shorthand for the generated localisations.
///
/// `AppLocalizations.of(context)` is nullable only because the delegate could
/// be missing; it is registered in `main.dart` for the whole app, so every
/// widget below `MaterialApp` has one. Reading it through `context.l10n` keeps
/// call sites short enough to sit inline in a widget tree.
extension L10nExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
