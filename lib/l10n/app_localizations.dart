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
