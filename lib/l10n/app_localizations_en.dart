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

  @override
  String get deviceIphone => 'iPhone / iPad';

  @override
  String get deviceAndroid => 'Android device';

  @override
  String get alreadySignedIn => 'Already signed in';

  @override
  String get accountActiveOtherDevice =>
      'Your account is currently active on another device.';

  @override
  String deviceIdLabel(String maskedId) {
    return 'ID: $maskedId';
  }

  @override
  String get continueSignsOutOther => 'Continuing will sign out that device.';

  @override
  String get cancel => 'Cancel';

  @override
  String get continueLabel => 'Continue';

  @override
  String get unknownRoleFromServer => 'Unknown role from server';

  @override
  String get googleMissingEmail =>
      'Google account is missing email information.';

  @override
  String googleLoginFailed(String error) {
    return 'Google Login Failed: $error';
  }

  @override
  String get pleaseEnterLogin => 'Please enter login';

  @override
  String get pleaseEnterPassword => 'Please enter password';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get registerStaffAccount => 'Register Staff Account';

  @override
  String get failedToSendOtp => 'Failed to send OTP';

  @override
  String failedToSendOtpError(String error) {
    return 'Failed to send OTP: $error';
  }

  @override
  String tooManyOtpRequests(String time) {
    return 'Too many OTP requests. Please wait $time before resending.';
  }

  @override
  String get otpVerification => 'OTP Verification';

  @override
  String otpSentTo(String phone) {
    return 'We have sent a 6-digit OTP to your phone number:\n+856 $phone';
  }

  @override
  String get pleaseEnterSixDigitCode => 'Please enter a 6-digit code';

  @override
  String get registrationSuccessful => 'Registration successful';

  @override
  String registrationFailed(String error) {
    return 'Registration Failed: $error';
  }

  @override
  String get verifyAndRegister => 'VERIFY & REGISTER';

  @override
  String get otpResentSuccessfully => 'OTP code resent successfully!';

  @override
  String get resendCode => 'Resend Code';

  @override
  String get selectBranchBeforeGoogle =>
      'Please select a branch before Google registration';

  @override
  String googleRegistrationFailed(String error) {
    return 'Google Registration Failed: $error';
  }

  @override
  String get createAccountTitle => 'Create Account';

  @override
  String get joinLaDolce => 'Join LaDolce and start ordering';

  @override
  String get fullName => 'Full Name';

  @override
  String get pleaseEnterName => 'Please enter name';

  @override
  String get phoneRequiredCustomers => 'Phone Number (Required for Customers)';

  @override
  String get phoneOptional => 'Phone Number (Optional)';

  @override
  String get phoneRequiredForCustomers =>
      'Phone number is required for customers';

  @override
  String get phoneMustBe10Digits => 'Phone must be 10 digits starting with 20';

  @override
  String get pleaseEnterLoginEmail => 'Please enter login/email';

  @override
  String get role => 'Role';

  @override
  String get roleCustomer => 'Customer';

  @override
  String get roleCashier => 'Cashier';

  @override
  String get roleRider => 'Rider';

  @override
  String get branch => 'Branch';

  @override
  String get selectBranchHint => 'Select branch';

  @override
  String get pleaseSelectBranch => 'Please select a branch';

  @override
  String get agreeToTerms => 'I agree to the Terms of Service and ';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get registerButton => 'REGISTER';

  @override
  String get language => 'Language';
}
