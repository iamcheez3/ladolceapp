import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_lo.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('lo'),
  ];

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @emailOrLogin.
  ///
  /// In en, this message translates to:
  /// **'Email / Login'**
  String get emailOrLogin;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'LOGIN'**
  String get loginButton;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create a new account'**
  String get createAccount;

  /// No description provided for @choosePaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Choose Payment Method'**
  String get choosePaymentMethod;

  /// No description provided for @selectBranch.
  ///
  /// In en, this message translates to:
  /// **'Select Branch'**
  String get selectBranch;

  /// No description provided for @noBranchesFound.
  ///
  /// In en, this message translates to:
  /// **'No branches found. Please ask staff.'**
  String get noBranchesFound;

  /// No description provided for @selectBank.
  ///
  /// In en, this message translates to:
  /// **'Select Bank'**
  String get selectBank;

  /// No description provided for @scanQrCode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQrCode;

  /// No description provided for @qrNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'QR not configured in Odoo Settings'**
  String get qrNotConfigured;

  /// No description provided for @downloadQr.
  ///
  /// In en, this message translates to:
  /// **'Download QR'**
  String get downloadQr;

  /// No description provided for @uploadTransferProof.
  ///
  /// In en, this message translates to:
  /// **'Upload Transfer Proof'**
  String get uploadTransferProof;

  /// No description provided for @proofSelected.
  ///
  /// In en, this message translates to:
  /// **'Proof Selected'**
  String get proofSelected;

  /// No description provided for @transferProofSelectedMsg.
  ///
  /// In en, this message translates to:
  /// **'Transfer proof selected. It will be uploaded when you confirm order.'**
  String get transferProofSelectedMsg;

  /// No description provided for @confirmOrder.
  ///
  /// In en, this message translates to:
  /// **'Confirm Order'**
  String get confirmOrder;

  /// No description provided for @runOut.
  ///
  /// In en, this message translates to:
  /// **'Run out'**
  String get runOut;

  /// No description provided for @orderNote.
  ///
  /// In en, this message translates to:
  /// **'Order Note / Pickup Time'**
  String get orderNote;

  /// No description provided for @orderNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Pickup at 3:00 PM, extra spicy, etc.'**
  String get orderNoteHint;

  /// No description provided for @weatherWarning.
  ///
  /// In en, this message translates to:
  /// **'Due to bad weather, your delivery or rider may be delayed.'**
  String get weatherWarning;

  /// No description provided for @deviceIphone.
  ///
  /// In en, this message translates to:
  /// **'iPhone / iPad'**
  String get deviceIphone;

  /// No description provided for @deviceAndroid.
  ///
  /// In en, this message translates to:
  /// **'Android device'**
  String get deviceAndroid;

  /// No description provided for @alreadySignedIn.
  ///
  /// In en, this message translates to:
  /// **'Already signed in'**
  String get alreadySignedIn;

  /// No description provided for @accountActiveOtherDevice.
  ///
  /// In en, this message translates to:
  /// **'Your account is currently active on another device.'**
  String get accountActiveOtherDevice;

  /// No description provided for @deviceIdLabel.
  ///
  /// In en, this message translates to:
  /// **'ID: {maskedId}'**
  String deviceIdLabel(String maskedId);

  /// No description provided for @continueSignsOutOther.
  ///
  /// In en, this message translates to:
  /// **'Continuing will sign out that device.'**
  String get continueSignsOutOther;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @unknownRoleFromServer.
  ///
  /// In en, this message translates to:
  /// **'Unknown role from server'**
  String get unknownRoleFromServer;

  /// No description provided for @googleMissingEmail.
  ///
  /// In en, this message translates to:
  /// **'Google account is missing email information.'**
  String get googleMissingEmail;

  /// No description provided for @googleLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Google Login Failed: {error}'**
  String googleLoginFailed(String error);

  /// No description provided for @pleaseEnterLogin.
  ///
  /// In en, this message translates to:
  /// **'Please enter login'**
  String get pleaseEnterLogin;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter password'**
  String get pleaseEnterPassword;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @registerStaffAccount.
  ///
  /// In en, this message translates to:
  /// **'Register Staff Account'**
  String get registerStaffAccount;

  /// No description provided for @failedToSendOtp.
  ///
  /// In en, this message translates to:
  /// **'Failed to send OTP'**
  String get failedToSendOtp;

  /// No description provided for @failedToSendOtpError.
  ///
  /// In en, this message translates to:
  /// **'Failed to send OTP: {error}'**
  String failedToSendOtpError(String error);

  /// No description provided for @tooManyOtpRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many OTP requests. Please wait {time} before resending.'**
  String tooManyOtpRequests(String time);

  /// No description provided for @otpVerification.
  ///
  /// In en, this message translates to:
  /// **'OTP Verification'**
  String get otpVerification;

  /// No description provided for @otpSentTo.
  ///
  /// In en, this message translates to:
  /// **'We have sent a 6-digit OTP to your phone number:\n+856 {phone}'**
  String otpSentTo(String phone);

  /// No description provided for @pleaseEnterSixDigitCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter a 6-digit code'**
  String get pleaseEnterSixDigitCode;

  /// No description provided for @registrationSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Registration successful'**
  String get registrationSuccessful;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration Failed: {error}'**
  String registrationFailed(String error);

  /// No description provided for @verifyAndRegister.
  ///
  /// In en, this message translates to:
  /// **'VERIFY & REGISTER'**
  String get verifyAndRegister;

  /// No description provided for @otpResentSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'OTP code resent successfully!'**
  String get otpResentSuccessfully;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// No description provided for @selectBranchBeforeGoogle.
  ///
  /// In en, this message translates to:
  /// **'Please select a branch before Google registration'**
  String get selectBranchBeforeGoogle;

  /// No description provided for @googleRegistrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Google Registration Failed: {error}'**
  String googleRegistrationFailed(String error);

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccountTitle;

  /// No description provided for @joinLaDolce.
  ///
  /// In en, this message translates to:
  /// **'Join LaDolce and start ordering'**
  String get joinLaDolce;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @pleaseEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter name'**
  String get pleaseEnterName;

  /// No description provided for @phoneRequiredCustomers.
  ///
  /// In en, this message translates to:
  /// **'Phone Number (Required for Customers)'**
  String get phoneRequiredCustomers;

  /// No description provided for @phoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone Number (Optional)'**
  String get phoneOptional;

  /// No description provided for @phoneRequiredForCustomers.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required for customers'**
  String get phoneRequiredForCustomers;

  /// No description provided for @phoneMustBe10Digits.
  ///
  /// In en, this message translates to:
  /// **'Phone must be 10 digits starting with 20'**
  String get phoneMustBe10Digits;

  /// No description provided for @pleaseEnterLoginEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter login/email'**
  String get pleaseEnterLoginEmail;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @roleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get roleCustomer;

  /// No description provided for @roleCashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get roleCashier;

  /// No description provided for @roleRider.
  ///
  /// In en, this message translates to:
  /// **'Rider'**
  String get roleRider;

  /// No description provided for @branch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get branch;

  /// No description provided for @selectBranchHint.
  ///
  /// In en, this message translates to:
  /// **'Select branch'**
  String get selectBranchHint;

  /// No description provided for @pleaseSelectBranch.
  ///
  /// In en, this message translates to:
  /// **'Please select a branch'**
  String get pleaseSelectBranch;

  /// No description provided for @agreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms of Service and '**
  String get agreeToTerms;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'REGISTER'**
  String get registerButton;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'lo'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'lo':
      return AppLocalizationsLo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
