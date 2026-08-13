// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get emailOrLogin => 'Email / Login';

  @override
  String get password => 'Password';

  @override
  String get loginButton => 'LOGIN';

  @override
  String get createAccount => 'Create a new account';

  @override
  String get choosePaymentMethod => 'Choose Payment Method';

  @override
  String get selectBranch => 'Select Branch';

  @override
  String get noBranchesFound => 'No branches found. Please ask staff.';

  @override
  String get selectBank => 'Select Bank';

  @override
  String get scanQrCode => 'Scan QR Code';

  @override
  String get qrNotConfigured => 'QR not configured in Odoo Settings';

  @override
  String get downloadQr => 'Download QR';

  @override
  String get uploadTransferProof => 'Upload Transfer Proof';

  @override
  String get proofSelected => 'Proof Selected';

  @override
  String get transferProofSelectedMsg =>
      'Transfer proof selected. It will be uploaded when you confirm order.';

  @override
  String get confirmOrder => 'Confirm Order';

  @override
  String get runOut => 'Run out';

  @override
  String get orderNote => 'Order Note / Pickup Time';

  @override
  String get orderNoteHint => 'e.g., Pickup at 3:00 PM, extra spicy, etc.';

  @override
  String get weatherWarning =>
      'Due to bad weather, your delivery or rider may be delayed.';
}
