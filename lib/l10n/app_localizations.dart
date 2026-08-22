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

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorWithMessage(String error);

  /// No description provided for @featureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Feature coming soon!'**
  String get featureComingSoon;

  /// No description provided for @allItems.
  ///
  /// In en, this message translates to:
  /// **'All Items'**
  String get allItems;

  /// No description provided for @combos.
  ///
  /// In en, this message translates to:
  /// **'Combos'**
  String get combos;

  /// No description provided for @searchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get searchProducts;

  /// No description provided for @noProductsMatching.
  ///
  /// In en, this message translates to:
  /// **'No products matching \"{query}\"'**
  String noProductsMatching(String query);

  /// No description provided for @noProductsInCategory.
  ///
  /// In en, this message translates to:
  /// **'No products in this category'**
  String get noProductsInCategory;

  /// No description provided for @applyDiscount.
  ///
  /// In en, this message translates to:
  /// **'Apply Discount'**
  String get applyDiscount;

  /// No description provided for @selectDiscountOption.
  ///
  /// In en, this message translates to:
  /// **'Select Discount Option'**
  String get selectDiscountOption;

  /// No description provided for @selectDiscount.
  ///
  /// In en, this message translates to:
  /// **'Select Discount'**
  String get selectDiscount;

  /// No description provided for @noDiscount.
  ///
  /// In en, this message translates to:
  /// **'No Discount'**
  String get noDiscount;

  /// No description provided for @customPercent.
  ///
  /// In en, this message translates to:
  /// **'(Custom %)'**
  String get customPercent;

  /// No description provided for @customAmount.
  ///
  /// In en, this message translates to:
  /// **'(Custom Amount)'**
  String get customAmount;

  /// No description provided for @enterDiscountPercentage.
  ///
  /// In en, this message translates to:
  /// **'Enter Discount Percentage'**
  String get enterDiscountPercentage;

  /// No description provided for @enterDiscountAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter Discount Amount'**
  String get enterDiscountAmount;

  /// No description provided for @removeDiscount.
  ///
  /// In en, this message translates to:
  /// **'Remove Discount'**
  String get removeDiscount;

  /// No description provided for @discountValueOption.
  ///
  /// In en, this message translates to:
  /// **'Discount (Value)'**
  String get discountValueOption;

  /// No description provided for @percentOff.
  ///
  /// In en, this message translates to:
  /// **'{percent}% Off'**
  String percentOff(String percent);

  /// No description provided for @egTen.
  ///
  /// In en, this message translates to:
  /// **'e.g. 10'**
  String get egTen;

  /// No description provided for @egFiveThousand.
  ///
  /// In en, this message translates to:
  /// **'e.g. 5000'**
  String get egFiveThousand;

  /// No description provided for @kitchenNote.
  ///
  /// In en, this message translates to:
  /// **'Kitchen note'**
  String get kitchenNote;

  /// No description provided for @kitchenNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Less sugar, no ice, extra spicy...'**
  String get kitchenNoteHint;

  /// No description provided for @selectToppingsFor.
  ///
  /// In en, this message translates to:
  /// **'Select Toppings for {product}'**
  String selectToppingsFor(String product);

  /// No description provided for @addWithoutToppings.
  ///
  /// In en, this message translates to:
  /// **'Add Without Toppings'**
  String get addWithoutToppings;

  /// No description provided for @addToOrder.
  ///
  /// In en, this message translates to:
  /// **'Add To Order'**
  String get addToOrder;

  /// No description provided for @tickets.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get tickets;

  /// No description provided for @openTickets.
  ///
  /// In en, this message translates to:
  /// **'Open Tickets'**
  String get openTickets;

  /// No description provided for @ticketLabel.
  ///
  /// In en, this message translates to:
  /// **'Ticket'**
  String get ticketLabel;

  /// No description provided for @ticketOptions.
  ///
  /// In en, this message translates to:
  /// **'Ticket Options'**
  String get ticketOptions;

  /// No description provided for @clearTicket.
  ///
  /// In en, this message translates to:
  /// **'Clear ticket'**
  String get clearTicket;

  /// No description provided for @printBill.
  ///
  /// In en, this message translates to:
  /// **'Print bill'**
  String get printBill;

  /// No description provided for @reprintOrderKitchen.
  ///
  /// In en, this message translates to:
  /// **'Reprint order (kitchen)'**
  String get reprintOrderKitchen;

  /// No description provided for @splitTicketAction.
  ///
  /// In en, this message translates to:
  /// **'Split ticket'**
  String get splitTicketAction;

  /// No description provided for @moveTicketAction.
  ///
  /// In en, this message translates to:
  /// **'Move ticket'**
  String get moveTicketAction;

  /// No description provided for @sendToRider.
  ///
  /// In en, this message translates to:
  /// **'Send to rider'**
  String get sendToRider;

  /// No description provided for @openCashDrawer.
  ///
  /// In en, this message translates to:
  /// **'Open cash drawer'**
  String get openCashDrawer;

  /// No description provided for @syncAction.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get syncAction;

  /// No description provided for @scanVoucher.
  ///
  /// In en, this message translates to:
  /// **'Scan Voucher'**
  String get scanVoucher;

  /// No description provided for @switchToList.
  ///
  /// In en, this message translates to:
  /// **'Switch to List'**
  String get switchToList;

  /// No description provided for @switchToGrid.
  ///
  /// In en, this message translates to:
  /// **'Switch to Grid'**
  String get switchToGrid;

  /// No description provided for @ticketCleared.
  ///
  /// In en, this message translates to:
  /// **'Ticket cleared.'**
  String get ticketCleared;

  /// No description provided for @ticketRemovedByAdminPin.
  ///
  /// In en, this message translates to:
  /// **'Ticket removed by Admin PIN.'**
  String get ticketRemovedByAdminPin;

  /// No description provided for @cannotClearTicket.
  ///
  /// In en, this message translates to:
  /// **'Cannot clear ticket: {error}'**
  String cannotClearTicket(String error);

  /// No description provided for @adminPinRequired.
  ///
  /// In en, this message translates to:
  /// **'Admin PIN Required'**
  String get adminPinRequired;

  /// No description provided for @enterPinToClearTicket.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN to clear selected ticket'**
  String get enterPinToClearTicket;

  /// No description provided for @pinIsRequired.
  ///
  /// In en, this message translates to:
  /// **'PIN is required'**
  String get pinIsRequired;

  /// No description provided for @currentTicket.
  ///
  /// In en, this message translates to:
  /// **'CURRENT TICKET'**
  String get currentTicket;

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Items'**
  String itemsCount(String count);

  /// No description provided for @viewTicketCharge.
  ///
  /// In en, this message translates to:
  /// **'View Ticket &\nCharge'**
  String get viewTicketCharge;

  /// No description provided for @ticketSavedNoNewItems.
  ///
  /// In en, this message translates to:
  /// **'Ticket saved (no new items added).'**
  String get ticketSavedNoNewItems;

  /// No description provided for @ticketUpdatedWithItems.
  ///
  /// In en, this message translates to:
  /// **'Ticket {name} updated with {count} new item(s)!'**
  String ticketUpdatedWithItems(String name, String count);

  /// No description provided for @noItemsToPrint.
  ///
  /// In en, this message translates to:
  /// **'No items in the current ticket to print.'**
  String get noItemsToPrint;

  /// No description provided for @noPrinterConfiguredSettings.
  ///
  /// In en, this message translates to:
  /// **'No printer configured. Set up a printer in Settings first.'**
  String get noPrinterConfiguredSettings;

  /// No description provided for @noPrinterConfigured.
  ///
  /// In en, this message translates to:
  /// **'No printer configured. Set up a printer first.'**
  String get noPrinterConfigured;

  /// No description provided for @amountExclVat.
  ///
  /// In en, this message translates to:
  /// **'Amount (excl. VAT):'**
  String get amountExclVat;

  /// No description provided for @vatPercentLabel.
  ///
  /// In en, this message translates to:
  /// **'VAT ({percent}%):'**
  String vatPercentLabel(String percent);

  /// No description provided for @billPrinted.
  ///
  /// In en, this message translates to:
  /// **'🧾 Bill printed!'**
  String get billPrinted;

  /// No description provided for @failedToPrintBill.
  ///
  /// In en, this message translates to:
  /// **'Failed to print bill. Check printer connection.'**
  String get failedToPrintBill;

  /// No description provided for @noItemsToReprint.
  ///
  /// In en, this message translates to:
  /// **'No items in the current ticket to reprint.'**
  String get noItemsToReprint;

  /// No description provided for @orderReprinted.
  ///
  /// In en, this message translates to:
  /// **'🖨️ Order reprinted to {count} kitchen printer(s).'**
  String orderReprinted(String count);

  /// No description provided for @noPrinterForReprint.
  ///
  /// In en, this message translates to:
  /// **'No available printer could print this reprint request.'**
  String get noPrinterForReprint;

  /// No description provided for @cashDrawerOpened.
  ///
  /// In en, this message translates to:
  /// **'🗃️ Cash drawer opened!'**
  String get cashDrawerOpened;

  /// No description provided for @failedToOpenDrawer.
  ///
  /// In en, this message translates to:
  /// **'Failed to open drawer. Check printer connection.'**
  String get failedToOpenDrawer;

  /// No description provided for @noItemsToSplit.
  ///
  /// In en, this message translates to:
  /// **'No items in the current ticket to split.'**
  String get noItemsToSplit;

  /// No description provided for @saveTicketBeforeSplit.
  ///
  /// In en, this message translates to:
  /// **'Please save the ticket first before splitting.'**
  String get saveTicketBeforeSplit;

  /// No description provided for @ticketSplitCreated.
  ///
  /// In en, this message translates to:
  /// **'Ticket split! \"{name}\" created.'**
  String ticketSplitCreated(String name);

  /// No description provided for @splitError.
  ///
  /// In en, this message translates to:
  /// **'Split error: {error}'**
  String splitError(String error);

  /// No description provided for @cannotLoadOpenTickets.
  ///
  /// In en, this message translates to:
  /// **'Cannot load open tickets: {error}'**
  String cannotLoadOpenTickets(String error);

  /// No description provided for @noOpenTicketToMoveFrom.
  ///
  /// In en, this message translates to:
  /// **'No open ticket to move from.'**
  String get noOpenTicketToMoveFrom;

  /// No description provided for @noDestinationAvailable.
  ///
  /// In en, this message translates to:
  /// **'No destination available. Open another ticket or free a table.'**
  String get noDestinationAvailable;

  /// No description provided for @moveTicketTitle.
  ///
  /// In en, this message translates to:
  /// **'Move Ticket'**
  String get moveTicketTitle;

  /// No description provided for @selectSourceTicket.
  ///
  /// In en, this message translates to:
  /// **'Select source ticket'**
  String get selectSourceTicket;

  /// No description provided for @tableNumber.
  ///
  /// In en, this message translates to:
  /// **'Table {id}'**
  String tableNumber(String id);

  /// No description provided for @noTable.
  ///
  /// In en, this message translates to:
  /// **'No table'**
  String get noTable;

  /// No description provided for @moveDestination.
  ///
  /// In en, this message translates to:
  /// **'Move destination'**
  String get moveDestination;

  /// No description provided for @openTicketLabel.
  ///
  /// In en, this message translates to:
  /// **'Open ticket'**
  String get openTicketLabel;

  /// No description provided for @emptyTable.
  ///
  /// In en, this message translates to:
  /// **'Empty table'**
  String get emptyTable;

  /// No description provided for @moveNow.
  ///
  /// In en, this message translates to:
  /// **'Move Now'**
  String get moveNow;

  /// No description provided for @sourceTicketGone.
  ///
  /// In en, this message translates to:
  /// **'Source ticket no longer exists.'**
  String get sourceTicketGone;

  /// No description provided for @selectDestinationFirst.
  ///
  /// In en, this message translates to:
  /// **'Please select a destination ticket or table.'**
  String get selectDestinationFirst;

  /// No description provided for @sourceHasNoItems.
  ///
  /// In en, this message translates to:
  /// **'Source ticket has no items to move.'**
  String get sourceHasNoItems;

  /// No description provided for @destinationTicketGone.
  ///
  /// In en, this message translates to:
  /// **'Destination ticket no longer exists.'**
  String get destinationTicketGone;

  /// No description provided for @movedItemsTo.
  ///
  /// In en, this message translates to:
  /// **'Moved items from ticket #{source} to {destination}'**
  String movedItemsTo(String source, String destination);

  /// No description provided for @moveTicketFailed.
  ///
  /// In en, this message translates to:
  /// **'Move ticket failed: {error}'**
  String moveTicketFailed(String error);

  /// No description provided for @destTicketRef.
  ///
  /// In en, this message translates to:
  /// **'ticket #{id}'**
  String destTicketRef(String id);

  /// No description provided for @destTableRef.
  ///
  /// In en, this message translates to:
  /// **'table #{id} (new ticket)'**
  String destTableRef(String id);

  /// No description provided for @sourceTotalItems.
  ///
  /// In en, this message translates to:
  /// **'Source total: ₭{total}\nItems: {count}'**
  String sourceTotalItems(String total, String count);

  /// No description provided for @cannotLoadRiders.
  ///
  /// In en, this message translates to:
  /// **'Cannot load riders: {error}'**
  String cannotLoadRiders(String error);

  /// No description provided for @noRidersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No riders available for this branch.'**
  String get noRidersAvailable;

  /// No description provided for @selectRider.
  ///
  /// In en, this message translates to:
  /// **'Select Rider'**
  String get selectRider;

  /// No description provided for @orderForCustomer.
  ///
  /// In en, this message translates to:
  /// **'Order for: {name}'**
  String orderForCustomer(String name);

  /// No description provided for @deliveryToPlace.
  ///
  /// In en, this message translates to:
  /// **'Delivery to: {place}'**
  String deliveryToPlace(String place);

  /// No description provided for @selfOrderDelivery.
  ///
  /// In en, this message translates to:
  /// **'Self-order delivery'**
  String get selfOrderDelivery;

  /// No description provided for @unnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get unnamed;

  /// No description provided for @orderSentToRider.
  ///
  /// In en, this message translates to:
  /// **'Order sent to {rider}'**
  String orderSentToRider(String rider);

  /// No description provided for @failedToAssignRider.
  ///
  /// In en, this message translates to:
  /// **'Failed to assign rider: {error}'**
  String failedToAssignRider(String error);

  /// No description provided for @customerSelected.
  ///
  /// In en, this message translates to:
  /// **'Customer {name} selected!'**
  String customerSelected(String name);

  /// No description provided for @charge.
  ///
  /// In en, this message translates to:
  /// **'Charge'**
  String get charge;

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmount;

  /// No description provided for @selectPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Select Payment Method'**
  String get selectPaymentMethod;

  /// No description provided for @noPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'No payment methods configured.'**
  String get noPaymentMethods;

  /// No description provided for @amountReceived.
  ///
  /// In en, this message translates to:
  /// **'Amount Received'**
  String get amountReceived;

  /// No description provided for @changeDue.
  ///
  /// In en, this message translates to:
  /// **'Change Due:'**
  String get changeDue;

  /// No description provided for @chargeAmount.
  ///
  /// In en, this message translates to:
  /// **'CHARGE K{amount}'**
  String chargeAmount(String amount);

  /// No description provided for @orderPaidSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Order Paid Successfully!'**
  String get orderPaidSuccessfully;

  /// No description provided for @transferTicketFixedTo.
  ///
  /// In en, this message translates to:
  /// **'Transfer ticket: fixed to {method}.'**
  String transferTicketFixedTo(String method);

  /// No description provided for @transferTicketFixed.
  ///
  /// In en, this message translates to:
  /// **'Transfer ticket: payment method is fixed.'**
  String get transferTicketFixed;

  /// No description provided for @administrator.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get administrator;

  /// No description provided for @posTerminal.
  ///
  /// In en, this message translates to:
  /// **'POS Terminal'**
  String get posTerminal;

  /// No description provided for @sales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get sales;

  /// No description provided for @receipts.
  ///
  /// In en, this message translates to:
  /// **'Receipts'**
  String get receipts;

  /// No description provided for @selfOrdersReview.
  ///
  /// In en, this message translates to:
  /// **'Self Orders Review'**
  String get selfOrdersReview;

  /// No description provided for @itemsMenu.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get itemsMenu;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @lockSwitchUser.
  ///
  /// In en, this message translates to:
  /// **'Lock / Switch User'**
  String get lockSwitchUser;

  /// No description provided for @demoCashier.
  ///
  /// In en, this message translates to:
  /// **'Demo Cashier'**
  String get demoCashier;

  /// No description provided for @selectTable.
  ///
  /// In en, this message translates to:
  /// **'Select Table'**
  String get selectTable;

  /// No description provided for @chooseLocationNewTicket.
  ///
  /// In en, this message translates to:
  /// **'Choose a location to open a new ticket'**
  String get chooseLocationNewTicket;

  /// No description provided for @noTablesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No tables available.\nPlease sync catalog.'**
  String get noTablesAvailable;

  /// No description provided for @tableAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get tableAvailable;

  /// No description provided for @tableOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get tableOpen;

  /// No description provided for @tableOccupied.
  ///
  /// In en, this message translates to:
  /// **'Occupied'**
  String get tableOccupied;

  /// No description provided for @openOrder.
  ///
  /// In en, this message translates to:
  /// **'Open Order'**
  String get openOrder;

  /// No description provided for @ticketOpenedAt.
  ///
  /// In en, this message translates to:
  /// **'Ticket opened at {table}!'**
  String ticketOpenedAt(String table);

  /// No description provided for @rewardClaimed.
  ///
  /// In en, this message translates to:
  /// **'Reward Claimed!'**
  String get rewardClaimed;

  /// No description provided for @voucherCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer: {name}'**
  String voucherCustomer(String name);

  /// No description provided for @voucherProduct.
  ///
  /// In en, this message translates to:
  /// **'Product: {name}'**
  String voucherProduct(String name);

  /// No description provided for @giveItemToCustomer.
  ///
  /// In en, this message translates to:
  /// **'Please give this item to the customer.'**
  String get giveItemToCustomer;

  /// No description provided for @claimRewardVoucher.
  ///
  /// In en, this message translates to:
  /// **'Claim Reward Voucher'**
  String get claimRewardVoucher;

  /// No description provided for @enterOrScanVoucher.
  ///
  /// In en, this message translates to:
  /// **'Enter or scan the customer\'s reward voucher code:'**
  String get enterOrScanVoucher;

  /// No description provided for @voucherCode.
  ///
  /// In en, this message translates to:
  /// **'Voucher Code'**
  String get voucherCode;

  /// No description provided for @claim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get claim;

  /// No description provided for @syncedOfflineOrders.
  ///
  /// In en, this message translates to:
  /// **'✅ Synced {count} offline orders to server.'**
  String syncedOfflineOrders(String count);

  /// No description provided for @syncedAllData.
  ///
  /// In en, this message translates to:
  /// **'✅ Synced all data.'**
  String get syncedAllData;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String syncFailed(String error);

  /// No description provided for @newSelfOrderWaiting.
  ///
  /// In en, this message translates to:
  /// **'New self order waiting review'**
  String get newSelfOrderWaiting;

  /// No description provided for @newSelfOrderWaitingCount.
  ///
  /// In en, this message translates to:
  /// **'New self order waiting review ({count} pending)'**
  String newSelfOrderWaitingCount(String count);

  /// No description provided for @newSelfOrderDetail.
  ///
  /// In en, this message translates to:
  /// **'New self order: {summary}'**
  String newSelfOrderDetail(String summary);

  /// No description provided for @newSelfOrdersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} new self orders: {detail}'**
  String newSelfOrdersCount(String count, String detail);

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @laoLanguage.
  ///
  /// In en, this message translates to:
  /// **'Lao'**
  String get laoLanguage;

  /// No description provided for @chooseAppLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose the app language'**
  String get chooseAppLanguage;

  /// No description provided for @appSettings.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettings;

  /// No description provided for @printerConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Printer Configuration'**
  String get printerConfiguration;

  /// No description provided for @printersConfigured.
  ///
  /// In en, this message translates to:
  /// **'{count} printer(s) configured'**
  String printersConfigured(String count);

  /// No description provided for @connectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected: {ip}'**
  String connectedTo(String ip);

  /// No description provided for @notConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get notConfigured;

  /// No description provided for @billTemplates.
  ///
  /// In en, this message translates to:
  /// **'Bill Templates'**
  String get billTemplates;

  /// No description provided for @billTemplatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select bill/receipt/refund templates for this branch'**
  String get billTemplatesSubtitle;

  /// No description provided for @discountConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Discount Configuration'**
  String get discountConfiguration;

  /// No description provided for @discountOptionsConfigured.
  ///
  /// In en, this message translates to:
  /// **'{count} discount option(s) configured'**
  String discountOptionsConfigured(String count);

  /// No description provided for @usePromotionPrice.
  ///
  /// In en, this message translates to:
  /// **'Use Promotion Price in POS'**
  String get usePromotionPrice;

  /// No description provided for @promotionalPricesApplied.
  ///
  /// In en, this message translates to:
  /// **'Promotional prices will be applied'**
  String get promotionalPricesApplied;

  /// No description provided for @normalPricesApplied.
  ///
  /// In en, this message translates to:
  /// **'Normal base prices will be applied'**
  String get normalPricesApplied;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please login again.'**
  String get sessionExpired;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @selectedLocation.
  ///
  /// In en, this message translates to:
  /// **'Selected location'**
  String get selectedLocation;

  /// No description provided for @couldNotSearchPlaces.
  ///
  /// In en, this message translates to:
  /// **'Could not search for places. Please check your connection.'**
  String get couldNotSearchPlaces;

  /// No description provided for @couldNotReadAddress.
  ///
  /// In en, this message translates to:
  /// **'Could not read the selected address. Please try again.'**
  String get couldNotReadAddress;

  /// No description provided for @addFavoritePlace.
  ///
  /// In en, this message translates to:
  /// **'Add favorite place'**
  String get addFavoritePlace;

  /// No description provided for @searchAddressOrPlace.
  ///
  /// In en, this message translates to:
  /// **'Search address or place'**
  String get searchAddressOrPlace;

  /// No description provided for @nameThisPlace.
  ///
  /// In en, this message translates to:
  /// **'Name this place, e.g. House'**
  String get nameThisPlace;

  /// No description provided for @placeHouse.
  ///
  /// In en, this message translates to:
  /// **'House'**
  String get placeHouse;

  /// No description provided for @placeWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get placeWork;

  /// No description provided for @placeFriendHouse.
  ///
  /// In en, this message translates to:
  /// **'Friend house'**
  String get placeFriendHouse;

  /// No description provided for @locationServicesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled. Please enable them in Settings.'**
  String get locationServicesDisabled;

  /// No description provided for @locationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied.'**
  String get locationPermissionDenied;

  /// No description provided for @locationPermissionPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission permanently denied. Please enable it in Settings.'**
  String get locationPermissionPermanentlyDenied;

  /// No description provided for @couldNotGetLocation.
  ///
  /// In en, this message translates to:
  /// **'Could not get current location. Please allow location access and try again.'**
  String get couldNotGetLocation;

  /// No description provided for @moveMapToPlacePin.
  ///
  /// In en, this message translates to:
  /// **'Move the map to place the pin'**
  String get moveMapToPlacePin;

  /// No description provided for @readingSelectedAddress.
  ///
  /// In en, this message translates to:
  /// **'Reading selected address...'**
  String get readingSelectedAddress;

  /// No description provided for @addSelectedPlace.
  ///
  /// In en, this message translates to:
  /// **'Add selected place'**
  String get addSelectedPlace;

  /// No description provided for @addDeliveryPlaces.
  ///
  /// In en, this message translates to:
  /// **'Add delivery places for self order'**
  String get addDeliveryPlaces;

  /// No description provided for @favoritePlaces.
  ///
  /// In en, this message translates to:
  /// **'Favorite places'**
  String get favoritePlaces;

  /// No description provided for @noFavoritePlaces.
  ///
  /// In en, this message translates to:
  /// **'No favorite places saved yet.'**
  String get noFavoritePlaces;

  /// No description provided for @deletePlaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete place?'**
  String get deletePlaceTitle;

  /// No description provided for @removePlaceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" from your favorites?'**
  String removePlaceConfirm(String name);

  /// No description provided for @placeSavedCount.
  ///
  /// In en, this message translates to:
  /// **'{label}  •  {count} saved'**
  String placeSavedCount(String label, String count);

  /// No description provided for @profileImageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile image updated'**
  String get profileImageUpdated;

  /// No description provided for @couldNotOpenImagePicker.
  ///
  /// In en, this message translates to:
  /// **'Could not open the image picker. Please try again.'**
  String get couldNotOpenImagePicker;

  /// No description provided for @noQrImageConfigured.
  ///
  /// In en, this message translates to:
  /// **'No QR image configured yet'**
  String get noQrImageConfigured;

  /// No description provided for @photosPermissionBlocked.
  ///
  /// In en, this message translates to:
  /// **'Photos permission is blocked. Open Settings to allow access.'**
  String get photosPermissionBlocked;

  /// No description provided for @photoPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Photo permission is required to save QR'**
  String get photoPermissionRequired;

  /// No description provided for @storagePermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Storage permission is required to save QR'**
  String get storagePermissionRequired;

  /// No description provided for @qrSavedToGallery.
  ///
  /// In en, this message translates to:
  /// **'QR saved to gallery ✓'**
  String get qrSavedToGallery;

  /// No description provided for @couldNotSaveQr.
  ///
  /// In en, this message translates to:
  /// **'Could not save QR code. Please try again.'**
  String get couldNotSaveQr;

  /// No description provided for @cannotFindSaveDirectory.
  ///
  /// In en, this message translates to:
  /// **'Cannot find save directory'**
  String get cannotFindSaveDirectory;

  /// No description provided for @couldNotSaveQrDownloads.
  ///
  /// In en, this message translates to:
  /// **'Could not save QR to Downloads. Please try again.'**
  String get couldNotSaveQrDownloads;

  /// No description provided for @qrSavedTo.
  ///
  /// In en, this message translates to:
  /// **'QR saved to {path}'**
  String qrSavedTo(String path);

  /// No description provided for @itemRunOut.
  ///
  /// In en, this message translates to:
  /// **'This item is run out and cannot be ordered.'**
  String get itemRunOut;

  /// No description provided for @couponApplied.
  ///
  /// In en, this message translates to:
  /// **'Coupon applied successfully!'**
  String get couponApplied;

  /// No description provided for @phoneNumberRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone Number Required'**
  String get phoneNumberRequiredTitle;

  /// No description provided for @verifiedPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'A verified phone number is required before placing an order. Please update your profile.'**
  String get verifiedPhoneRequired;

  /// No description provided for @updateProfile.
  ///
  /// In en, this message translates to:
  /// **'Update Profile'**
  String get updateProfile;

  /// No description provided for @branchClosed.
  ///
  /// In en, this message translates to:
  /// **'This branch is currently closed. Please choose another branch or order later.'**
  String get branchClosed;

  /// No description provided for @howReceiveOrder.
  ///
  /// In en, this message translates to:
  /// **'How will you receive your order?'**
  String get howReceiveOrder;

  /// No description provided for @riderDelivery.
  ///
  /// In en, this message translates to:
  /// **'Rider delivery'**
  String get riderDelivery;

  /// No description provided for @comePickUpMyself.
  ///
  /// In en, this message translates to:
  /// **'Come pick up myself'**
  String get comePickUpMyself;

  /// No description provided for @deliveryPlace.
  ///
  /// In en, this message translates to:
  /// **'Delivery place'**
  String get deliveryPlace;

  /// No description provided for @addFavoritePlaceBeforeOrder.
  ///
  /// In en, this message translates to:
  /// **'Please add a favorite place before confirming the order.'**
  String get addFavoritePlaceBeforeOrder;

  /// No description provided for @selectDeliveryPlace.
  ///
  /// In en, this message translates to:
  /// **'Select a delivery place'**
  String get selectDeliveryPlace;

  /// No description provided for @paymentBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Payment Breakdown'**
  String get paymentBreakdown;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @pointsRequired.
  ///
  /// In en, this message translates to:
  /// **'Points Required'**
  String get pointsRequired;

  /// No description provided for @totalPayment.
  ///
  /// In en, this message translates to:
  /// **'Total Payment'**
  String get totalPayment;

  /// No description provided for @deliveryFeeKm.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee ({km} km)'**
  String deliveryFeeKm(String km);

  /// No description provided for @addMoreForFreeDelivery.
  ///
  /// In en, this message translates to:
  /// **'Add ₭{amount} more to get free delivery!'**
  String addMoreForFreeDelivery(String amount);

  /// No description provided for @notEnoughPointsRedeem.
  ///
  /// In en, this message translates to:
  /// **'Not enough points to redeem these items.'**
  String get notEnoughPointsRedeem;

  /// No description provided for @payTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get payTransfer;

  /// No description provided for @payAtStore.
  ///
  /// In en, this message translates to:
  /// **'Pay At Store'**
  String get payAtStore;

  /// No description provided for @orderCreatedProofUploaded.
  ///
  /// In en, this message translates to:
  /// **'Order created. Transfer proof uploaded.'**
  String get orderCreatedProofUploaded;

  /// No description provided for @orderCreatedProofLocal.
  ///
  /// In en, this message translates to:
  /// **'Order created. Transfer proof saved locally.'**
  String get orderCreatedProofLocal;

  /// No description provided for @orderCreatedPayAtStore.
  ///
  /// In en, this message translates to:
  /// **'Order created. Please pay at the store.'**
  String get orderCreatedPayAtStore;

  /// No description provided for @failedToPlaceOrder.
  ///
  /// In en, this message translates to:
  /// **'Failed to place order. Please check your connection and try again.'**
  String get failedToPlaceOrder;

  /// No description provided for @phoneNumberRequiredLower.
  ///
  /// In en, this message translates to:
  /// **'Phone number required'**
  String get phoneNumberRequiredLower;

  /// No description provided for @addPhoneBeforeOrder.
  ///
  /// In en, this message translates to:
  /// **'Please add your phone number before placing an order. This is required for customer verification and so the store can contact you if needed.'**
  String get addPhoneBeforeOrder;

  /// No description provided for @addPhone.
  ///
  /// In en, this message translates to:
  /// **'Add phone'**
  String get addPhone;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @couldNotSaveProfileConnection.
  ///
  /// In en, this message translates to:
  /// **'Could not save profile. Please check your connection and try again.'**
  String get couldNotSaveProfileConnection;

  /// No description provided for @couldNotSaveProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not save profile. Please try again.'**
  String get couldNotSaveProfile;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get deleteAccountTitle;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get accountDeleted;

  /// No description provided for @couldNotDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Could not delete account. Please try again.'**
  String get couldNotDeleteAccount;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @fullNameCaps.
  ///
  /// In en, this message translates to:
  /// **'FULL NAME'**
  String get fullNameCaps;

  /// No description provided for @yourFullName.
  ///
  /// In en, this message translates to:
  /// **'Your Full Name'**
  String get yourFullName;

  /// No description provided for @phoneCaps.
  ///
  /// In en, this message translates to:
  /// **'PHONE'**
  String get phoneCaps;

  /// No description provided for @phoneExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. 20XXXXXXXX'**
  String get phoneExample;

  /// No description provided for @dateOfBirthCaps.
  ///
  /// In en, this message translates to:
  /// **'DATE OF BIRTH'**
  String get dateOfBirthCaps;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @phoneNumberIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get phoneNumberIsRequired;

  /// No description provided for @phoneMustStartWith20.
  ///
  /// In en, this message translates to:
  /// **'Phone number must start with 20 and be exactly 10 digits long (e.g. 20XXXXXXXX)'**
  String get phoneMustStartWith20;

  /// No description provided for @verifyAndSave.
  ///
  /// In en, this message translates to:
  /// **'VERIFY & SAVE'**
  String get verifyAndSave;

  /// No description provided for @otpVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'OTP verification failed'**
  String get otpVerificationFailed;

  /// No description provided for @failedToResendOtp.
  ///
  /// In en, this message translates to:
  /// **'Failed to resend OTP'**
  String get failedToResendOtp;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @loggingOut.
  ///
  /// In en, this message translates to:
  /// **'Logging out...'**
  String get loggingOut;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deletingAccount.
  ///
  /// In en, this message translates to:
  /// **'Deleting account...'**
  String get deletingAccount;

  /// No description provided for @clientIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Client ID copied to clipboard!'**
  String get clientIdCopied;

  /// No description provided for @rewardPointsLabel.
  ///
  /// In en, this message translates to:
  /// **'Reward points: {points}'**
  String rewardPointsLabel(String points);

  /// No description provided for @rewardsCatalog.
  ///
  /// In en, this message translates to:
  /// **'Rewards Catalog'**
  String get rewardsCatalog;

  /// No description provided for @noRewardsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No rewards available at the moment.'**
  String get noRewardsAvailable;

  /// No description provided for @notEnoughPoints.
  ///
  /// In en, this message translates to:
  /// **'Not enough points!'**
  String get notEnoughPoints;

  /// No description provided for @redeemRewardTitle.
  ///
  /// In en, this message translates to:
  /// **'Redeem Reward?'**
  String get redeemRewardTitle;

  /// No description provided for @redeemConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you want to convert {points} points into a voucher for {product}?'**
  String redeemConfirm(String points, String product);

  /// No description provided for @customerNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Customer not logged in properly.'**
  String get customerNotLoggedIn;

  /// No description provided for @voucherCreated.
  ///
  /// In en, this message translates to:
  /// **'Voucher created successfully!'**
  String get voucherCreated;

  /// No description provided for @redeem.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get redeem;

  /// No description provided for @claimedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Claimed Successfully!'**
  String get claimedSuccessfully;

  /// No description provided for @rewardClaimedEnjoy.
  ///
  /// In en, this message translates to:
  /// **'Your reward has been claimed. Enjoy!'**
  String get rewardClaimedEnjoy;

  /// No description provided for @scanQrAtCounter.
  ///
  /// In en, this message translates to:
  /// **'Scan this QR code at the counter to claim your reward.'**
  String get scanQrAtCounter;

  /// No description provided for @myVouchers.
  ///
  /// In en, this message translates to:
  /// **'My Vouchers'**
  String get myVouchers;

  /// No description provided for @notLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in.'**
  String get notLoggedIn;

  /// No description provided for @voucherActive.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get voucherActive;

  /// No description provided for @redeemPoints.
  ///
  /// In en, this message translates to:
  /// **'Redeem points'**
  String get redeemPoints;

  /// No description provided for @convertPointsIntoItems.
  ///
  /// In en, this message translates to:
  /// **'Convert your points into free items'**
  String get convertPointsIntoItems;

  /// No description provided for @viewClaimVouchers.
  ///
  /// In en, this message translates to:
  /// **'View and claim your saved vouchers'**
  String get viewClaimVouchers;

  /// No description provided for @ranking.
  ///
  /// In en, this message translates to:
  /// **'Ranking'**
  String get ranking;

  /// No description provided for @seeTop50.
  ///
  /// In en, this message translates to:
  /// **'See Top 50 rewards leaderboard'**
  String get seeTop50;

  /// No description provided for @customerSupport.
  ///
  /// In en, this message translates to:
  /// **'Customer support'**
  String get customerSupport;

  /// No description provided for @supportChannels.
  ///
  /// In en, this message translates to:
  /// **'Facebook & WhatsApp (from store settings)'**
  String get supportChannels;

  /// No description provided for @pointsSuffix.
  ///
  /// In en, this message translates to:
  /// **'{points} Pts'**
  String pointsSuffix(String points);

  /// No description provided for @couldNotUpdateNotifications.
  ///
  /// In en, this message translates to:
  /// **'Could not update notification settings. Please try again.'**
  String get couldNotUpdateNotifications;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @orderUpdatesOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Order updates on this device'**
  String get orderUpdatesOnDevice;

  /// No description provided for @pushAlertsOff.
  ///
  /// In en, this message translates to:
  /// **'Push alerts are turned off'**
  String get pushAlertsOff;

  /// No description provided for @customization.
  ///
  /// In en, this message translates to:
  /// **'Customization'**
  String get customization;

  /// No description provided for @totalPrice.
  ///
  /// In en, this message translates to:
  /// **'Total Price'**
  String get totalPrice;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get addToCart;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navCart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get navCart;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @errorLoadingProducts.
  ///
  /// In en, this message translates to:
  /// **'Error loading products'**
  String get errorLoadingProducts;

  /// No description provided for @allProducts.
  ///
  /// In en, this message translates to:
  /// **'All Products'**
  String get allProducts;

  /// No description provided for @noItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get noItemsFound;

  /// No description provided for @recommendedProducts.
  ///
  /// In en, this message translates to:
  /// **'Recommended Products'**
  String get recommendedProducts;

  /// No description provided for @recommendedBadge.
  ///
  /// In en, this message translates to:
  /// **'⭐ Recommended'**
  String get recommendedBadge;

  /// No description provided for @mostPopular.
  ///
  /// In en, this message translates to:
  /// **'Most Popular'**
  String get mostPopular;

  /// No description provided for @freshPicksToday.
  ///
  /// In en, this message translates to:
  /// **'Fresh picks for you today'**
  String get freshPicksToday;

  /// No description provided for @bestSeller.
  ///
  /// In en, this message translates to:
  /// **'Best Seller'**
  String get bestSeller;

  /// No description provided for @promoBadge.
  ///
  /// In en, this message translates to:
  /// **'PROMO'**
  String get promoBadge;

  /// No description provided for @selectItemToPreview.
  ///
  /// In en, this message translates to:
  /// **'Select an item\nto preview'**
  String get selectItemToPreview;

  /// No description provided for @noToppingsSelected.
  ///
  /// In en, this message translates to:
  /// **'No Toppings Selected'**
  String get noToppingsSelected;

  /// No description provided for @toppingsFor.
  ///
  /// In en, this message translates to:
  /// **'Toppings for {product}'**
  String toppingsFor(String product);

  /// No description provided for @cartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartEmpty;

  /// No description provided for @addItemsFromHome.
  ///
  /// In en, this message translates to:
  /// **'Add items from Home'**
  String get addItemsFromHome;

  /// No description provided for @enterCouponCode.
  ///
  /// In en, this message translates to:
  /// **'Enter coupon code'**
  String get enterCouponCode;

  /// No description provided for @couponApplied2.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get couponApplied2;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @addedToCart.
  ///
  /// In en, this message translates to:
  /// **'{name} added to cart'**
  String addedToCart(String name);

  /// No description provided for @addedToCartQty.
  ///
  /// In en, this message translates to:
  /// **'{qty} {name} added to cart'**
  String addedToCartQty(String qty, String name);

  /// No description provided for @discountWithCode.
  ///
  /// In en, this message translates to:
  /// **'Discount ({code})'**
  String discountWithCode(String code);

  /// No description provided for @noOrderHistory.
  ///
  /// In en, this message translates to:
  /// **'No order history yet'**
  String get noOrderHistory;

  /// No description provided for @completedOrdersHere.
  ///
  /// In en, this message translates to:
  /// **'Your completed orders will show up here.'**
  String get completedOrdersHere;

  /// No description provided for @paymentMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethodLabel;

  /// No description provided for @trackRider.
  ///
  /// In en, this message translates to:
  /// **'Track Rider'**
  String get trackRider;

  /// No description provided for @viewChatHistory.
  ///
  /// In en, this message translates to:
  /// **'View Chat History'**
  String get viewChatHistory;

  /// No description provided for @chatWithRider.
  ///
  /// In en, this message translates to:
  /// **'Chat with Rider'**
  String get chatWithRider;

  /// No description provided for @viewOrderDetails.
  ///
  /// In en, this message translates to:
  /// **'View order details'**
  String get viewOrderDetails;

  /// No description provided for @statusComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get statusComplete;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusRiderArrived.
  ///
  /// In en, this message translates to:
  /// **'Rider arrived'**
  String get statusRiderArrived;

  /// No description provided for @statusOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get statusOnTheWay;

  /// No description provided for @statusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get statusPreparing;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusWaitingTransfer.
  ///
  /// In en, this message translates to:
  /// **'Waiting transfer verification'**
  String get statusWaitingTransfer;

  /// No description provided for @statusOrderConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Order confirmed'**
  String get statusOrderConfirmed;

  /// No description provided for @statusRiderOnWay.
  ///
  /// In en, this message translates to:
  /// **'Rider is on the way'**
  String get statusRiderOnWay;

  /// No description provided for @statusPreparingYourOrder.
  ///
  /// In en, this message translates to:
  /// **'Preparing your order'**
  String get statusPreparingYourOrder;

  /// No description provided for @statusTransferVerified.
  ///
  /// In en, this message translates to:
  /// **'Transfer verified, preparing order'**
  String get statusTransferVerified;

  /// No description provided for @statusArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get statusArrived;

  /// No description provided for @deliveryProgress.
  ///
  /// In en, this message translates to:
  /// **'Delivery progress'**
  String get deliveryProgress;

  /// No description provided for @arrivingSoon.
  ///
  /// In en, this message translates to:
  /// **'Arriving soon'**
  String get arrivingSoon;

  /// No description provided for @deliveryLocation.
  ///
  /// In en, this message translates to:
  /// **'Delivery location'**
  String get deliveryLocation;

  /// No description provided for @liveRiderTracking.
  ///
  /// In en, this message translates to:
  /// **'Live Rider Tracking'**
  String get liveRiderTracking;

  /// No description provided for @liveBadge.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get liveBadge;

  /// No description provided for @fetchingRiderLocation.
  ///
  /// In en, this message translates to:
  /// **'Fetching rider location…'**
  String get fetchingRiderLocation;

  /// No description provided for @noLocationData.
  ///
  /// In en, this message translates to:
  /// **'No location data yet'**
  String get noLocationData;

  /// No description provided for @riderLocationWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Rider location will appear here once available'**
  String get riderLocationWillAppear;

  /// No description provided for @riderLocation.
  ///
  /// In en, this message translates to:
  /// **'Rider location'**
  String get riderLocation;

  /// No description provided for @etaLabel.
  ///
  /// In en, this message translates to:
  /// **'ETA: {eta}'**
  String etaLabel(String eta);

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(String minutes);

  /// No description provided for @hoursMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String hoursMinutesShort(String hours, String minutes);

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @qty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get qty;

  /// No description provided for @item.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get item;

  /// No description provided for @product.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get product;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @toppings.
  ///
  /// In en, this message translates to:
  /// **'Toppings'**
  String get toppings;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @order.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get order;

  /// No description provided for @revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenue;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @blocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get blocked;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @today2.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get today2;

  /// No description provided for @yesterday2.
  ///
  /// In en, this message translates to:
  /// **'YESTERDAY'**
  String get yesterday2;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load More'**
  String get loadMore;

  /// No description provided for @fullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get fullscreen;

  /// No description provided for @official.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get official;

  /// No description provided for @unsynced.
  ///
  /// In en, this message translates to:
  /// **'Unsynced'**
  String get unsynced;

  /// No description provided for @percentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get percentage;

  /// No description provided for @fixedValue.
  ///
  /// In en, this message translates to:
  /// **'Fixed Value'**
  String get fixedValue;

  /// No description provided for @manageCatalog.
  ///
  /// In en, this message translates to:
  /// **'Manage Catalog'**
  String get manageCatalog;

  /// No description provided for @manageYourActiveProductCatalog.
  ///
  /// In en, this message translates to:
  /// **'Manage your active product catalog'**
  String get manageYourActiveProductCatalog;

  /// No description provided for @organizeProductsIntoGroups.
  ///
  /// In en, this message translates to:
  /// **'Organize products into groups'**
  String get organizeProductsIntoGroups;

  /// No description provided for @addOnsModifiersAndVariations.
  ///
  /// In en, this message translates to:
  /// **'Add-ons, modifiers, and variations'**
  String get addOnsModifiersAndVariations;

  /// No description provided for @manageCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage Categories'**
  String get manageCategories;

  /// No description provided for @manageCombos.
  ///
  /// In en, this message translates to:
  /// **'Manage Combos'**
  String get manageCombos;

  /// No description provided for @manageProducts.
  ///
  /// In en, this message translates to:
  /// **'Manage Products'**
  String get manageProducts;

  /// No description provided for @manageToppings.
  ///
  /// In en, this message translates to:
  /// **'Manage Toppings'**
  String get manageToppings;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProduct;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get addCategory;

  /// No description provided for @addCombo.
  ///
  /// In en, this message translates to:
  /// **'Add Combo'**
  String get addCombo;

  /// No description provided for @addTopping.
  ///
  /// In en, this message translates to:
  /// **'Add Topping'**
  String get addTopping;

  /// No description provided for @addYourFirstCategoryToGet.
  ///
  /// In en, this message translates to:
  /// **'Add your first category to get started'**
  String get addYourFirstCategoryToGet;

  /// No description provided for @addYourFirstComboToGet.
  ///
  /// In en, this message translates to:
  /// **'Add your first combo to get started'**
  String get addYourFirstComboToGet;

  /// No description provided for @addYourFirstProductToGet.
  ///
  /// In en, this message translates to:
  /// **'Add your first product to get started'**
  String get addYourFirstProductToGet;

  /// No description provided for @addYourFirstToppingToGet.
  ///
  /// In en, this message translates to:
  /// **'Add your first topping to get started'**
  String get addYourFirstToppingToGet;

  /// No description provided for @noCategoriesYet.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get noCategoriesYet;

  /// No description provided for @noCombosYet.
  ///
  /// In en, this message translates to:
  /// **'No combos yet'**
  String get noCombosYet;

  /// No description provided for @noProductsYet.
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get noProductsYet;

  /// No description provided for @noToppingsYet.
  ///
  /// In en, this message translates to:
  /// **'No toppings yet'**
  String get noToppingsYet;

  /// No description provided for @deleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Delete Category'**
  String get deleteCategory;

  /// No description provided for @deleteCombo.
  ///
  /// In en, this message translates to:
  /// **'Delete Combo'**
  String get deleteCombo;

  /// No description provided for @deleteProduct.
  ///
  /// In en, this message translates to:
  /// **'Delete Product'**
  String get deleteProduct;

  /// No description provided for @deleteTopping.
  ///
  /// In en, this message translates to:
  /// **'Delete Topping'**
  String get deleteTopping;

  /// No description provided for @areYouSureYouWantTo.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this category?'**
  String get areYouSureYouWantTo;

  /// No description provided for @areYouSureYouWantTo2.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this combo?'**
  String get areYouSureYouWantTo2;

  /// No description provided for @areYouSureYouWantTo3.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this product?'**
  String get areYouSureYouWantTo3;

  /// No description provided for @areYouSureYouWantTo4.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this topping?'**
  String get areYouSureYouWantTo4;

  /// No description provided for @categoryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Category deleted'**
  String get categoryDeleted;

  /// No description provided for @comboDeleted.
  ///
  /// In en, this message translates to:
  /// **'Combo deleted'**
  String get comboDeleted;

  /// No description provided for @productDeleted.
  ///
  /// In en, this message translates to:
  /// **'Product deleted'**
  String get productDeleted;

  /// No description provided for @toppingDeleted.
  ///
  /// In en, this message translates to:
  /// **'Topping deleted'**
  String get toppingDeleted;

  /// No description provided for @visibleInApp.
  ///
  /// In en, this message translates to:
  /// **'Visible in app'**
  String get visibleInApp;

  /// No description provided for @hiddenInApp.
  ///
  /// In en, this message translates to:
  /// **'Hidden in app'**
  String get hiddenInApp;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category Name*'**
  String get categoryName;

  /// No description provided for @comboName.
  ///
  /// In en, this message translates to:
  /// **'Combo Name*'**
  String get comboName;

  /// No description provided for @comboFixedPrice.
  ///
  /// In en, this message translates to:
  /// **'Combo Fixed Price*'**
  String get comboFixedPrice;

  /// No description provided for @productName.
  ///
  /// In en, this message translates to:
  /// **'Product Name*'**
  String get productName;

  /// No description provided for @toppingName.
  ///
  /// In en, this message translates to:
  /// **'Topping Name*'**
  String get toppingName;

  /// No description provided for @listPrice.
  ///
  /// In en, this message translates to:
  /// **'List Price*'**
  String get listPrice;

  /// No description provided for @extraPriceOptional.
  ///
  /// In en, this message translates to:
  /// **'Extra Price (Optional)'**
  String get extraPriceOptional;

  /// No description provided for @saveCategory.
  ///
  /// In en, this message translates to:
  /// **'Save Category'**
  String get saveCategory;

  /// No description provided for @saveCombo.
  ///
  /// In en, this message translates to:
  /// **'Save Combo'**
  String get saveCombo;

  /// No description provided for @saveProduct.
  ///
  /// In en, this message translates to:
  /// **'Save Product'**
  String get saveProduct;

  /// No description provided for @saveTopping.
  ///
  /// In en, this message translates to:
  /// **'Save Topping'**
  String get saveTopping;

  /// No description provided for @categoryAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Category added successfully'**
  String get categoryAddedSuccessfully;

  /// No description provided for @categoryUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Category updated successfully'**
  String get categoryUpdatedSuccessfully;

  /// No description provided for @comboSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Combo saved successfully'**
  String get comboSavedSuccessfully;

  /// No description provided for @productSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Product saved successfully'**
  String get productSavedSuccessfully;

  /// No description provided for @toppingSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Topping saved successfully'**
  String get toppingSavedSuccessfully;

  /// No description provided for @nameIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameIsRequired;

  /// No description provided for @validNameAndPriceAreRequired.
  ///
  /// In en, this message translates to:
  /// **'Valid name and price are required'**
  String get validNameAndPriceAreRequired;

  /// No description provided for @comboMustHaveAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Combo must have at least one product'**
  String get comboMustHaveAtLeastOne;

  /// No description provided for @comboItems.
  ///
  /// In en, this message translates to:
  /// **'Combo Items'**
  String get comboItems;

  /// No description provided for @noProductsAddedToThisCombo.
  ///
  /// In en, this message translates to:
  /// **'No products added to this combo yet.'**
  String get noProductsAddedToThisCombo;

  /// No description provided for @availableToppings.
  ///
  /// In en, this message translates to:
  /// **'Available Toppings'**
  String get availableToppings;

  /// No description provided for @noToppingsConfigured.
  ///
  /// In en, this message translates to:
  /// **'No toppings configured.'**
  String get noToppingsConfigured;

  /// No description provided for @showInApp.
  ///
  /// In en, this message translates to:
  /// **'Show in app'**
  String get showInApp;

  /// No description provided for @onlyCheckedCategoriesAreVisibleIn.
  ///
  /// In en, this message translates to:
  /// **'Only checked categories are visible in POS app.'**
  String get onlyCheckedCategoriesAreVisibleIn;

  /// No description provided for @customerSelfOrder.
  ///
  /// In en, this message translates to:
  /// **'Customer self-order'**
  String get customerSelfOrder;

  /// No description provided for @customersCanSelectAndOrder.
  ///
  /// In en, this message translates to:
  /// **'Customers can select and order'**
  String get customersCanSelectAndOrder;

  /// No description provided for @runOutBlocked.
  ///
  /// In en, this message translates to:
  /// **'Run out (blocked)'**
  String get runOutBlocked;

  /// No description provided for @shownAsRunOutCannotAdd.
  ///
  /// In en, this message translates to:
  /// **'Shown as run out; cannot add to cart'**
  String get shownAsRunOutCannotAdd;

  /// No description provided for @couldNotSaveToppingPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Could not save topping. Please try again.'**
  String get couldNotSaveToppingPleaseTry;

  /// No description provided for @currentTicket2.
  ///
  /// In en, this message translates to:
  /// **'Current Ticket'**
  String get currentTicket2;

  /// No description provided for @newItems.
  ///
  /// In en, this message translates to:
  /// **'NEW ITEMS'**
  String get newItems;

  /// No description provided for @alreadyOrdered.
  ///
  /// In en, this message translates to:
  /// **'ALREADY ORDERED'**
  String get alreadyOrdered;

  /// No description provided for @noItems.
  ///
  /// In en, this message translates to:
  /// **'No items'**
  String get noItems;

  /// No description provided for @noItemsInTicket.
  ///
  /// In en, this message translates to:
  /// **'No items in ticket'**
  String get noItemsInTicket;

  /// No description provided for @addCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get addCustomer;

  /// No description provided for @clearTicket2.
  ///
  /// In en, this message translates to:
  /// **'Clear Ticket'**
  String get clearTicket2;

  /// No description provided for @saveTicket.
  ///
  /// In en, this message translates to:
  /// **'SAVE TICKET'**
  String get saveTicket;

  /// No description provided for @charge2.
  ///
  /// In en, this message translates to:
  /// **'CHARGE'**
  String get charge2;

  /// No description provided for @subtotalExclVat.
  ///
  /// In en, this message translates to:
  /// **'Subtotal (excl. VAT)'**
  String get subtotalExclVat;

  /// No description provided for @amountExclVat2.
  ///
  /// In en, this message translates to:
  /// **'Amount (excl. VAT)'**
  String get amountExclVat2;

  /// No description provided for @includesVat.
  ///
  /// In en, this message translates to:
  /// **'Includes VAT'**
  String get includesVat;

  /// No description provided for @priceIncludesTax.
  ///
  /// In en, this message translates to:
  /// **'Price includes tax'**
  String get priceIncludesTax;

  /// No description provided for @taxHiddenOnReceipt.
  ///
  /// In en, this message translates to:
  /// **'Tax hidden on receipt'**
  String get taxHiddenOnReceipt;

  /// No description provided for @totalDue.
  ///
  /// In en, this message translates to:
  /// **'Total due'**
  String get totalDue;

  /// No description provided for @selectCustomer.
  ///
  /// In en, this message translates to:
  /// **'Select Customer'**
  String get selectCustomer;

  /// No description provided for @addCustomer2.
  ///
  /// In en, this message translates to:
  /// **'Add Customer'**
  String get addCustomer2;

  /// No description provided for @newCustomer.
  ///
  /// In en, this message translates to:
  /// **'New Customer'**
  String get newCustomer;

  /// No description provided for @addCustomerIfNotFound.
  ///
  /// In en, this message translates to:
  /// **'Add customer if not found'**
  String get addCustomerIfNotFound;

  /// No description provided for @searchByNameOrPhone.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone...'**
  String get searchByNameOrPhone;

  /// No description provided for @loadingCustomers.
  ///
  /// In en, this message translates to:
  /// **'Loading customers...'**
  String get loadingCustomers;

  /// No description provided for @noCustomersFound.
  ///
  /// In en, this message translates to:
  /// **'No customers found'**
  String get noCustomersFound;

  /// No description provided for @searchFailedPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Search failed. Please try again.'**
  String get searchFailedPleaseTryAgain;

  /// No description provided for @couldNotCreateCustomerPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Could not create customer. Please try again.'**
  String get couldNotCreateCustomerPleaseTry;

  /// No description provided for @couldNotLoadMorePleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Could not load more. Please try again.'**
  String get couldNotLoadMorePleaseTry;

  /// No description provided for @noOpenTickets.
  ///
  /// In en, this message translates to:
  /// **'No open tickets'**
  String get noOpenTickets;

  /// No description provided for @noTable2.
  ///
  /// In en, this message translates to:
  /// **'No Table'**
  String get noTable2;

  /// No description provided for @orderReady.
  ///
  /// In en, this message translates to:
  /// **'Order Ready'**
  String get orderReady;

  /// No description provided for @discountCustomItem.
  ///
  /// In en, this message translates to:
  /// **'Discount / Custom Item'**
  String get discountCustomItem;

  /// No description provided for @couldNotLoadTicketsPleaseCheck.
  ///
  /// In en, this message translates to:
  /// **'Could not load tickets. Please check your connection and try again.'**
  String get couldNotLoadTicketsPleaseCheck;

  /// No description provided for @couldNotSendNotificationPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Could not send notification. Please try again.'**
  String get couldNotSendNotificationPleaseTry;

  /// No description provided for @splitTicket.
  ///
  /// In en, this message translates to:
  /// **'Split Ticket'**
  String get splitTicket;

  /// No description provided for @ticketName.
  ///
  /// In en, this message translates to:
  /// **'Ticket Name'**
  String get ticketName;

  /// No description provided for @renameNewTicket.
  ///
  /// In en, this message translates to:
  /// **'Rename New Ticket'**
  String get renameNewTicket;

  /// No description provided for @allItemsMoved.
  ///
  /// In en, this message translates to:
  /// **'All items moved'**
  String get allItemsMoved;

  /// No description provided for @pleaseMoveAtLeastOneItem.
  ///
  /// In en, this message translates to:
  /// **'Please move at least one item to the new ticket.'**
  String get pleaseMoveAtLeastOneItem;

  /// No description provided for @theOriginalTicketCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'The original ticket cannot be empty. Keep at least one item.'**
  String get theOriginalTicketCannotBeEmpty;

  /// No description provided for @tapItemsOnTheLeftTo.
  ///
  /// In en, this message translates to:
  /// **'Tap items on the\nleft to move them here'**
  String get tapItemsOnTheLeftTo;

  /// No description provided for @discountOptions.
  ///
  /// In en, this message translates to:
  /// **'Discount Options'**
  String get discountOptions;

  /// No description provided for @addDiscountOption.
  ///
  /// In en, this message translates to:
  /// **'Add Discount Option'**
  String get addDiscountOption;

  /// No description provided for @discountType.
  ///
  /// In en, this message translates to:
  /// **'Discount Type'**
  String get discountType;

  /// No description provided for @enableDiscount.
  ///
  /// In en, this message translates to:
  /// **'Enable Discount'**
  String get enableDiscount;

  /// No description provided for @discountHidden.
  ///
  /// In en, this message translates to:
  /// **'Discount hidden'**
  String get discountHidden;

  /// No description provided for @discountWillAppearInPos.
  ///
  /// In en, this message translates to:
  /// **'Discount will appear in POS'**
  String get discountWillAppearInPos;

  /// No description provided for @discountSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Discount settings saved'**
  String get discountSettingsSaved;

  /// No description provided for @noDiscountOptionsAddedYet.
  ///
  /// In en, this message translates to:
  /// **'No discount options added yet.'**
  String get noDiscountOptionsAddedYet;

  /// No description provided for @optionName.
  ///
  /// In en, this message translates to:
  /// **'Option Name'**
  String get optionName;

  /// No description provided for @percentage2.
  ///
  /// In en, this message translates to:
  /// **'Percentage (%)'**
  String get percentage2;

  /// No description provided for @leaveEmptyForManualInput.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for manual input'**
  String get leaveEmptyForManualInput;

  /// No description provided for @tipLeaveTheValueBlankTo.
  ///
  /// In en, this message translates to:
  /// **'Tip: Leave the value blank to let cashiers enter a custom amount.'**
  String get tipLeaveTheValueBlankTo;

  /// No description provided for @receiptsHistory.
  ///
  /// In en, this message translates to:
  /// **'Receipts History'**
  String get receiptsHistory;

  /// No description provided for @noPaidReceiptsYet.
  ///
  /// In en, this message translates to:
  /// **'No paid receipts yet'**
  String get noPaidReceiptsYet;

  /// No description provided for @noMoreReceipts.
  ///
  /// In en, this message translates to:
  /// **'No more receipts'**
  String get noMoreReceipts;

  /// No description provided for @unknownDate.
  ///
  /// In en, this message translates to:
  /// **'Unknown Date'**
  String get unknownDate;

  /// No description provided for @thisReceiptIsMissingAnOrder.
  ///
  /// In en, this message translates to:
  /// **'This receipt is missing an order id. Please refresh and try again.'**
  String get thisReceiptIsMissingAnOrder;

  /// No description provided for @refund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get refund;

  /// No description provided for @refundOrder.
  ///
  /// In en, this message translates to:
  /// **'Refund Order'**
  String get refundOrder;

  /// No description provided for @confirmRefund.
  ///
  /// In en, this message translates to:
  /// **'Confirm Refund'**
  String get confirmRefund;

  /// No description provided for @reprintReceipt.
  ///
  /// In en, this message translates to:
  /// **'Reprint Receipt'**
  String get reprintReceipt;

  /// No description provided for @adminPin.
  ///
  /// In en, this message translates to:
  /// **'Admin PIN'**
  String get adminPin;

  /// No description provided for @adminPinIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Admin PIN is required.'**
  String get adminPinIsRequired;

  /// No description provided for @thisOrderHasBeenRefunded.
  ///
  /// In en, this message translates to:
  /// **'This order has been refunded'**
  String get thisOrderHasBeenRefunded;

  /// No description provided for @printerErrorCheckConnection.
  ///
  /// In en, this message translates to:
  /// **'Printer error. Check connection.'**
  String get printerErrorCheckConnection;

  /// No description provided for @orderRefundedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'✅ Order refunded successfully.'**
  String get orderRefundedSuccessfully;

  /// No description provided for @receiptReprinted.
  ///
  /// In en, this message translates to:
  /// **'🖨️ Receipt reprinted!'**
  String get receiptReprinted;

  /// No description provided for @noPendingSelfOrders.
  ///
  /// In en, this message translates to:
  /// **'No pending self orders'**
  String get noPendingSelfOrders;

  /// No description provided for @quickConfirm.
  ///
  /// In en, this message translates to:
  /// **'Quick Confirm'**
  String get quickConfirm;

  /// No description provided for @rejectOrder.
  ///
  /// In en, this message translates to:
  /// **'Reject Order'**
  String get rejectOrder;

  /// No description provided for @rejectOrder2.
  ///
  /// In en, this message translates to:
  /// **'Reject Order?'**
  String get rejectOrder2;

  /// No description provided for @orderRejectedAndCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order rejected and cancelled.'**
  String get orderRejectedAndCancelled;

  /// No description provided for @transferConfirmedOrderMovedToOpen.
  ///
  /// In en, this message translates to:
  /// **'Transfer confirmed. Order moved to Open Tickets.'**
  String get transferConfirmedOrderMovedToOpen;

  /// No description provided for @couldNotConfirmOrderPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Could not confirm order. Please try again.'**
  String get couldNotConfirmOrderPleaseTry;

  /// No description provided for @couldNotRejectOrderPleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Could not reject order. Please try again.'**
  String get couldNotRejectOrderPleaseTry;

  /// No description provided for @couldNotLoadOrdersPleaseCheck.
  ///
  /// In en, this message translates to:
  /// **'Could not load orders. Please check your connection and try again.'**
  String get couldNotLoadOrdersPleaseCheck;

  /// No description provided for @viewProof.
  ///
  /// In en, this message translates to:
  /// **'View Proof'**
  String get viewProof;

  /// No description provided for @noProofImageUploaded.
  ///
  /// In en, this message translates to:
  /// **'No proof image uploaded'**
  String get noProofImageUploaded;

  /// No description provided for @cannotLoadProofImage.
  ///
  /// In en, this message translates to:
  /// **'Cannot load proof image'**
  String get cannotLoadProofImage;

  /// No description provided for @bankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get bankTransfer;

  /// No description provided for @payAtStore2.
  ///
  /// In en, this message translates to:
  /// **'Pay at Store'**
  String get payAtStore2;

  /// No description provided for @customerPlace.
  ///
  /// In en, this message translates to:
  /// **'Customer place:'**
  String get customerPlace;

  /// No description provided for @orderNotePickupTime.
  ///
  /// In en, this message translates to:
  /// **'Order Note / Pickup Time:'**
  String get orderNotePickupTime;

  /// No description provided for @openMap.
  ///
  /// In en, this message translates to:
  /// **'Open map'**
  String get openMap;

  /// No description provided for @callCustomer.
  ///
  /// In en, this message translates to:
  /// **'Call Customer?'**
  String get callCustomer;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @currentOrders.
  ///
  /// In en, this message translates to:
  /// **'Current Orders'**
  String get currentOrders;

  /// No description provided for @orderHistory.
  ///
  /// In en, this message translates to:
  /// **'Order History'**
  String get orderHistory;

  /// No description provided for @ordersByStatus.
  ///
  /// In en, this message translates to:
  /// **'Orders by Status'**
  String get ordersByStatus;

  /// No description provided for @totalOrders.
  ///
  /// In en, this message translates to:
  /// **'Total Orders'**
  String get totalOrders;

  /// No description provided for @totalRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total Revenue'**
  String get totalRevenue;

  /// No description provided for @onTheWay.
  ///
  /// In en, this message translates to:
  /// **'On The Way'**
  String get onTheWay;

  /// No description provided for @noCurrentOrders.
  ///
  /// In en, this message translates to:
  /// **'No current orders'**
  String get noCurrentOrders;

  /// No description provided for @noHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get noHistoryYet;

  /// No description provided for @activeOrdersWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Active orders will appear here'**
  String get activeOrdersWillAppearHere;

  /// No description provided for @completedOrdersWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Completed orders will appear here'**
  String get completedOrdersWillAppearHere;

  /// No description provided for @actionFailedPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Action failed. Please try again.'**
  String get actionFailedPleaseTryAgain;

  /// No description provided for @chatWithCustomer.
  ///
  /// In en, this message translates to:
  /// **'Chat with Customer'**
  String get chatWithCustomer;

  /// No description provided for @navigateInApp.
  ///
  /// In en, this message translates to:
  /// **'Navigate (In App)'**
  String get navigateInApp;

  /// No description provided for @openInGoogleMapsApp.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps App'**
  String get openInGoogleMapsApp;

  /// No description provided for @deliveryTarget.
  ///
  /// In en, this message translates to:
  /// **'Delivery Target'**
  String get deliveryTarget;

  /// No description provided for @youRider.
  ///
  /// In en, this message translates to:
  /// **'You (Rider)'**
  String get youRider;

  /// No description provided for @callCustomer2.
  ///
  /// In en, this message translates to:
  /// **'Call Customer'**
  String get callCustomer2;

  /// No description provided for @refreshRoute.
  ///
  /// In en, this message translates to:
  /// **'Refresh route'**
  String get refreshRoute;

  /// No description provided for @fitRouteOnScreen.
  ///
  /// In en, this message translates to:
  /// **'Fit route on screen'**
  String get fitRouteOnScreen;

  /// No description provided for @openInExternalGoogleMapsApp.
  ///
  /// In en, this message translates to:
  /// **'Open in External Google Maps app'**
  String get openInExternalGoogleMapsApp;

  /// No description provided for @couldNotLaunchDialer.
  ///
  /// In en, this message translates to:
  /// **'Could not launch dialer'**
  String get couldNotLaunchDialer;

  /// No description provided for @couldNotLaunchExternalMapsApplication.
  ///
  /// In en, this message translates to:
  /// **'Could not launch external maps application'**
  String get couldNotLaunchExternalMapsApplication;

  /// No description provided for @statusUpdatedToArrived.
  ///
  /// In en, this message translates to:
  /// **'Status updated to Arrived'**
  String get statusUpdatedToArrived;

  /// No description provided for @statusUpdatedToCompleteDelivered.
  ///
  /// In en, this message translates to:
  /// **'Status updated to Complete / Delivered'**
  String get statusUpdatedToCompleteDelivered;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @startTheConversationBelow.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation below'**
  String get startTheConversationBelow;

  /// No description provided for @typeAMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message…'**
  String get typeAMessage;

  /// No description provided for @sendImage.
  ///
  /// In en, this message translates to:
  /// **'Send Image'**
  String get sendImage;

  /// No description provided for @sendImage2.
  ///
  /// In en, this message translates to:
  /// **'Send image'**
  String get sendImage2;

  /// No description provided for @takeAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takeAPhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @addACaptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Add a caption (optional)'**
  String get addACaptionOptional;

  /// No description provided for @imageReadyToSend.
  ///
  /// In en, this message translates to:
  /// **'Image ready to send'**
  String get imageReadyToSend;

  /// No description provided for @couldNotLoadImage.
  ///
  /// In en, this message translates to:
  /// **'Could not load image'**
  String get couldNotLoadImage;

  /// No description provided for @couldNotLoadMessages.
  ///
  /// In en, this message translates to:
  /// **'Could not load messages.'**
  String get couldNotLoadMessages;

  /// No description provided for @failedToSendImagePleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Failed to send image. Please try again.'**
  String get failedToSendImagePleaseTry;

  /// No description provided for @failedToSendMessagePleaseTry.
  ///
  /// In en, this message translates to:
  /// **'Failed to send message. Please try again.'**
  String get failedToSendMessagePleaseTry;

  /// No description provided for @sendingImage.
  ///
  /// In en, this message translates to:
  /// **'📷 Sending image…'**
  String get sendingImage;

  /// No description provided for @printers.
  ///
  /// In en, this message translates to:
  /// **'Printers'**
  String get printers;

  /// No description provided for @addPrinter.
  ///
  /// In en, this message translates to:
  /// **'Add Printer'**
  String get addPrinter;

  /// No description provided for @deletePrinter.
  ///
  /// In en, this message translates to:
  /// **'Delete Printer'**
  String get deletePrinter;

  /// No description provided for @printerSaved.
  ///
  /// In en, this message translates to:
  /// **'Printer saved'**
  String get printerSaved;

  /// No description provided for @printerDeleted.
  ///
  /// In en, this message translates to:
  /// **'Printer deleted'**
  String get printerDeleted;

  /// No description provided for @printerTestSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Printer test successful.'**
  String get printerTestSuccessful;

  /// No description provided for @printerTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Printer test failed.'**
  String get printerTestFailed;

  /// No description provided for @printTest.
  ///
  /// In en, this message translates to:
  /// **'Print Test'**
  String get printTest;

  /// No description provided for @printerIpAddress.
  ///
  /// In en, this message translates to:
  /// **'Printer IP address'**
  String get printerIpAddress;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @paperWidth.
  ///
  /// In en, this message translates to:
  /// **'Paper width'**
  String get paperWidth;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced settings'**
  String get advancedSettings;

  /// No description provided for @categoryRouting.
  ///
  /// In en, this message translates to:
  /// **'Category routing'**
  String get categoryRouting;

  /// No description provided for @noCategoriesFound.
  ///
  /// In en, this message translates to:
  /// **'No categories found'**
  String get noCategoriesFound;

  /// No description provided for @ifNoneSelectedAllCategoriesWill.
  ///
  /// In en, this message translates to:
  /// **'If none selected, all categories will print on this printer.'**
  String get ifNoneSelectedAllCategoriesWill;

  /// No description provided for @printReceiptsAndBills.
  ///
  /// In en, this message translates to:
  /// **'Print receipts and bills'**
  String get printReceiptsAndBills;

  /// No description provided for @printOrders.
  ///
  /// In en, this message translates to:
  /// **'Print orders'**
  String get printOrders;

  /// No description provided for @defaultPrinterForReceipts.
  ///
  /// In en, this message translates to:
  /// **'Default printer for receipts'**
  String get defaultPrinterForReceipts;

  /// No description provided for @printSingleItemPerOrderTicket.
  ///
  /// In en, this message translates to:
  /// **'Print single item per order ticket'**
  String get printSingleItemPerOrderTicket;

  /// No description provided for @groupIdenticalItemsInOrderTickets.
  ///
  /// In en, this message translates to:
  /// **'Group identical items in order tickets'**
  String get groupIdenticalItemsInOrderTickets;

  /// No description provided for @noPrintersYet.
  ///
  /// In en, this message translates to:
  /// **'No printers yet'**
  String get noPrintersYet;

  /// No description provided for @tapToAddYourFirstPrinter.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first printer.\nConfigure receipts, orders, and categories.'**
  String get tapToAddYourFirstPrinter;

  /// No description provided for @receipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receipt;

  /// No description provided for @billPreReceipt.
  ///
  /// In en, this message translates to:
  /// **'Bill (pre-receipt)'**
  String get billPreReceipt;

  /// No description provided for @receiptPaid.
  ///
  /// In en, this message translates to:
  /// **'Receipt (paid)'**
  String get receiptPaid;

  /// No description provided for @kitchenOrderTicket.
  ///
  /// In en, this message translates to:
  /// **'Kitchen / Order Ticket'**
  String get kitchenOrderTicket;

  /// No description provided for @kitchenOrderTicket2.
  ///
  /// In en, this message translates to:
  /// **'Kitchen / Order ticket'**
  String get kitchenOrderTicket2;

  /// No description provided for @refundVoid.
  ///
  /// In en, this message translates to:
  /// **'Refund / Void'**
  String get refundVoid;

  /// No description provided for @savedTemplateSettings.
  ///
  /// In en, this message translates to:
  /// **'Saved template settings.'**
  String get savedTemplateSettings;

  /// No description provided for @noTemplateSelectedPreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No template selected — preview unavailable'**
  String get noTemplateSelectedPreviewUnavailable;

  /// No description provided for @adminReports.
  ///
  /// In en, this message translates to:
  /// **'Admin Reports'**
  String get adminReports;

  /// No description provided for @allBranches.
  ///
  /// In en, this message translates to:
  /// **'All branches'**
  String get allBranches;

  /// No description provided for @selectDateRange.
  ///
  /// In en, this message translates to:
  /// **'Select date range'**
  String get selectDateRange;

  /// No description provided for @salesByDate.
  ///
  /// In en, this message translates to:
  /// **'Sales by date'**
  String get salesByDate;

  /// No description provided for @salesByPaymentType.
  ///
  /// In en, this message translates to:
  /// **'Sales by payment type'**
  String get salesByPaymentType;

  /// No description provided for @salesByProductTop.
  ///
  /// In en, this message translates to:
  /// **'Sales by product (top)'**
  String get salesByProductTop;

  /// No description provided for @paymentType.
  ///
  /// In en, this message translates to:
  /// **'Payment type'**
  String get paymentType;

  /// No description provided for @peakOrderHours.
  ///
  /// In en, this message translates to:
  /// **'Peak order hours'**
  String get peakOrderHours;

  /// No description provided for @noHourlyPeakDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No hourly peak data available'**
  String get noHourlyPeakDataAvailable;

  /// No description provided for @noOrderTrafficRecordedInThis.
  ///
  /// In en, this message translates to:
  /// **'No order traffic recorded in this range.'**
  String get noOrderTrafficRecordedInThis;

  /// No description provided for @branchRanking.
  ///
  /// In en, this message translates to:
  /// **'Branch ranking'**
  String get branchRanking;

  /// No description provided for @forbiddenAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'Forbidden (admin only)'**
  String get forbiddenAdminOnly;

  /// No description provided for @cannotLoadRanking.
  ///
  /// In en, this message translates to:
  /// **'Cannot load ranking'**
  String get cannotLoadRanking;

  /// No description provided for @climbTheAdventureLadder.
  ///
  /// In en, this message translates to:
  /// **'Climb the adventure ladder!'**
  String get climbTheAdventureLadder;

  /// No description provided for @yourRank.
  ///
  /// In en, this message translates to:
  /// **'Your rank: -'**
  String get yourRank;

  /// No description provided for @enterPinToUnlock.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN to unlock'**
  String get enterPinToUnlock;

  /// No description provided for @createYour4DigitPin.
  ///
  /// In en, this message translates to:
  /// **'Create your 4-digit PIN'**
  String get createYour4DigitPin;

  /// No description provided for @confirmYourNewPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm your new PIN'**
  String get confirmYourNewPin;

  /// No description provided for @incorrectPin.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN'**
  String get incorrectPin;

  /// No description provided for @pinMismatchOrSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'PIN mismatch or save failed'**
  String get pinMismatchOrSaveFailed;

  /// No description provided for @switchUser.
  ///
  /// In en, this message translates to:
  /// **'Switch User'**
  String get switchUser;

  /// No description provided for @setPosName.
  ///
  /// In en, this message translates to:
  /// **'Set POS Name'**
  String get setPosName;

  /// No description provided for @posNameExCounter1Ipad.
  ///
  /// In en, this message translates to:
  /// **'POS name (ex: Counter-1, iPad-Bar, Android-Front)'**
  String get posNameExCounter1Ipad;

  /// No description provided for @pleaseEnterAPosName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a POS name'**
  String get pleaseEnterAPosName;

  /// No description provided for @posNameIsTooShort.
  ///
  /// In en, this message translates to:
  /// **'POS name is too short'**
  String get posNameIsTooShort;

  /// No description provided for @posNameIsTooLong.
  ///
  /// In en, this message translates to:
  /// **'POS name is too long'**
  String get posNameIsTooLong;

  /// No description provided for @thisHelpsTrackWhichDeviceWas.
  ///
  /// In en, this message translates to:
  /// **'This helps track which device was used when something happens.'**
  String get thisHelpsTrackWhichDeviceWas;

  /// No description provided for @refreshingMenusTablesAndSalesData.
  ///
  /// In en, this message translates to:
  /// **'Refreshing menus, tables, and sales data for this device'**
  String get refreshingMenusTablesAndSalesData;

  /// No description provided for @returnToLogin.
  ///
  /// In en, this message translates to:
  /// **'Return to Login'**
  String get returnToLogin;

  /// No description provided for @networkErrorAndNoOfflineCache.
  ///
  /// In en, this message translates to:
  /// **'Network error and no offline cache available.\nPlease connect to the internet.'**
  String get networkErrorAndNoOfflineCache;

  /// No description provided for @maintenanceMode.
  ///
  /// In en, this message translates to:
  /// **'Maintenance Mode'**
  String get maintenanceMode;

  /// No description provided for @reachTheAdmin.
  ///
  /// In en, this message translates to:
  /// **'Reach the admin'**
  String get reachTheAdmin;

  /// No description provided for @useTheOptionsYourStoreHas.
  ///
  /// In en, this message translates to:
  /// **'Use the options your store has enabled in Odoo.'**
  String get useTheOptionsYourStoreHas;

  /// No description provided for @openFacebook.
  ///
  /// In en, this message translates to:
  /// **'Open Facebook'**
  String get openFacebook;

  /// No description provided for @openInWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Open in WhatsApp'**
  String get openInWhatsapp;

  /// No description provided for @notConfiguredAskStaffToSet.
  ///
  /// In en, this message translates to:
  /// **'Not configured. Ask staff to set the Facebook URL in Odoo (Customer support).'**
  String get notConfiguredAskStaffToSet;

  /// No description provided for @notConfiguredAskStaffToSet2.
  ///
  /// In en, this message translates to:
  /// **'Not configured. Ask staff to set the WhatsApp number in Odoo (Customer support).'**
  String get notConfiguredAskStaffToSet2;

  /// No description provided for @ladolcePrivacy.
  ///
  /// In en, this message translates to:
  /// **'LaDolce Privacy'**
  String get ladolcePrivacy;

  /// No description provided for @failedToLoadPrivacyPolicyPlease.
  ///
  /// In en, this message translates to:
  /// **'Failed to load Privacy Policy. Please check your network connection and try again.'**
  String get failedToLoadPrivacyPolicyPlease;

  /// No description provided for @orderItems.
  ///
  /// In en, this message translates to:
  /// **'ORDER ITEMS'**
  String get orderItems;

  /// No description provided for @transferProof.
  ///
  /// In en, this message translates to:
  /// **'TRANSFER PROOF'**
  String get transferProof;

  /// No description provided for @noLineItems.
  ///
  /// In en, this message translates to:
  /// **'No line items'**
  String get noLineItems;

  /// No description provided for @waitingReview.
  ///
  /// In en, this message translates to:
  /// **'Waiting review'**
  String get waitingReview;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'COMPLETE'**
  String get complete;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'DELIVERED'**
  String get delivered;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'CANCELLED'**
  String get cancelled;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'⚡ OFFLINE'**
  String get offline;

  /// No description provided for @removeCoupon.
  ///
  /// In en, this message translates to:
  /// **'Remove coupon'**
  String get removeCoupon;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addNote;

  /// No description provided for @noteForKitchen.
  ///
  /// In en, this message translates to:
  /// **'Note for the kitchen'**
  String get noteForKitchen;

  /// No description provided for @tapItemToAddNote.
  ///
  /// In en, this message translates to:
  /// **'Tap an item to add a note'**
  String get tapItemToAddNote;

  /// No description provided for @proofUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Order placed, but the transfer proof could not be uploaded. Please show it to the staff.'**
  String get proofUploadFailed;
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
