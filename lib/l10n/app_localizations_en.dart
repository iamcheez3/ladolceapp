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

  @override
  String get apply => 'Apply';

  @override
  String get save => 'Save';

  @override
  String get clear => 'Clear';

  @override
  String get done => 'Done';

  @override
  String get retry => 'Retry';

  @override
  String get unknown => 'Unknown';

  @override
  String get free => 'Free';

  @override
  String errorWithMessage(String error) {
    return 'Error: $error';
  }

  @override
  String get featureComingSoon => 'Feature coming soon!';

  @override
  String get allItems => 'All Items';

  @override
  String get combos => 'Combos';

  @override
  String get searchProducts => 'Search products...';

  @override
  String noProductsMatching(String query) {
    return 'No products matching \"$query\"';
  }

  @override
  String get noProductsInCategory => 'No products in this category';

  @override
  String get applyDiscount => 'Apply Discount';

  @override
  String get selectDiscountOption => 'Select Discount Option';

  @override
  String get selectDiscount => 'Select Discount';

  @override
  String get noDiscount => 'No Discount';

  @override
  String get customPercent => '(Custom %)';

  @override
  String get customAmount => '(Custom Amount)';

  @override
  String get enterDiscountPercentage => 'Enter Discount Percentage';

  @override
  String get enterDiscountAmount => 'Enter Discount Amount';

  @override
  String get removeDiscount => 'Remove Discount';

  @override
  String get discountValueOption => 'Discount (Value)';

  @override
  String percentOff(String percent) {
    return '$percent% Off';
  }

  @override
  String get egTen => 'e.g. 10';

  @override
  String get egFiveThousand => 'e.g. 5000';

  @override
  String get kitchenNote => 'Kitchen note';

  @override
  String get kitchenNoteHint => 'Less sugar, no ice, extra spicy...';

  @override
  String selectToppingsFor(String product) {
    return 'Select Toppings for $product';
  }

  @override
  String get addWithoutToppings => 'Add Without Toppings';

  @override
  String get addToOrder => 'Add To Order';

  @override
  String get tickets => 'Tickets';

  @override
  String get openTickets => 'Open Tickets';

  @override
  String get ticketLabel => 'Ticket';

  @override
  String get ticketOptions => 'Ticket Options';

  @override
  String get clearTicket => 'Clear ticket';

  @override
  String get printBill => 'Print bill';

  @override
  String get reprintOrderKitchen => 'Reprint order (kitchen)';

  @override
  String get splitTicketAction => 'Split ticket';

  @override
  String get moveTicketAction => 'Move ticket';

  @override
  String get sendToRider => 'Send to rider';

  @override
  String get openCashDrawer => 'Open cash drawer';

  @override
  String get syncAction => 'Sync';

  @override
  String get scanVoucher => 'Scan Voucher';

  @override
  String get switchToList => 'Switch to List';

  @override
  String get switchToGrid => 'Switch to Grid';

  @override
  String get ticketCleared => 'Ticket cleared.';

  @override
  String get ticketRemovedByAdminPin => 'Ticket removed by Admin PIN.';

  @override
  String cannotClearTicket(String error) {
    return 'Cannot clear ticket: $error';
  }

  @override
  String get adminPinRequired => 'Admin PIN Required';

  @override
  String get enterPinToClearTicket => 'Enter PIN to clear selected ticket';

  @override
  String get pinIsRequired => 'PIN is required';

  @override
  String get currentTicket => 'CURRENT TICKET';

  @override
  String itemsCount(String count) {
    return '$count Items';
  }

  @override
  String get viewTicketCharge => 'View Ticket &\nCharge';

  @override
  String get ticketSavedNoNewItems => 'Ticket saved (no new items added).';

  @override
  String ticketUpdatedWithItems(String name, String count) {
    return 'Ticket $name updated with $count new item(s)!';
  }

  @override
  String get noItemsToPrint => 'No items in the current ticket to print.';

  @override
  String get noPrinterConfiguredSettings =>
      'No printer configured. Set up a printer in Settings first.';

  @override
  String get noPrinterConfigured =>
      'No printer configured. Set up a printer first.';

  @override
  String get amountExclVat => 'Amount (excl. VAT):';

  @override
  String vatPercentLabel(String percent) {
    return 'VAT ($percent%):';
  }

  @override
  String get billPrinted => '🧾 Bill printed!';

  @override
  String get failedToPrintBill =>
      'Failed to print bill. Check printer connection.';

  @override
  String get noItemsToReprint => 'No items in the current ticket to reprint.';

  @override
  String orderReprinted(String count) {
    return '🖨️ Order reprinted to $count kitchen printer(s).';
  }

  @override
  String get noPrinterForReprint =>
      'No available printer could print this reprint request.';

  @override
  String get cashDrawerOpened => '🗃️ Cash drawer opened!';

  @override
  String get failedToOpenDrawer =>
      'Failed to open drawer. Check printer connection.';

  @override
  String get noItemsToSplit => 'No items in the current ticket to split.';

  @override
  String get saveTicketBeforeSplit =>
      'Please save the ticket first before splitting.';

  @override
  String ticketSplitCreated(String name) {
    return 'Ticket split! \"$name\" created.';
  }

  @override
  String splitError(String error) {
    return 'Split error: $error';
  }

  @override
  String cannotLoadOpenTickets(String error) {
    return 'Cannot load open tickets: $error';
  }

  @override
  String get noOpenTicketToMoveFrom => 'No open ticket to move from.';

  @override
  String get noDestinationAvailable =>
      'No destination available. Open another ticket or free a table.';

  @override
  String get moveTicketTitle => 'Move Ticket';

  @override
  String get selectSourceTicket => 'Select source ticket';

  @override
  String tableNumber(String id) {
    return 'Table $id';
  }

  @override
  String get noTable => 'No table';

  @override
  String get moveDestination => 'Move destination';

  @override
  String get openTicketLabel => 'Open ticket';

  @override
  String get emptyTable => 'Empty table';

  @override
  String get moveNow => 'Move Now';

  @override
  String get sourceTicketGone => 'Source ticket no longer exists.';

  @override
  String get selectDestinationFirst =>
      'Please select a destination ticket or table.';

  @override
  String get sourceHasNoItems => 'Source ticket has no items to move.';

  @override
  String get destinationTicketGone => 'Destination ticket no longer exists.';

  @override
  String movedItemsTo(String source, String destination) {
    return 'Moved items from ticket #$source to $destination';
  }

  @override
  String moveTicketFailed(String error) {
    return 'Move ticket failed: $error';
  }

  @override
  String destTicketRef(String id) {
    return 'ticket #$id';
  }

  @override
  String destTableRef(String id) {
    return 'table #$id (new ticket)';
  }

  @override
  String sourceTotalItems(String total, String count) {
    return 'Source total: ₭$total\nItems: $count';
  }

  @override
  String cannotLoadRiders(String error) {
    return 'Cannot load riders: $error';
  }

  @override
  String get noRidersAvailable => 'No riders available for this branch.';

  @override
  String get selectRider => 'Select Rider';

  @override
  String orderForCustomer(String name) {
    return 'Order for: $name';
  }

  @override
  String deliveryToPlace(String place) {
    return 'Delivery to: $place';
  }

  @override
  String get selfOrderDelivery => 'Self-order delivery';

  @override
  String get unnamed => 'Unnamed';

  @override
  String orderSentToRider(String rider) {
    return 'Order sent to $rider';
  }

  @override
  String failedToAssignRider(String error) {
    return 'Failed to assign rider: $error';
  }

  @override
  String customerSelected(String name) {
    return 'Customer $name selected!';
  }

  @override
  String get charge => 'Charge';

  @override
  String get totalAmount => 'Total Amount';

  @override
  String get selectPaymentMethod => 'Select Payment Method';

  @override
  String get noPaymentMethods => 'No payment methods configured.';

  @override
  String get amountReceived => 'Amount Received';

  @override
  String get changeDue => 'Change Due:';

  @override
  String chargeAmount(String amount) {
    return 'CHARGE K$amount';
  }

  @override
  String get orderPaidSuccessfully => 'Order Paid Successfully!';

  @override
  String transferTicketFixedTo(String method) {
    return 'Transfer ticket: fixed to $method.';
  }

  @override
  String get transferTicketFixed => 'Transfer ticket: payment method is fixed.';

  @override
  String get administrator => 'Administrator';

  @override
  String get posTerminal => 'POS Terminal';

  @override
  String get sales => 'Sales';

  @override
  String get receipts => 'Receipts';

  @override
  String get selfOrdersReview => 'Self Orders Review';

  @override
  String get itemsMenu => 'Items';

  @override
  String get settings => 'Settings';

  @override
  String get lockSwitchUser => 'Lock / Switch User';

  @override
  String get demoCashier => 'Demo Cashier';

  @override
  String get selectTable => 'Select Table';

  @override
  String get chooseLocationNewTicket =>
      'Choose a location to open a new ticket';

  @override
  String get noTablesAvailable => 'No tables available.\nPlease sync catalog.';

  @override
  String get tableAvailable => 'Available';

  @override
  String get tableOpen => 'Open';

  @override
  String get tableOccupied => 'Occupied';

  @override
  String get openOrder => 'Open Order';

  @override
  String ticketOpenedAt(String table) {
    return 'Ticket opened at $table!';
  }

  @override
  String get rewardClaimed => 'Reward Claimed!';

  @override
  String voucherCustomer(String name) {
    return 'Customer: $name';
  }

  @override
  String voucherProduct(String name) {
    return 'Product: $name';
  }

  @override
  String get giveItemToCustomer => 'Please give this item to the customer.';

  @override
  String get claimRewardVoucher => 'Claim Reward Voucher';

  @override
  String get enterOrScanVoucher =>
      'Enter or scan the customer\'s reward voucher code:';

  @override
  String get voucherCode => 'Voucher Code';

  @override
  String get claim => 'Claim';

  @override
  String syncedOfflineOrders(String count) {
    return '✅ Synced $count offline orders to server.';
  }

  @override
  String get syncedAllData => '✅ Synced all data.';

  @override
  String syncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get newSelfOrderWaiting => 'New self order waiting review';

  @override
  String newSelfOrderWaitingCount(String count) {
    return 'New self order waiting review ($count pending)';
  }

  @override
  String newSelfOrderDetail(String summary) {
    return 'New self order: $summary';
  }

  @override
  String newSelfOrdersCount(String count, String detail) {
    return '$count new self orders: $detail';
  }

  @override
  String get english => 'English';

  @override
  String get laoLanguage => 'Lao';

  @override
  String get chooseAppLanguage => 'Choose the app language';

  @override
  String get appSettings => 'App Settings';

  @override
  String get printerConfiguration => 'Printer Configuration';

  @override
  String printersConfigured(String count) {
    return '$count printer(s) configured';
  }

  @override
  String connectedTo(String ip) {
    return 'Connected: $ip';
  }

  @override
  String get notConfigured => 'Not configured';

  @override
  String get billTemplates => 'Bill Templates';

  @override
  String get billTemplatesSubtitle =>
      'Select bill/receipt/refund templates for this branch';

  @override
  String get discountConfiguration => 'Discount Configuration';

  @override
  String discountOptionsConfigured(String count) {
    return '$count discount option(s) configured';
  }

  @override
  String get usePromotionPrice => 'Use Promotion Price in POS';

  @override
  String get promotionalPricesApplied => 'Promotional prices will be applied';

  @override
  String get normalPricesApplied => 'Normal base prices will be applied';

  @override
  String get sessionExpired => 'Session expired. Please login again.';

  @override
  String get close => 'Close';

  @override
  String get add => 'Add';

  @override
  String get delete => 'Delete';

  @override
  String get refresh => 'Refresh';

  @override
  String get optional => 'Optional';

  @override
  String get total => 'Total';

  @override
  String get status => 'Status';

  @override
  String get date => 'Date';

  @override
  String get quantity => 'Quantity';

  @override
  String get selectedLocation => 'Selected location';

  @override
  String get couldNotSearchPlaces =>
      'Could not search for places. Please check your connection.';

  @override
  String get couldNotReadAddress =>
      'Could not read the selected address. Please try again.';

  @override
  String get addFavoritePlace => 'Add favorite place';

  @override
  String get searchAddressOrPlace => 'Search address or place';

  @override
  String get nameThisPlace => 'Name this place, e.g. House';

  @override
  String get placeHouse => 'House';

  @override
  String get placeWork => 'Work';

  @override
  String get placeFriendHouse => 'Friend house';

  @override
  String get locationServicesDisabled =>
      'Location services are disabled. Please enable them in Settings.';

  @override
  String get locationPermissionDenied => 'Location permission denied.';

  @override
  String get locationPermissionPermanentlyDenied =>
      'Location permission permanently denied. Please enable it in Settings.';

  @override
  String get couldNotGetLocation =>
      'Could not get current location. Please allow location access and try again.';

  @override
  String get moveMapToPlacePin => 'Move the map to place the pin';

  @override
  String get readingSelectedAddress => 'Reading selected address...';

  @override
  String get addSelectedPlace => 'Add selected place';

  @override
  String get addDeliveryPlaces => 'Add delivery places for self order';

  @override
  String get favoritePlaces => 'Favorite places';

  @override
  String get noFavoritePlaces => 'No favorite places saved yet.';

  @override
  String get deletePlaceTitle => 'Delete place?';

  @override
  String removePlaceConfirm(String name) {
    return 'Remove \"$name\" from your favorites?';
  }

  @override
  String placeSavedCount(String label, String count) {
    return '$label  •  $count saved';
  }

  @override
  String get profileImageUpdated => 'Profile image updated';

  @override
  String get couldNotOpenImagePicker =>
      'Could not open the image picker. Please try again.';

  @override
  String get noQrImageConfigured => 'No QR image configured yet';

  @override
  String get photosPermissionBlocked =>
      'Photos permission is blocked. Open Settings to allow access.';

  @override
  String get photoPermissionRequired =>
      'Photo permission is required to save QR';

  @override
  String get storagePermissionRequired =>
      'Storage permission is required to save QR';

  @override
  String get qrSavedToGallery => 'QR saved to gallery ✓';

  @override
  String get couldNotSaveQr => 'Could not save QR code. Please try again.';

  @override
  String get cannotFindSaveDirectory => 'Cannot find save directory';

  @override
  String get couldNotSaveQrDownloads =>
      'Could not save QR to Downloads. Please try again.';

  @override
  String qrSavedTo(String path) {
    return 'QR saved to $path';
  }

  @override
  String get itemRunOut => 'This item is run out and cannot be ordered.';

  @override
  String get couponApplied => 'Coupon applied successfully!';

  @override
  String get phoneNumberRequiredTitle => 'Phone Number Required';

  @override
  String get verifiedPhoneRequired =>
      'A verified phone number is required before placing an order. Please update your profile.';

  @override
  String get updateProfile => 'Update Profile';

  @override
  String get branchClosed =>
      'This branch is currently closed. Please choose another branch or order later.';

  @override
  String get howReceiveOrder => 'How will you receive your order?';

  @override
  String get riderDelivery => 'Rider delivery';

  @override
  String get comePickUpMyself => 'Come pick up myself';

  @override
  String get deliveryPlace => 'Delivery place';

  @override
  String get addFavoritePlaceBeforeOrder =>
      'Please add a favorite place before confirming the order.';

  @override
  String get selectDeliveryPlace => 'Select a delivery place';

  @override
  String get paymentBreakdown => 'Payment Breakdown';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get discount => 'Discount';

  @override
  String get pointsRequired => 'Points Required';

  @override
  String get totalPayment => 'Total Payment';

  @override
  String deliveryFeeKm(String km) {
    return 'Delivery Fee ($km km)';
  }

  @override
  String addMoreForFreeDelivery(String amount) {
    return 'Add ₭$amount more to get free delivery!';
  }

  @override
  String get notEnoughPointsRedeem =>
      'Not enough points to redeem these items.';

  @override
  String get payTransfer => 'Transfer';

  @override
  String get payAtStore => 'Pay At Store';

  @override
  String get orderCreatedProofUploaded =>
      'Order created. Transfer proof uploaded.';

  @override
  String get orderCreatedProofLocal =>
      'Order created. Transfer proof saved locally.';

  @override
  String get orderCreatedPayAtStore =>
      'Order created. Please pay at the store.';

  @override
  String get failedToPlaceOrder =>
      'Failed to place order. Please check your connection and try again.';

  @override
  String get phoneNumberRequiredLower => 'Phone number required';

  @override
  String get addPhoneBeforeOrder =>
      'Please add your phone number before placing an order. This is required for customer verification and so the store can contact you if needed.';

  @override
  String get addPhone => 'Add phone';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get couldNotSaveProfileConnection =>
      'Could not save profile. Please check your connection and try again.';

  @override
  String get couldNotSaveProfile => 'Could not save profile. Please try again.';

  @override
  String get deleteAccountTitle => 'Delete account?';

  @override
  String get accountDeleted => 'Your account has been deleted.';

  @override
  String get couldNotDeleteAccount =>
      'Could not delete account. Please try again.';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get fullNameCaps => 'FULL NAME';

  @override
  String get yourFullName => 'Your Full Name';

  @override
  String get phoneCaps => 'PHONE';

  @override
  String get phoneExample => 'e.g. 20XXXXXXXX';

  @override
  String get dateOfBirthCaps => 'DATE OF BIRTH';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get phoneNumberIsRequired => 'Phone number is required';

  @override
  String get phoneMustStartWith20 =>
      'Phone number must start with 20 and be exactly 10 digits long (e.g. 20XXXXXXXX)';

  @override
  String get verifyAndSave => 'VERIFY & SAVE';

  @override
  String get otpVerificationFailed => 'OTP verification failed';

  @override
  String get failedToResendOtp => 'Failed to resend OTP';

  @override
  String get logout => 'Logout';

  @override
  String get loggingOut => 'Logging out...';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deletingAccount => 'Deleting account...';

  @override
  String get clientIdCopied => 'Client ID copied to clipboard!';

  @override
  String rewardPointsLabel(String points) {
    return 'Reward points: $points';
  }

  @override
  String get rewardsCatalog => 'Rewards Catalog';

  @override
  String get noRewardsAvailable => 'No rewards available at the moment.';

  @override
  String get notEnoughPoints => 'Not enough points!';

  @override
  String get redeemRewardTitle => 'Redeem Reward?';

  @override
  String redeemConfirm(String points, String product) {
    return 'Do you want to convert $points points into a voucher for $product?';
  }

  @override
  String get customerNotLoggedIn => 'Customer not logged in properly.';

  @override
  String get voucherCreated => 'Voucher created successfully!';

  @override
  String get redeem => 'Redeem';

  @override
  String get claimedSuccessfully => 'Claimed Successfully!';

  @override
  String get rewardClaimedEnjoy => 'Your reward has been claimed. Enjoy!';

  @override
  String get scanQrAtCounter =>
      'Scan this QR code at the counter to claim your reward.';

  @override
  String get myVouchers => 'My Vouchers';

  @override
  String get notLoggedIn => 'Not logged in.';

  @override
  String get voucherActive => 'ACTIVE';

  @override
  String get redeemPoints => 'Redeem points';

  @override
  String get convertPointsIntoItems => 'Convert your points into free items';

  @override
  String get viewClaimVouchers => 'View and claim your saved vouchers';

  @override
  String get ranking => 'Ranking';

  @override
  String get seeTop50 => 'See Top 50 rewards leaderboard';

  @override
  String get customerSupport => 'Customer support';

  @override
  String get supportChannels => 'Facebook & WhatsApp (from store settings)';

  @override
  String pointsSuffix(String points) {
    return '$points Pts';
  }

  @override
  String get couldNotUpdateNotifications =>
      'Could not update notification settings. Please try again.';

  @override
  String get notifications => 'Notifications';

  @override
  String get orderUpdatesOnDevice => 'Order updates on this device';

  @override
  String get pushAlertsOff => 'Push alerts are turned off';

  @override
  String get customization => 'Customization';

  @override
  String get totalPrice => 'Total Price';

  @override
  String get addToCart => 'Add to Cart';

  @override
  String get navHome => 'Home';

  @override
  String get navCart => 'Cart';

  @override
  String get navHistory => 'History';

  @override
  String get navProfile => 'Profile';

  @override
  String get errorLoadingProducts => 'Error loading products';

  @override
  String get allProducts => 'All Products';

  @override
  String get noItemsFound => 'No items found';

  @override
  String get recommendedProducts => 'Recommended Products';

  @override
  String get recommendedBadge => '⭐ Recommended';

  @override
  String get mostPopular => 'Most Popular';

  @override
  String get freshPicksToday => 'Fresh picks for you today';

  @override
  String get bestSeller => 'Best Seller';

  @override
  String get promoBadge => 'PROMO';

  @override
  String get selectItemToPreview => 'Select an item\nto preview';

  @override
  String get noToppingsSelected => 'No Toppings Selected';

  @override
  String toppingsFor(String product) {
    return 'Toppings for $product';
  }

  @override
  String get cartEmpty => 'Your cart is empty';

  @override
  String get addItemsFromHome => 'Add items from Home';

  @override
  String get enterCouponCode => 'Enter coupon code';

  @override
  String get couponApplied2 => 'Applied';

  @override
  String get checkout => 'Checkout';

  @override
  String addedToCart(String name) {
    return '$name added to cart';
  }

  @override
  String addedToCartQty(String qty, String name) {
    return '$qty $name added to cart';
  }

  @override
  String discountWithCode(String code) {
    return 'Discount ($code)';
  }

  @override
  String get noOrderHistory => 'No order history yet';

  @override
  String get completedOrdersHere => 'Your completed orders will show up here.';

  @override
  String get paymentMethodLabel => 'Payment method';

  @override
  String get trackRider => 'Track Rider';

  @override
  String get viewChatHistory => 'View Chat History';

  @override
  String get chatWithRider => 'Chat with Rider';

  @override
  String get viewOrderDetails => 'View order details';

  @override
  String get statusComplete => 'Complete';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusRiderArrived => 'Rider arrived';

  @override
  String get statusOnTheWay => 'On the way';

  @override
  String get statusPreparing => 'Preparing';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusWaitingTransfer => 'Waiting transfer verification';

  @override
  String get statusOrderConfirmed => 'Order confirmed';

  @override
  String get statusRiderOnWay => 'Rider is on the way';

  @override
  String get statusPreparingYourOrder => 'Preparing your order';

  @override
  String get statusTransferVerified => 'Transfer verified, preparing order';

  @override
  String get statusArrived => 'Arrived';

  @override
  String get deliveryProgress => 'Delivery progress';

  @override
  String get arrivingSoon => 'Arriving soon';

  @override
  String get deliveryLocation => 'Delivery location';

  @override
  String get liveRiderTracking => 'Live Rider Tracking';

  @override
  String get liveBadge => 'LIVE';

  @override
  String get fetchingRiderLocation => 'Fetching rider location…';

  @override
  String get noLocationData => 'No location data yet';

  @override
  String get riderLocationWillAppear =>
      'Rider location will appear here once available';

  @override
  String get riderLocation => 'Rider location';

  @override
  String etaLabel(String eta) {
    return 'ETA: $eta';
  }

  @override
  String minutesShort(String minutes) {
    return '$minutes min';
  }

  @override
  String hoursMinutesShort(String hours, String minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get noData => 'No data';

  @override
  String get name => 'Name';

  @override
  String get phone => 'Phone';

  @override
  String get amount => 'Amount';

  @override
  String get qty => 'Qty';

  @override
  String get item => 'Item';

  @override
  String get product => 'Product';

  @override
  String get products => 'Products';

  @override
  String get categories => 'Categories';

  @override
  String get toppings => 'Toppings';

  @override
  String get category => 'Category';

  @override
  String get orders => 'Orders';

  @override
  String get order => 'Order';

  @override
  String get revenue => 'Revenue';

  @override
  String get transactions => 'Transactions';

  @override
  String get payment => 'Payment';

  @override
  String get confirm => 'Confirm';

  @override
  String get remove => 'Remove';

  @override
  String get keep => 'Keep';

  @override
  String get reject => 'Reject';

  @override
  String get call => 'Call';

  @override
  String get newLabel => 'New';

  @override
  String get active => 'Active';

  @override
  String get pending => 'Pending';

  @override
  String get completed => 'Completed';

  @override
  String get confirmed => 'Confirmed';

  @override
  String get defaultLabel => 'Default';

  @override
  String get disabled => 'Disabled';

  @override
  String get blocked => 'Blocked';

  @override
  String get admin => 'Admin';

  @override
  String get system => 'System';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get today2 => 'TODAY';

  @override
  String get yesterday2 => 'YESTERDAY';

  @override
  String get loadMore => 'Load More';

  @override
  String get fullscreen => 'Fullscreen';

  @override
  String get official => 'Official';

  @override
  String get unsynced => 'Unsynced';

  @override
  String get percentage => 'Percentage';

  @override
  String get fixedValue => 'Fixed Value';

  @override
  String get manageCatalog => 'Manage Catalog';

  @override
  String get manageYourActiveProductCatalog =>
      'Manage your active product catalog';

  @override
  String get organizeProductsIntoGroups => 'Organize products into groups';

  @override
  String get addOnsModifiersAndVariations =>
      'Add-ons, modifiers, and variations';

  @override
  String get manageCategories => 'Manage Categories';

  @override
  String get manageCombos => 'Manage Combos';

  @override
  String get manageProducts => 'Manage Products';

  @override
  String get manageToppings => 'Manage Toppings';

  @override
  String get addProduct => 'Add Product';

  @override
  String get addCategory => 'Add Category';

  @override
  String get addCombo => 'Add Combo';

  @override
  String get addTopping => 'Add Topping';

  @override
  String get addYourFirstCategoryToGet =>
      'Add your first category to get started';

  @override
  String get addYourFirstComboToGet => 'Add your first combo to get started';

  @override
  String get addYourFirstProductToGet =>
      'Add your first product to get started';

  @override
  String get addYourFirstToppingToGet =>
      'Add your first topping to get started';

  @override
  String get noCategoriesYet => 'No categories yet';

  @override
  String get noCombosYet => 'No combos yet';

  @override
  String get noProductsYet => 'No products yet';

  @override
  String get noToppingsYet => 'No toppings yet';

  @override
  String get deleteCategory => 'Delete Category';

  @override
  String get deleteCombo => 'Delete Combo';

  @override
  String get deleteProduct => 'Delete Product';

  @override
  String get deleteTopping => 'Delete Topping';

  @override
  String get areYouSureYouWantTo =>
      'Are you sure you want to delete this category?';

  @override
  String get areYouSureYouWantTo2 =>
      'Are you sure you want to delete this combo?';

  @override
  String get areYouSureYouWantTo3 =>
      'Are you sure you want to delete this product?';

  @override
  String get areYouSureYouWantTo4 =>
      'Are you sure you want to delete this topping?';

  @override
  String get categoryDeleted => 'Category deleted';

  @override
  String get comboDeleted => 'Combo deleted';

  @override
  String get productDeleted => 'Product deleted';

  @override
  String get toppingDeleted => 'Topping deleted';

  @override
  String get visibleInApp => 'Visible in app';

  @override
  String get hiddenInApp => 'Hidden in app';

  @override
  String get categoryName => 'Category Name*';

  @override
  String get comboName => 'Combo Name*';

  @override
  String get comboFixedPrice => 'Combo Fixed Price*';

  @override
  String get productName => 'Product Name*';

  @override
  String get toppingName => 'Topping Name*';

  @override
  String get listPrice => 'List Price*';

  @override
  String get extraPriceOptional => 'Extra Price (Optional)';

  @override
  String get saveCategory => 'Save Category';

  @override
  String get saveCombo => 'Save Combo';

  @override
  String get saveProduct => 'Save Product';

  @override
  String get saveTopping => 'Save Topping';

  @override
  String get categoryAddedSuccessfully => 'Category added successfully';

  @override
  String get categoryUpdatedSuccessfully => 'Category updated successfully';

  @override
  String get comboSavedSuccessfully => 'Combo saved successfully';

  @override
  String get productSavedSuccessfully => 'Product saved successfully';

  @override
  String get toppingSavedSuccessfully => 'Topping saved successfully';

  @override
  String get nameIsRequired => 'Name is required';

  @override
  String get validNameAndPriceAreRequired =>
      'Valid name and price are required';

  @override
  String get comboMustHaveAtLeastOne => 'Combo must have at least one product';

  @override
  String get comboItems => 'Combo Items';

  @override
  String get noProductsAddedToThisCombo =>
      'No products added to this combo yet.';

  @override
  String get availableToppings => 'Available Toppings';

  @override
  String get noToppingsConfigured => 'No toppings configured.';

  @override
  String get showInApp => 'Show in app';

  @override
  String get onlyCheckedCategoriesAreVisibleIn =>
      'Only checked categories are visible in POS app.';

  @override
  String get customerSelfOrder => 'Customer self-order';

  @override
  String get customersCanSelectAndOrder => 'Customers can select and order';

  @override
  String get runOutBlocked => 'Run out (blocked)';

  @override
  String get shownAsRunOutCannotAdd => 'Shown as run out; cannot add to cart';

  @override
  String get couldNotSaveToppingPleaseTry =>
      'Could not save topping. Please try again.';

  @override
  String get currentTicket2 => 'Current Ticket';

  @override
  String get newItems => 'NEW ITEMS';

  @override
  String get alreadyOrdered => 'ALREADY ORDERED';

  @override
  String get noItems => 'No items';

  @override
  String get noItemsInTicket => 'No items in ticket';

  @override
  String get addCustomer => 'Add customer';

  @override
  String get clearTicket2 => 'Clear Ticket';

  @override
  String get saveTicket => 'SAVE TICKET';

  @override
  String get charge2 => 'CHARGE';

  @override
  String get subtotalExclVat => 'Subtotal (excl. VAT)';

  @override
  String get amountExclVat2 => 'Amount (excl. VAT)';

  @override
  String get includesVat => 'Includes VAT';

  @override
  String get priceIncludesTax => 'Price includes tax';

  @override
  String get taxHiddenOnReceipt => 'Tax hidden on receipt';

  @override
  String get totalDue => 'Total due';

  @override
  String get selectCustomer => 'Select Customer';

  @override
  String get addCustomer2 => 'Add Customer';

  @override
  String get newCustomer => 'New Customer';

  @override
  String get addCustomerIfNotFound => 'Add customer if not found';

  @override
  String get searchByNameOrPhone => 'Search by name or phone...';

  @override
  String get loadingCustomers => 'Loading customers...';

  @override
  String get noCustomersFound => 'No customers found';

  @override
  String get searchFailedPleaseTryAgain => 'Search failed. Please try again.';

  @override
  String get couldNotCreateCustomerPleaseTry =>
      'Could not create customer. Please try again.';

  @override
  String get couldNotLoadMorePleaseTry =>
      'Could not load more. Please try again.';

  @override
  String get noOpenTickets => 'No open tickets';

  @override
  String get noTable2 => 'No Table';

  @override
  String get orderReady => 'Order Ready';

  @override
  String get discountCustomItem => 'Discount / Custom Item';

  @override
  String get couldNotLoadTicketsPleaseCheck =>
      'Could not load tickets. Please check your connection and try again.';

  @override
  String get couldNotSendNotificationPleaseTry =>
      'Could not send notification. Please try again.';

  @override
  String get splitTicket => 'Split Ticket';

  @override
  String get ticketName => 'Ticket Name';

  @override
  String get renameNewTicket => 'Rename New Ticket';

  @override
  String get allItemsMoved => 'All items moved';

  @override
  String get pleaseMoveAtLeastOneItem =>
      'Please move at least one item to the new ticket.';

  @override
  String get theOriginalTicketCannotBeEmpty =>
      'The original ticket cannot be empty. Keep at least one item.';

  @override
  String get tapItemsOnTheLeftTo => 'Tap items on the\nleft to move them here';

  @override
  String get discountOptions => 'Discount Options';

  @override
  String get addDiscountOption => 'Add Discount Option';

  @override
  String get discountType => 'Discount Type';

  @override
  String get enableDiscount => 'Enable Discount';

  @override
  String get discountHidden => 'Discount hidden';

  @override
  String get discountWillAppearInPos => 'Discount will appear in POS';

  @override
  String get discountSettingsSaved => 'Discount settings saved';

  @override
  String get noDiscountOptionsAddedYet => 'No discount options added yet.';

  @override
  String get optionName => 'Option Name';

  @override
  String get percentage2 => 'Percentage (%)';

  @override
  String get leaveEmptyForManualInput => 'Leave empty for manual input';

  @override
  String get tipLeaveTheValueBlankTo =>
      'Tip: Leave the value blank to let cashiers enter a custom amount.';

  @override
  String get receiptsHistory => 'Receipts History';

  @override
  String get noPaidReceiptsYet => 'No paid receipts yet';

  @override
  String get noMoreReceipts => 'No more receipts';

  @override
  String get unknownDate => 'Unknown Date';

  @override
  String get thisReceiptIsMissingAnOrder =>
      'This receipt is missing an order id. Please refresh and try again.';

  @override
  String get refund => 'Refund';

  @override
  String get refundOrder => 'Refund Order';

  @override
  String get confirmRefund => 'Confirm Refund';

  @override
  String get reprintReceipt => 'Reprint Receipt';

  @override
  String get adminPin => 'Admin PIN';

  @override
  String get adminPinIsRequired => 'Admin PIN is required.';

  @override
  String get thisOrderHasBeenRefunded => 'This order has been refunded';

  @override
  String get printerErrorCheckConnection => 'Printer error. Check connection.';

  @override
  String get orderRefundedSuccessfully => '✅ Order refunded successfully.';

  @override
  String get receiptReprinted => '🖨️ Receipt reprinted!';

  @override
  String get noPendingSelfOrders => 'No pending self orders';

  @override
  String get quickConfirm => 'Quick Confirm';

  @override
  String get rejectOrder => 'Reject Order';

  @override
  String get rejectOrder2 => 'Reject Order?';

  @override
  String get orderRejectedAndCancelled => 'Order rejected and cancelled.';

  @override
  String get transferConfirmedOrderMovedToOpen =>
      'Transfer confirmed. Order moved to Open Tickets.';

  @override
  String get couldNotConfirmOrderPleaseTry =>
      'Could not confirm order. Please try again.';

  @override
  String get couldNotRejectOrderPleaseTry =>
      'Could not reject order. Please try again.';

  @override
  String get couldNotLoadOrdersPleaseCheck =>
      'Could not load orders. Please check your connection and try again.';

  @override
  String get viewProof => 'View Proof';

  @override
  String get noProofImageUploaded => 'No proof image uploaded';

  @override
  String get cannotLoadProofImage => 'Cannot load proof image';

  @override
  String get bankTransfer => 'Bank Transfer';

  @override
  String get payAtStore2 => 'Pay at Store';

  @override
  String get customerPlace => 'Customer place:';

  @override
  String get orderNotePickupTime => 'Order Note / Pickup Time:';

  @override
  String get openMap => 'Open map';

  @override
  String get callCustomer => 'Call Customer?';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get currentOrders => 'Current Orders';

  @override
  String get orderHistory => 'Order History';

  @override
  String get ordersByStatus => 'Orders by Status';

  @override
  String get totalOrders => 'Total Orders';

  @override
  String get totalRevenue => 'Total Revenue';

  @override
  String get onTheWay => 'On The Way';

  @override
  String get noCurrentOrders => 'No current orders';

  @override
  String get noHistoryYet => 'No history yet';

  @override
  String get activeOrdersWillAppearHere => 'Active orders will appear here';

  @override
  String get completedOrdersWillAppearHere =>
      'Completed orders will appear here';

  @override
  String get actionFailedPleaseTryAgain => 'Action failed. Please try again.';

  @override
  String get chatWithCustomer => 'Chat with Customer';

  @override
  String get navigateInApp => 'Navigate (In App)';

  @override
  String get openInGoogleMapsApp => 'Open in Google Maps App';

  @override
  String get deliveryTarget => 'Delivery Target';

  @override
  String get youRider => 'You (Rider)';

  @override
  String get callCustomer2 => 'Call Customer';

  @override
  String get refreshRoute => 'Refresh route';

  @override
  String get fitRouteOnScreen => 'Fit route on screen';

  @override
  String get openInExternalGoogleMapsApp => 'Open in External Google Maps app';

  @override
  String get couldNotLaunchDialer => 'Could not launch dialer';

  @override
  String get couldNotLaunchExternalMapsApplication =>
      'Could not launch external maps application';

  @override
  String get statusUpdatedToArrived => 'Status updated to Arrived';

  @override
  String get statusUpdatedToCompleteDelivered =>
      'Status updated to Complete / Delivered';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get startTheConversationBelow => 'Start the conversation below';

  @override
  String get typeAMessage => 'Type a message…';

  @override
  String get sendImage => 'Send Image';

  @override
  String get sendImage2 => 'Send image';

  @override
  String get takeAPhoto => 'Take a photo';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get addACaptionOptional => 'Add a caption (optional)';

  @override
  String get imageReadyToSend => 'Image ready to send';

  @override
  String get couldNotLoadImage => 'Could not load image';

  @override
  String get couldNotLoadMessages => 'Could not load messages.';

  @override
  String get failedToSendImagePleaseTry =>
      'Failed to send image. Please try again.';

  @override
  String get failedToSendMessagePleaseTry =>
      'Failed to send message. Please try again.';

  @override
  String get sendingImage => '📷 Sending image…';

  @override
  String get printers => 'Printers';

  @override
  String get addPrinter => 'Add Printer';

  @override
  String get deletePrinter => 'Delete Printer';

  @override
  String get printerSaved => 'Printer saved';

  @override
  String get printerDeleted => 'Printer deleted';

  @override
  String get printerTestSuccessful => 'Printer test successful.';

  @override
  String get printerTestFailed => 'Printer test failed.';

  @override
  String get printTest => 'Print Test';

  @override
  String get printerIpAddress => 'Printer IP address';

  @override
  String get port => 'Port';

  @override
  String get paperWidth => 'Paper width';

  @override
  String get advancedSettings => 'Advanced settings';

  @override
  String get categoryRouting => 'Category routing';

  @override
  String get noCategoriesFound => 'No categories found';

  @override
  String get ifNoneSelectedAllCategoriesWill =>
      'If none selected, all categories will print on this printer.';

  @override
  String get printReceiptsAndBills => 'Print receipts and bills';

  @override
  String get printOrders => 'Print orders';

  @override
  String get defaultPrinterForReceipts => 'Default printer for receipts';

  @override
  String get printSingleItemPerOrderTicket =>
      'Print single item per order ticket';

  @override
  String get groupIdenticalItemsInOrderTickets =>
      'Group identical items in order tickets';

  @override
  String get noPrintersYet => 'No printers yet';

  @override
  String get tapToAddYourFirstPrinter =>
      'Tap + to add your first printer.\nConfigure receipts, orders, and categories.';

  @override
  String get receipt => 'Receipt';

  @override
  String get billPreReceipt => 'Bill (pre-receipt)';

  @override
  String get receiptPaid => 'Receipt (paid)';

  @override
  String get kitchenOrderTicket => 'Kitchen / Order Ticket';

  @override
  String get kitchenOrderTicket2 => 'Kitchen / Order ticket';

  @override
  String get refundVoid => 'Refund / Void';

  @override
  String get savedTemplateSettings => 'Saved template settings.';

  @override
  String get noTemplateSelectedPreviewUnavailable =>
      'No template selected — preview unavailable';

  @override
  String get adminReports => 'Admin Reports';

  @override
  String get allBranches => 'All branches';

  @override
  String get selectDateRange => 'Select date range';

  @override
  String get salesByDate => 'Sales by date';

  @override
  String get salesByPaymentType => 'Sales by payment type';

  @override
  String get salesByProductTop => 'Sales by product (top)';

  @override
  String get paymentType => 'Payment type';

  @override
  String get peakOrderHours => 'Peak order hours';

  @override
  String get noHourlyPeakDataAvailable => 'No hourly peak data available';

  @override
  String get noOrderTrafficRecordedInThis =>
      'No order traffic recorded in this range.';

  @override
  String get branchRanking => 'Branch ranking';

  @override
  String get forbiddenAdminOnly => 'Forbidden (admin only)';

  @override
  String get cannotLoadRanking => 'Cannot load ranking';

  @override
  String get climbTheAdventureLadder => 'Climb the adventure ladder!';

  @override
  String get yourRank => 'Your rank: -';

  @override
  String get enterPinToUnlock => 'Enter PIN to unlock';

  @override
  String get createYour4DigitPin => 'Create your 4-digit PIN';

  @override
  String get confirmYourNewPin => 'Confirm your new PIN';

  @override
  String get incorrectPin => 'Incorrect PIN';

  @override
  String get pinMismatchOrSaveFailed => 'PIN mismatch or save failed';

  @override
  String get switchUser => 'Switch User';

  @override
  String get setPosName => 'Set POS Name';

  @override
  String get posNameExCounter1Ipad =>
      'POS name (ex: Counter-1, iPad-Bar, Android-Front)';

  @override
  String get pleaseEnterAPosName => 'Please enter a POS name';

  @override
  String get posNameIsTooShort => 'POS name is too short';

  @override
  String get posNameIsTooLong => 'POS name is too long';

  @override
  String get thisHelpsTrackWhichDeviceWas =>
      'This helps track which device was used when something happens.';

  @override
  String get refreshingMenusTablesAndSalesData =>
      'Refreshing menus, tables, and sales data for this device';

  @override
  String get returnToLogin => 'Return to Login';

  @override
  String get networkErrorAndNoOfflineCache =>
      'Network error and no offline cache available.\nPlease connect to the internet.';

  @override
  String get maintenanceMode => 'Maintenance Mode';

  @override
  String get reachTheAdmin => 'Reach the admin';

  @override
  String get useTheOptionsYourStoreHas =>
      'Use the options your store has enabled in Odoo.';

  @override
  String get openFacebook => 'Open Facebook';

  @override
  String get openInWhatsapp => 'Open in WhatsApp';

  @override
  String get notConfiguredAskStaffToSet =>
      'Not configured. Ask staff to set the Facebook URL in Odoo (Customer support).';

  @override
  String get notConfiguredAskStaffToSet2 =>
      'Not configured. Ask staff to set the WhatsApp number in Odoo (Customer support).';

  @override
  String get ladolcePrivacy => 'LaDolce Privacy';

  @override
  String get failedToLoadPrivacyPolicyPlease =>
      'Failed to load Privacy Policy. Please check your network connection and try again.';

  @override
  String get orderItems => 'ORDER ITEMS';

  @override
  String get transferProof => 'TRANSFER PROOF';

  @override
  String get noLineItems => 'No line items';

  @override
  String get waitingReview => 'Waiting review';

  @override
  String get complete => 'COMPLETE';

  @override
  String get delivered => 'DELIVERED';

  @override
  String get cancelled => 'CANCELLED';

  @override
  String get offline => '⚡ OFFLINE';

  @override
  String get removeCoupon => 'Remove coupon';

  @override
  String get addNote => 'Add note';

  @override
  String get noteForKitchen => 'Note for the kitchen';

  @override
  String get tapItemToAddNote => 'Tap an item to add a note';

  @override
  String get proofUploadFailed =>
      'Order placed, but the transfer proof could not be uploaded. Please show it to the staff.';
}
