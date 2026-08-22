// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Lao (`lo`).
class AppLocalizationsLo extends AppLocalizations {
  AppLocalizationsLo([String locale = 'lo']) : super(locale);

  @override
  String get welcomeBack => 'ຍິນດີຕ້ອນຮັບກັບຄືນ';

  @override
  String get emailOrLogin => 'ອີເມວ / ເຂົ້າສູ່ລະບົບ';

  @override
  String get password => 'ລະຫັດຜ່ານ';

  @override
  String get loginButton => 'ເຂົ້າສູ່ລະບົບ';

  @override
  String get createAccount => 'ສ້າງບັນຊີໃໝ່';

  @override
  String get choosePaymentMethod => 'ເລືອກວິທີການຊໍາລະເງິນ';

  @override
  String get selectBranch => 'ເລືອກສາຂາ';

  @override
  String get noBranchesFound => 'ບໍ່ພົບສາຂາ. ກະລຸນາຕິດຕໍ່ພະນັກງານ.';

  @override
  String get selectBank => 'ເລືອກທະນາຄານ';

  @override
  String get scanQrCode => 'ສະແກນ QR ໂຄດ';

  @override
  String get qrNotConfigured => 'ບໍ່ໄດ້ຕັ້ງຄ່າ QR ໂຄດ';

  @override
  String get downloadQr => 'ດາວໂຫລດ QR';

  @override
  String get uploadTransferProof => 'ອັບໂຫຼດຫຼັກຖານການໂອນເງິນ';

  @override
  String get proofSelected => 'ເລືອກຫຼັກຖານແລ້ວ';

  @override
  String get transferProofSelectedMsg =>
      'ເລືອກຫຼັກຖານການໂອນເງິນແລ້ວ. ມັນຈະຖືກອັບໂຫຼດເມື່ອທ່ານຢືນຢັນຄໍາສັ່ງ.';

  @override
  String get confirmOrder => 'ຢືນຢັນຄໍາສັ່ງ';

  @override
  String get runOut => 'ໝົດແລ້ວ';

  @override
  String get orderNote => 'ໝາຍເຫດ / ເວລາຮັບເຄື່ອງ';

  @override
  String get orderNoteHint => 'ຕົວຢ່າງ: ມາຮັບຕອນ 15:00 ໂມງ, ເຜັດຫຼາຍ, ແລະອື່ນໆ';

  @override
  String get weatherWarning =>
      'ເນື່ອງຈາກສະພາບອາກາດບໍ່ດີ, ການຈັດສົ່ງ ຫຼື ໄຣເດີຂອງທ່ານອາດຈະຊັກຊ້າ.';

  @override
  String get deviceIphone => 'iPhone / iPad';

  @override
  String get deviceAndroid => 'ອຸປະກອນ Android';

  @override
  String get alreadySignedIn => 'ເຂົ້າສູ່ລະບົບຢູ່ແລ້ວ';

  @override
  String get accountActiveOtherDevice =>
      'ບັນຊີຂອງທ່ານກຳລັງໃຊ້ງານຢູ່ໃນອຸປະກອນອື່ນ.';

  @override
  String deviceIdLabel(String maskedId) {
    return 'ລະຫັດ: $maskedId';
  }

  @override
  String get continueSignsOutOther => 'ຖ້າສືບຕໍ່ ຈະອອກຈາກລະບົບໃນອຸປະກອນນັ້ນ.';

  @override
  String get cancel => 'ຍົກເລີກ';

  @override
  String get continueLabel => 'ສືບຕໍ່';

  @override
  String get unknownRoleFromServer => 'ບໍ່ຮູ້ຈັກສິດການໃຊ້ງານຈາກເຊີບເວີ';

  @override
  String get googleMissingEmail => 'ບັນຊີ Google ບໍ່ມີຂໍ້ມູນອີເມວ.';

  @override
  String googleLoginFailed(String error) {
    return 'ເຂົ້າສູ່ລະບົບດ້ວຍ Google ບໍ່ສຳເລັດ: $error';
  }

  @override
  String get pleaseEnterLogin => 'ກະລຸນາປ້ອນຊື່ຜູ້ໃຊ້';

  @override
  String get pleaseEnterPassword => 'ກະລຸນາປ້ອນລະຫັດຜ່ານ';

  @override
  String get continueWithGoogle => 'ສືບຕໍ່ດ້ວຍ Google';

  @override
  String get registerStaffAccount => 'ລົງທະບຽນບັນຊີພະນັກງານ';

  @override
  String get failedToSendOtp => 'ສົ່ງລະຫັດ OTP ບໍ່ສຳເລັດ';

  @override
  String failedToSendOtpError(String error) {
    return 'ສົ່ງລະຫັດ OTP ບໍ່ສຳເລັດ: $error';
  }

  @override
  String tooManyOtpRequests(String time) {
    return 'ຂໍລະຫັດ OTP ຫຼາຍເກີນໄປ. ກະລຸນາລໍຖ້າ $time ກ່ອນຂໍໃໝ່.';
  }

  @override
  String get otpVerification => 'ຢືນຢັນລະຫັດ OTP';

  @override
  String otpSentTo(String phone) {
    return 'ພວກເຮົາໄດ້ສົ່ງລະຫັດ OTP 6 ຫຼັກ ໄປຫາເບີໂທຂອງທ່ານ:\n+856 $phone';
  }

  @override
  String get pleaseEnterSixDigitCode => 'ກະລຸນາປ້ອນລະຫັດ 6 ຫຼັກ';

  @override
  String get registrationSuccessful => 'ລົງທະບຽນສຳເລັດແລ້ວ';

  @override
  String registrationFailed(String error) {
    return 'ລົງທະບຽນບໍ່ສຳເລັດ: $error';
  }

  @override
  String get verifyAndRegister => 'ຢືນຢັນ & ລົງທະບຽນ';

  @override
  String get otpResentSuccessfully => 'ສົ່ງລະຫັດ OTP ໃໝ່ສຳເລັດແລ້ວ!';

  @override
  String get resendCode => 'ສົ່ງລະຫັດໃໝ່';

  @override
  String get selectBranchBeforeGoogle =>
      'ກະລຸນາເລືອກສາຂາກ່ອນລົງທະບຽນດ້ວຍ Google';

  @override
  String googleRegistrationFailed(String error) {
    return 'ລົງທະບຽນດ້ວຍ Google ບໍ່ສຳເລັດ: $error';
  }

  @override
  String get createAccountTitle => 'ສ້າງບັນຊີ';

  @override
  String get joinLaDolce => 'ເຂົ້າຮ່ວມ LaDolce ແລະ ເລີ່ມສັ່ງອາຫານ';

  @override
  String get fullName => 'ຊື່ ແລະ ນາມສະກຸນ';

  @override
  String get pleaseEnterName => 'ກະລຸນາປ້ອນຊື່';

  @override
  String get phoneRequiredCustomers => 'ເບີໂທລະສັບ (ຈຳເປັນສຳລັບລູກຄ້າ)';

  @override
  String get phoneOptional => 'ເບີໂທລະສັບ (ບໍ່ບັງຄັບ)';

  @override
  String get phoneRequiredForCustomers => 'ລູກຄ້າຕ້ອງປ້ອນເບີໂທລະສັບ';

  @override
  String get phoneMustBe10Digits => 'ເບີໂທຕ້ອງມີ 10 ຫຼັກ ແລະ ຂຶ້ນຕົ້ນດ້ວຍ 20';

  @override
  String get pleaseEnterLoginEmail => 'ກະລຸນາປ້ອນຊື່ຜູ້ໃຊ້/ອີເມວ';

  @override
  String get role => 'ສິດການໃຊ້ງານ';

  @override
  String get roleCustomer => 'ລູກຄ້າ';

  @override
  String get roleCashier => 'ພະນັກງານເກັບເງິນ';

  @override
  String get roleRider => 'ໄຣເດີ';

  @override
  String get branch => 'ສາຂາ';

  @override
  String get selectBranchHint => 'ເລືອກສາຂາ';

  @override
  String get pleaseSelectBranch => 'ກະລຸນາເລືອກສາຂາ';

  @override
  String get agreeToTerms => 'ຂ້ອຍຍອມຮັບເງື່ອນໄຂການໃຊ້ບໍລິການ ແລະ ';

  @override
  String get privacyPolicy => 'ນະໂຍບາຍຄວາມເປັນສ່ວນຕົວ';

  @override
  String get registerButton => 'ລົງທະບຽນ';

  @override
  String get language => 'ພາສາ';

  @override
  String get apply => 'ນຳໃຊ້';

  @override
  String get save => 'ບັນທຶກ';

  @override
  String get clear => 'ລຶບ';

  @override
  String get done => 'ສຳເລັດ';

  @override
  String get retry => 'ລອງໃໝ່';

  @override
  String get unknown => 'ບໍ່ຮູ້ຈັກ';

  @override
  String get free => 'ຟຣີ';

  @override
  String errorWithMessage(String error) {
    return 'ຜິດພາດ: $error';
  }

  @override
  String get featureComingSoon => 'ຄຸນສົມບັດນີ້ຈະມາໃນໄວໆນີ້!';

  @override
  String get allItems => 'ລາຍການທັງໝົດ';

  @override
  String get combos => 'ຊຸດອາຫານ';

  @override
  String get searchProducts => 'ຄົ້ນຫາສິນຄ້າ...';

  @override
  String noProductsMatching(String query) {
    return 'ບໍ່ພົບສິນຄ້າທີ່ກົງກັບ \"$query\"';
  }

  @override
  String get noProductsInCategory => 'ບໍ່ມີສິນຄ້າໃນໝວດນີ້';

  @override
  String get applyDiscount => 'ນຳໃຊ້ສ່ວນຫຼຸດ';

  @override
  String get selectDiscountOption => 'ເລືອກຮູບແບບສ່ວນຫຼຸດ';

  @override
  String get selectDiscount => 'ເລືອກສ່ວນຫຼຸດ';

  @override
  String get noDiscount => 'ບໍ່ມີສ່ວນຫຼຸດ';

  @override
  String get customPercent => '(ກຳນົດເອງ %)';

  @override
  String get customAmount => '(ກຳນົດຈຳນວນເອງ)';

  @override
  String get enterDiscountPercentage => 'ປ້ອນເປີເຊັນສ່ວນຫຼຸດ';

  @override
  String get enterDiscountAmount => 'ປ້ອນຈຳນວນສ່ວນຫຼຸດ';

  @override
  String get removeDiscount => 'ລຶບສ່ວນຫຼຸດ';

  @override
  String get discountValueOption => 'ສ່ວນຫຼຸດ (ຈຳນວນເງິນ)';

  @override
  String percentOff(String percent) {
    return 'ຫຼຸດ $percent%';
  }

  @override
  String get egTen => 'ຕົວຢ່າງ: 10';

  @override
  String get egFiveThousand => 'ຕົວຢ່າງ: 5000';

  @override
  String get kitchenNote => 'ໝາຍເຫດເຖິງຄົວ';

  @override
  String get kitchenNoteHint => 'ຫວານໜ້ອຍ, ບໍ່ໃສ່ນ້ຳກ້ອນ, ເຜັດຫຼາຍ...';

  @override
  String selectToppingsFor(String product) {
    return 'ເລືອກເຄື່ອງເສີມສຳລັບ $product';
  }

  @override
  String get addWithoutToppings => 'ເພີ່ມໂດຍບໍ່ມີເຄື່ອງເສີມ';

  @override
  String get addToOrder => 'ເພີ່ມເຂົ້າອໍເດີ';

  @override
  String get tickets => 'ບິນ';

  @override
  String get openTickets => 'ບິນທີ່ເປີດຢູ່';

  @override
  String get ticketLabel => 'ບິນ';

  @override
  String get ticketOptions => 'ຕົວເລືອກບິນ';

  @override
  String get clearTicket => 'ລຶບບິນ';

  @override
  String get printBill => 'ພິມບິນ';

  @override
  String get reprintOrderKitchen => 'ພິມອໍເດີຄືນ (ຄົວ)';

  @override
  String get splitTicketAction => 'ແຍກບິນ';

  @override
  String get moveTicketAction => 'ຍ້າຍບິນ';

  @override
  String get sendToRider => 'ສົ່ງໃຫ້ໄຣເດີ';

  @override
  String get openCashDrawer => 'ເປີດລິ້ນຊັກເງິນ';

  @override
  String get syncAction => 'ຊິງຄ໌ຂໍ້ມູນ';

  @override
  String get scanVoucher => 'ສະແກນບັດສ່ວນຫຼຸດ';

  @override
  String get switchToList => 'ສະຫຼັບເປັນລາຍການ';

  @override
  String get switchToGrid => 'ສະຫຼັບເປັນຕາຕະລາງ';

  @override
  String get ticketCleared => 'ລຶບບິນແລ້ວ.';

  @override
  String get ticketRemovedByAdminPin => 'ລຶບບິນດ້ວຍ PIN ຜູ້ດູແລແລ້ວ.';

  @override
  String cannotClearTicket(String error) {
    return 'ບໍ່ສາມາດລຶບບິນ: $error';
  }

  @override
  String get adminPinRequired => 'ຕ້ອງການ PIN ຜູ້ດູແລ';

  @override
  String get enterPinToClearTicket => 'ປ້ອນ PIN ເພື່ອລຶບບິນທີ່ເລືອກ';

  @override
  String get pinIsRequired => 'ຕ້ອງປ້ອນ PIN';

  @override
  String get currentTicket => 'ບິນປັດຈຸບັນ';

  @override
  String itemsCount(String count) {
    return '$count ລາຍການ';
  }

  @override
  String get viewTicketCharge => 'ເບິ່ງບິນ &\nຮັບເງິນ';

  @override
  String get ticketSavedNoNewItems => 'ບັນທຶກບິນແລ້ວ (ບໍ່ມີລາຍການໃໝ່).';

  @override
  String ticketUpdatedWithItems(String name, String count) {
    return 'ອັບເດດບິນ $name ດ້ວຍ $count ລາຍການໃໝ່!';
  }

  @override
  String get noItemsToPrint => 'ບໍ່ມີລາຍການໃນບິນປັດຈຸບັນເພື່ອພິມ.';

  @override
  String get noPrinterConfiguredSettings =>
      'ຍັງບໍ່ໄດ້ຕັ້ງຄ່າເຄື່ອງພິມ. ກະລຸນາຕັ້ງຄ່າໃນການຕັ້ງຄ່າກ່ອນ.';

  @override
  String get noPrinterConfigured =>
      'ຍັງບໍ່ໄດ້ຕັ້ງຄ່າເຄື່ອງພິມ. ກະລຸນາຕັ້ງຄ່າກ່ອນ.';

  @override
  String get amountExclVat => 'ຈຳນວນເງິນ (ບໍ່ລວມ VAT):';

  @override
  String vatPercentLabel(String percent) {
    return 'VAT ($percent%):';
  }

  @override
  String get billPrinted => '🧾 ພິມບິນແລ້ວ!';

  @override
  String get failedToPrintBill =>
      'ພິມບິນບໍ່ສຳເລັດ. ກະລຸນາກວດການເຊື່ອມຕໍ່ເຄື່ອງພິມ.';

  @override
  String get noItemsToReprint => 'ບໍ່ມີລາຍການໃນບິນປັດຈຸບັນເພື່ອພິມຄືນ.';

  @override
  String orderReprinted(String count) {
    return '🖨️ ພິມອໍເດີຄືນໄປຫາເຄື່ອງພິມຄົວ $count ເຄື່ອງ.';
  }

  @override
  String get noPrinterForReprint =>
      'ບໍ່ມີເຄື່ອງພິມທີ່ພ້ອມໃຊ້ສຳລັບການພິມຄືນນີ້.';

  @override
  String get cashDrawerOpened => '🗃️ ເປີດລິ້ນຊັກເງິນແລ້ວ!';

  @override
  String get failedToOpenDrawer =>
      'ເປີດລິ້ນຊັກບໍ່ສຳເລັດ. ກະລຸນາກວດການເຊື່ອມຕໍ່ເຄື່ອງພິມ.';

  @override
  String get noItemsToSplit => 'ບໍ່ມີລາຍການໃນບິນປັດຈຸບັນເພື່ອແຍກ.';

  @override
  String get saveTicketBeforeSplit => 'ກະລຸນາບັນທຶກບິນກ່ອນແຍກບິນ.';

  @override
  String ticketSplitCreated(String name) {
    return 'ແຍກບິນແລ້ວ! ສ້າງ \"$name\" ແລ້ວ.';
  }

  @override
  String splitError(String error) {
    return 'ແຍກບິນຜິດພາດ: $error';
  }

  @override
  String cannotLoadOpenTickets(String error) {
    return 'ບໍ່ສາມາດໂຫຼດບິນທີ່ເປີດຢູ່: $error';
  }

  @override
  String get noOpenTicketToMoveFrom => 'ບໍ່ມີບິນທີ່ຈະຍ້າຍອອກ.';

  @override
  String get noDestinationAvailable =>
      'ບໍ່ມີປາຍທາງ. ກະລຸນາເປີດບິນອື່ນ ຫຼື ປ່ອຍໂຕະໃຫ້ວ່າງ.';

  @override
  String get moveTicketTitle => 'ຍ້າຍບິນ';

  @override
  String get selectSourceTicket => 'ເລືອກບິນຕົ້ນທາງ';

  @override
  String tableNumber(String id) {
    return 'ໂຕະ $id';
  }

  @override
  String get noTable => 'ບໍ່ມີໂຕະ';

  @override
  String get moveDestination => 'ປາຍທາງ';

  @override
  String get openTicketLabel => 'ບິນທີ່ເປີດຢູ່';

  @override
  String get emptyTable => 'ໂຕະຫວ່າງ';

  @override
  String get moveNow => 'ຍ້າຍດຽວນີ້';

  @override
  String get sourceTicketGone => 'ບໍ່ພົບບິນຕົ້ນທາງແລ້ວ.';

  @override
  String get selectDestinationFirst => 'ກະລຸນາເລືອກບິນ ຫຼື ໂຕະປາຍທາງ.';

  @override
  String get sourceHasNoItems => 'ບິນຕົ້ນທາງບໍ່ມີລາຍການໃຫ້ຍ້າຍ.';

  @override
  String get destinationTicketGone => 'ບໍ່ພົບບິນປາຍທາງແລ້ວ.';

  @override
  String movedItemsTo(String source, String destination) {
    return 'ຍ້າຍລາຍການຈາກບິນ #$source ໄປ $destination';
  }

  @override
  String moveTicketFailed(String error) {
    return 'ຍ້າຍບິນບໍ່ສຳເລັດ: $error';
  }

  @override
  String destTicketRef(String id) {
    return 'ບິນ #$id';
  }

  @override
  String destTableRef(String id) {
    return 'ໂຕະ #$id (ບິນໃໝ່)';
  }

  @override
  String sourceTotalItems(String total, String count) {
    return 'ຍອດຕົ້ນທາງ: ₭$total\nລາຍການ: $count';
  }

  @override
  String cannotLoadRiders(String error) {
    return 'ບໍ່ສາມາດໂຫຼດຂໍ້ມູນໄຣເດີ: $error';
  }

  @override
  String get noRidersAvailable => 'ບໍ່ມີໄຣເດີສຳລັບສາຂານີ້.';

  @override
  String get selectRider => 'ເລືອກໄຣເດີ';

  @override
  String orderForCustomer(String name) {
    return 'ອໍເດີສຳລັບ: $name';
  }

  @override
  String deliveryToPlace(String place) {
    return 'ຈັດສົ່ງໄປ: $place';
  }

  @override
  String get selfOrderDelivery => 'ຈັດສົ່ງອໍເດີລູກຄ້າ';

  @override
  String get unnamed => 'ບໍ່ມີຊື່';

  @override
  String orderSentToRider(String rider) {
    return 'ສົ່ງອໍເດີໃຫ້ $rider ແລ້ວ';
  }

  @override
  String failedToAssignRider(String error) {
    return 'ມອບໝາຍໄຣເດີບໍ່ສຳເລັດ: $error';
  }

  @override
  String customerSelected(String name) {
    return 'ເລືອກລູກຄ້າ $name ແລ້ວ!';
  }

  @override
  String get charge => 'ຮັບເງິນ';

  @override
  String get totalAmount => 'ຍອດລວມ';

  @override
  String get selectPaymentMethod => 'ເລືອກວິທີຊຳລະ';

  @override
  String get noPaymentMethods => 'ຍັງບໍ່ໄດ້ຕັ້ງຄ່າວິທີການຊຳລະ.';

  @override
  String get amountReceived => 'ຈຳນວນເງິນທີ່ຮັບ';

  @override
  String get changeDue => 'ເງິນທອນ:';

  @override
  String chargeAmount(String amount) {
    return 'ຮັບເງິນ K$amount';
  }

  @override
  String get orderPaidSuccessfully => 'ຊຳລະເງິນສຳເລັດແລ້ວ!';

  @override
  String transferTicketFixedTo(String method) {
    return 'ບິນໂອນ: ກຳນົດເປັນ $method.';
  }

  @override
  String get transferTicketFixed => 'ບິນໂອນ: ວິທີການຊຳລະຖືກກຳນົດໄວ້ແລ້ວ.';

  @override
  String get administrator => 'ຜູ້ດູແລລະບົບ';

  @override
  String get posTerminal => 'ເຄື່ອງ POS';

  @override
  String get sales => 'ການຂາຍ';

  @override
  String get receipts => 'ໃບຮັບເງິນ';

  @override
  String get selfOrdersReview => 'ກວດອໍເດີລູກຄ້າ';

  @override
  String get itemsMenu => 'ລາຍການສິນຄ້າ';

  @override
  String get settings => 'ການຕັ້ງຄ່າ';

  @override
  String get lockSwitchUser => 'ລັອກ / ປ່ຽນຜູ້ໃຊ້';

  @override
  String get demoCashier => 'ພະນັກງານທົດລອງ';

  @override
  String get selectTable => 'ເລືອກໂຕະ';

  @override
  String get chooseLocationNewTicket => 'ເລືອກບ່ອນນັ່ງເພື່ອເປີດບິນໃໝ່';

  @override
  String get noTablesAvailable => 'ບໍ່ມີໂຕະ.\nກະລຸນາຊິງຄ໌ຂໍ້ມູນ.';

  @override
  String get tableAvailable => 'ຫວ່າງ';

  @override
  String get tableOpen => 'ເປີດຢູ່';

  @override
  String get tableOccupied => 'ບໍ່ຫວ່າງ';

  @override
  String get openOrder => 'ເປີດອໍເດີ';

  @override
  String ticketOpenedAt(String table) {
    return 'ເປີດບິນທີ່ $table ແລ້ວ!';
  }

  @override
  String get rewardClaimed => 'ຮັບລາງວັນແລ້ວ!';

  @override
  String voucherCustomer(String name) {
    return 'ລູກຄ້າ: $name';
  }

  @override
  String voucherProduct(String name) {
    return 'ສິນຄ້າ: $name';
  }

  @override
  String get giveItemToCustomer => 'ກະລຸນາມອບສິນຄ້ານີ້ໃຫ້ລູກຄ້າ.';

  @override
  String get claimRewardVoucher => 'ຮັບບັດລາງວັນ';

  @override
  String get enterOrScanVoucher => 'ປ້ອນ ຫຼື ສະແກນລະຫັດບັດລາງວັນຂອງລູກຄ້າ:';

  @override
  String get voucherCode => 'ລະຫັດບັດ';

  @override
  String get claim => 'ຮັບ';

  @override
  String syncedOfflineOrders(String count) {
    return '✅ ຊິງຄ໌ອໍເດີອອບໄລນ໌ $count ລາຍການຂຶ້ນເຊີບເວີແລ້ວ.';
  }

  @override
  String get syncedAllData => '✅ ຊິງຄ໌ຂໍ້ມູນທັງໝົດແລ້ວ.';

  @override
  String syncFailed(String error) {
    return 'ຊິງຄ໌ບໍ່ສຳເລັດ: $error';
  }

  @override
  String get newSelfOrderWaiting => 'ມີອໍເດີລູກຄ້າໃໝ່ລໍຖ້າກວດ';

  @override
  String newSelfOrderWaitingCount(String count) {
    return 'ມີອໍເດີລູກຄ້າໃໝ່ລໍຖ້າກວດ ($count ລາຍການ)';
  }

  @override
  String newSelfOrderDetail(String summary) {
    return 'ອໍເດີລູກຄ້າໃໝ່: $summary';
  }

  @override
  String newSelfOrdersCount(String count, String detail) {
    return 'ອໍເດີລູກຄ້າໃໝ່ $count ລາຍການ: $detail';
  }

  @override
  String get english => 'ອັງກິດ';

  @override
  String get laoLanguage => 'ລາວ';

  @override
  String get chooseAppLanguage => 'ເລືອກພາສາຂອງແອັບ';

  @override
  String get appSettings => 'ການຕັ້ງຄ່າແອັບ';

  @override
  String get printerConfiguration => 'ຕັ້ງຄ່າເຄື່ອງພິມ';

  @override
  String printersConfigured(String count) {
    return 'ຕັ້ງຄ່າເຄື່ອງພິມ $count ເຄື່ອງແລ້ວ';
  }

  @override
  String connectedTo(String ip) {
    return 'ເຊື່ອມຕໍ່: $ip';
  }

  @override
  String get notConfigured => 'ຍັງບໍ່ໄດ້ຕັ້ງຄ່າ';

  @override
  String get billTemplates => 'ຮູບແບບບິນ';

  @override
  String get billTemplatesSubtitle =>
      'ເລືອກຮູບແບບບິນ/ໃບຮັບເງິນ/ໃບຄືນເງິນ ສຳລັບສາຂານີ້';

  @override
  String get discountConfiguration => 'ຕັ້ງຄ່າສ່ວນຫຼຸດ';

  @override
  String discountOptionsConfigured(String count) {
    return 'ຕັ້ງຄ່າຕົວເລືອກສ່ວນຫຼຸດ $count ລາຍການແລ້ວ';
  }

  @override
  String get usePromotionPrice => 'ໃຊ້ລາຄາໂປຣໂມຊັນໃນ POS';

  @override
  String get promotionalPricesApplied => 'ຈະໃຊ້ລາຄາໂປຣໂມຊັນ';

  @override
  String get normalPricesApplied => 'ຈະໃຊ້ລາຄາປົກກະຕິ';
}
