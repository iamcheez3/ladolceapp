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

  @override
  String get sessionExpired => 'ເຊສຊັນໝົດອາຍຸ. ກະລຸນາເຂົ້າສູ່ລະບົບໃໝ່.';

  @override
  String get close => 'ປິດ';

  @override
  String get add => 'ເພີ່ມ';

  @override
  String get delete => 'ລຶບ';

  @override
  String get refresh => 'ໂຫຼດຄືນ';

  @override
  String get optional => 'ບໍ່ບັງຄັບ';

  @override
  String get total => 'ລວມທັງໝົດ';

  @override
  String get status => 'ສະຖານະ';

  @override
  String get date => 'ວັນທີ';

  @override
  String get quantity => 'ຈຳນວນ';

  @override
  String get selectedLocation => 'ຕຳແໜ່ງທີ່ເລືອກ';

  @override
  String get couldNotSearchPlaces =>
      'ຄົ້ນຫາສະຖານທີ່ບໍ່ໄດ້. ກະລຸນາກວດການເຊື່ອມຕໍ່ອິນເຕີເນັດ.';

  @override
  String get couldNotReadAddress => 'ອ່ານທີ່ຢູ່ທີ່ເລືອກບໍ່ໄດ້. ກະລຸນາລອງໃໝ່.';

  @override
  String get addFavoritePlace => 'ເພີ່ມສະຖານທີ່ທີ່ມັກ';

  @override
  String get searchAddressOrPlace => 'ຄົ້ນຫາທີ່ຢູ່ ຫຼື ສະຖານທີ່';

  @override
  String get nameThisPlace => 'ຕັ້ງຊື່ສະຖານທີ່ນີ້ ເຊັ່ນ: ບ້ານ';

  @override
  String get placeHouse => 'ບ້ານ';

  @override
  String get placeWork => 'ບ່ອນເຮັດວຽກ';

  @override
  String get placeFriendHouse => 'ບ້ານໝູ່';

  @override
  String get locationServicesDisabled =>
      'ບໍລິການຕຳແໜ່ງຖືກປິດຢູ່. ກະລຸນາເປີດໃນການຕັ້ງຄ່າ.';

  @override
  String get locationPermissionDenied => 'ບໍ່ໄດ້ຮັບອະນຸຍາດເຂົ້າເຖິງຕຳແໜ່ງ.';

  @override
  String get locationPermissionPermanentlyDenied =>
      'ການເຂົ້າເຖິງຕຳແໜ່ງຖືກປະຕິເສດຖາວອນ. ກະລຸນາເປີດໃນການຕັ້ງຄ່າ.';

  @override
  String get couldNotGetLocation =>
      'ຫາຕຳແໜ່ງປັດຈຸບັນບໍ່ໄດ້. ກະລຸນາອະນຸຍາດການເຂົ້າເຖິງຕຳແໜ່ງ ແລ້ວລອງໃໝ່.';

  @override
  String get moveMapToPlacePin => 'ເລື່ອນແຜນທີ່ເພື່ອວາງໝຸດ';

  @override
  String get readingSelectedAddress => 'ກຳລັງອ່ານທີ່ຢູ່ທີ່ເລືອກ...';

  @override
  String get addSelectedPlace => 'ເພີ່ມສະຖານທີ່ທີ່ເລືອກ';

  @override
  String get addDeliveryPlaces => 'ເພີ່ມສະຖານທີ່ຈັດສົ່ງສຳລັບການສັ່ງເອງ';

  @override
  String get favoritePlaces => 'ສະຖານທີ່ທີ່ມັກ';

  @override
  String get noFavoritePlaces => 'ຍັງບໍ່ມີສະຖານທີ່ທີ່ມັກ.';

  @override
  String get deletePlaceTitle => 'ລຶບສະຖານທີ່?';

  @override
  String removePlaceConfirm(String name) {
    return 'ຕ້ອງການລຶບ \"$name\" ອອກຈາກລາຍການທີ່ມັກບໍ?';
  }

  @override
  String placeSavedCount(String label, String count) {
    return '$label  •  ບັນທຶກ $count ແຫ່ງ';
  }

  @override
  String get profileImageUpdated => 'ອັບເດດຮູບໂປຣໄຟລ໌ແລ້ວ';

  @override
  String get couldNotOpenImagePicker => 'ເປີດຕົວເລືອກຮູບບໍ່ໄດ້. ກະລຸນາລອງໃໝ່.';

  @override
  String get noQrImageConfigured => 'ຍັງບໍ່ໄດ້ຕັ້ງຄ່າຮູບ QR';

  @override
  String get photosPermissionBlocked =>
      'ການເຂົ້າເຖິງຮູບພາບຖືກບລັອກ. ກະລຸນາເປີດການຕັ້ງຄ່າເພື່ອອະນຸຍາດ.';

  @override
  String get photoPermissionRequired =>
      'ຕ້ອງການສິດເຂົ້າເຖິງຮູບພາບເພື່ອບັນທຶກ QR';

  @override
  String get storagePermissionRequired =>
      'ຕ້ອງການສິດເຂົ້າເຖິງບ່ອນເກັບຂໍ້ມູນເພື່ອບັນທຶກ QR';

  @override
  String get qrSavedToGallery => 'ບັນທຶກ QR ໃສ່ຄັງຮູບແລ້ວ ✓';

  @override
  String get couldNotSaveQr => 'ບັນທຶກ QR ບໍ່ໄດ້. ກະລຸນາລອງໃໝ່.';

  @override
  String get cannotFindSaveDirectory => 'ຫາບ່ອນບັນທຶກບໍ່ພົບ';

  @override
  String get couldNotSaveQrDownloads =>
      'ບັນທຶກ QR ໃສ່ Downloads ບໍ່ໄດ້. ກະລຸນາລອງໃໝ່.';

  @override
  String qrSavedTo(String path) {
    return 'ບັນທຶກ QR ໃສ່ $path ແລ້ວ';
  }

  @override
  String get itemRunOut => 'ສິນຄ້ານີ້ໝົດແລ້ວ ບໍ່ສາມາດສັ່ງໄດ້.';

  @override
  String get couponApplied => 'ໃຊ້ຄູປອງສຳເລັດແລ້ວ!';

  @override
  String get phoneNumberRequiredTitle => 'ຕ້ອງການເບີໂທລະສັບ';

  @override
  String get verifiedPhoneRequired =>
      'ຕ້ອງມີເບີໂທລະສັບທີ່ຢືນຢັນແລ້ວກ່ອນສັ່ງຊື້. ກະລຸນາອັບເດດໂປຣໄຟລ໌ຂອງທ່ານ.';

  @override
  String get updateProfile => 'ອັບເດດໂປຣໄຟລ໌';

  @override
  String get branchClosed =>
      'ສາຂານີ້ປິດຢູ່ໃນຂະນະນີ້. ກະລຸນາເລືອກສາຂາອື່ນ ຫຼື ສັ່ງພາຍຫຼັງ.';

  @override
  String get howReceiveOrder => 'ທ່ານຕ້ອງການຮັບອໍເດີແບບໃດ?';

  @override
  String get riderDelivery => 'ຈັດສົ່ງໂດຍໄຣເດີ';

  @override
  String get comePickUpMyself => 'ມາຮັບເອງ';

  @override
  String get deliveryPlace => 'ສະຖານທີ່ຈັດສົ່ງ';

  @override
  String get addFavoritePlaceBeforeOrder =>
      'ກະລຸນາເພີ່ມສະຖານທີ່ທີ່ມັກກ່ອນຢືນຢັນອໍເດີ.';

  @override
  String get selectDeliveryPlace => 'ເລືອກສະຖານທີ່ຈັດສົ່ງ';

  @override
  String get paymentBreakdown => 'ລາຍລະອຽດການຊຳລະ';

  @override
  String get subtotal => 'ຍອດຍ່ອຍ';

  @override
  String get discount => 'ສ່ວນຫຼຸດ';

  @override
  String get pointsRequired => 'ຄະແນນທີ່ຕ້ອງໃຊ້';

  @override
  String get totalPayment => 'ຍອດຊຳລະທັງໝົດ';

  @override
  String deliveryFeeKm(String km) {
    return 'ຄ່າຈັດສົ່ງ ($km ກມ)';
  }

  @override
  String addMoreForFreeDelivery(String amount) {
    return 'ເພີ່ມອີກ ₭$amount ເພື່ອຮັບການຈັດສົ່ງຟຣີ!';
  }

  @override
  String get notEnoughPointsRedeem => 'ຄະແນນບໍ່ພໍສຳລັບແລກສິນຄ້າເຫຼົ່ານີ້.';

  @override
  String get payTransfer => 'ໂອນເງິນ';

  @override
  String get payAtStore => 'ຈ່າຍທີ່ຮ້ານ';

  @override
  String get orderCreatedProofUploaded =>
      'ສ້າງອໍເດີແລ້ວ. ອັບໂຫຼດຫຼັກຖານການໂອນແລ້ວ.';

  @override
  String get orderCreatedProofLocal =>
      'ສ້າງອໍເດີແລ້ວ. ບັນທຶກຫຼັກຖານການໂອນໄວ້ໃນເຄື່ອງແລ້ວ.';

  @override
  String get orderCreatedPayAtStore => 'ສ້າງອໍເດີແລ້ວ. ກະລຸນາຈ່າຍທີ່ຮ້ານ.';

  @override
  String get failedToPlaceOrder =>
      'ສັ່ງຊື້ບໍ່ສຳເລັດ. ກະລຸນາກວດການເຊື່ອມຕໍ່ ແລ້ວລອງໃໝ່.';

  @override
  String get phoneNumberRequiredLower => 'ຕ້ອງການເບີໂທລະສັບ';

  @override
  String get addPhoneBeforeOrder =>
      'ກະລຸນາເພີ່ມເບີໂທລະສັບກ່ອນສັ່ງຊື້. ຈຳເປັນສຳລັບການຢືນຢັນຕົວຕົນ ແລະ ໃຫ້ຮ້ານຕິດຕໍ່ທ່ານໄດ້ເມື່ອຈຳເປັນ.';

  @override
  String get addPhone => 'ເພີ່ມເບີໂທ';

  @override
  String get profileUpdated => 'ອັບເດດໂປຣໄຟລ໌ແລ້ວ';

  @override
  String get couldNotSaveProfileConnection =>
      'ບັນທຶກໂປຣໄຟລ໌ບໍ່ໄດ້. ກະລຸນາກວດການເຊື່ອມຕໍ່ ແລ້ວລອງໃໝ່.';

  @override
  String get couldNotSaveProfile => 'ບັນທຶກໂປຣໄຟລ໌ບໍ່ໄດ້. ກະລຸນາລອງໃໝ່.';

  @override
  String get deleteAccountTitle => 'ລຶບບັນຊີ?';

  @override
  String get accountDeleted => 'ບັນຊີຂອງທ່ານຖືກລຶບແລ້ວ.';

  @override
  String get couldNotDeleteAccount => 'ລຶບບັນຊີບໍ່ໄດ້. ກະລຸນາລອງໃໝ່.';

  @override
  String get editProfile => 'ແກ້ໄຂໂປຣໄຟລ໌';

  @override
  String get fullNameCaps => 'ຊື່ ແລະ ນາມສະກຸນ';

  @override
  String get yourFullName => 'ຊື່ເຕັມຂອງທ່ານ';

  @override
  String get phoneCaps => 'ເບີໂທລະສັບ';

  @override
  String get phoneExample => 'ຕົວຢ່າງ: 20XXXXXXXX';

  @override
  String get dateOfBirthCaps => 'ວັນເດືອນປີເກີດ';

  @override
  String get saveChanges => 'ບັນທຶກການປ່ຽນແປງ';

  @override
  String get phoneNumberIsRequired => 'ຕ້ອງປ້ອນເບີໂທລະສັບ';

  @override
  String get phoneMustStartWith20 =>
      'ເບີໂທຕ້ອງຂຶ້ນຕົ້ນດ້ວຍ 20 ແລະ ມີ 10 ຫຼັກພໍດີ (ຕົວຢ່າງ: 20XXXXXXXX)';

  @override
  String get verifyAndSave => 'ຢືນຢັນ & ບັນທຶກ';

  @override
  String get otpVerificationFailed => 'ຢືນຢັນລະຫັດ OTP ບໍ່ສຳເລັດ';

  @override
  String get failedToResendOtp => 'ສົ່ງລະຫັດ OTP ໃໝ່ບໍ່ສຳເລັດ';

  @override
  String get logout => 'ອອກຈາກລະບົບ';

  @override
  String get loggingOut => 'ກຳລັງອອກຈາກລະບົບ...';

  @override
  String get deleteAccount => 'ລຶບບັນຊີ';

  @override
  String get deletingAccount => 'ກຳລັງລຶບບັນຊີ...';

  @override
  String get clientIdCopied => 'ຄັດລອກ Client ID ແລ້ວ!';

  @override
  String rewardPointsLabel(String points) {
    return 'ຄະແນນສະສົມ: $points';
  }

  @override
  String get rewardsCatalog => 'ລາຍການລາງວັນ';

  @override
  String get noRewardsAvailable => 'ຍັງບໍ່ມີລາງວັນໃນຂະນະນີ້.';

  @override
  String get notEnoughPoints => 'ຄະແນນບໍ່ພໍ!';

  @override
  String get redeemRewardTitle => 'ແລກລາງວັນ?';

  @override
  String redeemConfirm(String points, String product) {
    return 'ທ່ານຕ້ອງການແລກ $points ຄະແນນເປັນບັດສ່ວນຫຼຸດສຳລັບ $product ບໍ?';
  }

  @override
  String get customerNotLoggedIn => 'ລູກຄ້າຍັງບໍ່ໄດ້ເຂົ້າສູ່ລະບົບຢ່າງຖືກຕ້ອງ.';

  @override
  String get voucherCreated => 'ສ້າງບັດສ່ວນຫຼຸດສຳເລັດແລ້ວ!';

  @override
  String get redeem => 'ແລກ';

  @override
  String get claimedSuccessfully => 'ຮັບລາງວັນສຳເລັດແລ້ວ!';

  @override
  String get rewardClaimedEnjoy => 'ທ່ານໄດ້ຮັບລາງວັນແລ້ວ. ຂໍໃຫ້ມ່ວນຊື່ນ!';

  @override
  String get scanQrAtCounter => 'ສະແກນ QR ນີ້ທີ່ເຄົາເຕີເພື່ອຮັບລາງວັນຂອງທ່ານ.';

  @override
  String get myVouchers => 'ບັດສ່ວນຫຼຸດຂອງຂ້ອຍ';

  @override
  String get notLoggedIn => 'ຍັງບໍ່ໄດ້ເຂົ້າສູ່ລະບົບ.';

  @override
  String get voucherActive => 'ໃຊ້ໄດ້';

  @override
  String get redeemPoints => 'ແລກຄະແນນ';

  @override
  String get convertPointsIntoItems => 'ແລກຄະແນນຂອງທ່ານເປັນສິນຄ້າຟຣີ';

  @override
  String get viewClaimVouchers => 'ເບິ່ງ ແລະ ໃຊ້ບັດສ່ວນຫຼຸດທີ່ບັນທຶກໄວ້';

  @override
  String get ranking => 'ອັນດັບ';

  @override
  String get seeTop50 => 'ເບິ່ງຕາຕະລາງອັນດັບ 50 ອັນດັບທຳອິດ';

  @override
  String get customerSupport => 'ຝ່າຍບໍລິການລູກຄ້າ';

  @override
  String get supportChannels => 'Facebook & WhatsApp (ຈາກການຕັ້ງຄ່າຮ້ານ)';

  @override
  String pointsSuffix(String points) {
    return '$points ຄະແນນ';
  }

  @override
  String get couldNotUpdateNotifications =>
      'ອັບເດດການຕັ້ງຄ່າການແຈ້ງເຕືອນບໍ່ໄດ້. ກະລຸນາລອງໃໝ່.';

  @override
  String get notifications => 'ການແຈ້ງເຕືອນ';

  @override
  String get orderUpdatesOnDevice => 'ການອັບເດດອໍເດີໃນເຄື່ອງນີ້';

  @override
  String get pushAlertsOff => 'ການແຈ້ງເຕືອນຖືກປິດຢູ່';

  @override
  String get customization => 'ປັບແຕ່ງ';

  @override
  String get totalPrice => 'ລາຄາລວມ';

  @override
  String get addToCart => 'ເພີ່ມໃສ່ກະຕ່າ';

  @override
  String get navHome => 'ໜ້າຫຼັກ';

  @override
  String get navCart => 'ກະຕ່າ';

  @override
  String get navHistory => 'ປະຫວັດ';

  @override
  String get navProfile => 'ໂປຣໄຟລ໌';

  @override
  String get errorLoadingProducts => 'ໂຫຼດສິນຄ້າຜິດພາດ';

  @override
  String get allProducts => 'ສິນຄ້າທັງໝົດ';

  @override
  String get noItemsFound => 'ບໍ່ພົບລາຍການ';

  @override
  String get recommendedProducts => 'ສິນຄ້າແນະນຳ';

  @override
  String get recommendedBadge => '⭐ ແນະນຳ';

  @override
  String get mostPopular => 'ນິຍົມທີ່ສຸດ';

  @override
  String get freshPicksToday => 'ລາຍການສົດໃໝ່ສຳລັບທ່ານມື້ນີ້';

  @override
  String get bestSeller => 'ຂາຍດີທີ່ສຸດ';

  @override
  String get promoBadge => 'ໂປຣໂມຊັນ';

  @override
  String get selectItemToPreview => 'ເລືອກລາຍການ\nເພື່ອເບິ່ງຕົວຢ່າງ';

  @override
  String get noToppingsSelected => 'ບໍ່ໄດ້ເລືອກເຄື່ອງເສີມ';

  @override
  String toppingsFor(String product) {
    return 'ເຄື່ອງເສີມສຳລັບ $product';
  }

  @override
  String get cartEmpty => 'ກະຕ່າຂອງທ່ານຫວ່າງເປົ່າ';

  @override
  String get addItemsFromHome => 'ເພີ່ມລາຍການຈາກໜ້າຫຼັກ';

  @override
  String get enterCouponCode => 'ປ້ອນລະຫັດຄູປອງ';

  @override
  String get couponApplied2 => 'ໃຊ້ແລ້ວ';

  @override
  String get checkout => 'ຊຳລະເງິນ';

  @override
  String addedToCart(String name) {
    return 'ເພີ່ມ $name ໃສ່ກະຕ່າແລ້ວ';
  }

  @override
  String addedToCartQty(String qty, String name) {
    return 'ເພີ່ມ $name $qty ລາຍການໃສ່ກະຕ່າແລ້ວ';
  }

  @override
  String discountWithCode(String code) {
    return 'ສ່ວນຫຼຸດ ($code)';
  }

  @override
  String get noOrderHistory => 'ຍັງບໍ່ມີປະຫວັດການສັ່ງຊື້';

  @override
  String get completedOrdersHere => 'ອໍເດີທີ່ສຳເລັດແລ້ວຈະສະແດງຢູ່ນີ້.';

  @override
  String get paymentMethodLabel => 'ວິທີການຊຳລະ';

  @override
  String get trackRider => 'ຕິດຕາມໄຣເດີ';

  @override
  String get viewChatHistory => 'ເບິ່ງປະຫວັດການສົນທະນາ';

  @override
  String get chatWithRider => 'ສົນທະນາກັບໄຣເດີ';

  @override
  String get viewOrderDetails => 'ເບິ່ງລາຍລະອຽດອໍເດີ';

  @override
  String get statusComplete => 'ສຳເລັດ';

  @override
  String get statusDelivered => 'ຈັດສົ່ງແລ້ວ';

  @override
  String get statusRiderArrived => 'ໄຣເດີມາຮອດແລ້ວ';

  @override
  String get statusOnTheWay => 'ກຳລັງເດີນທາງ';

  @override
  String get statusPreparing => 'ກຳລັງກຽມ';

  @override
  String get statusCancelled => 'ຍົກເລີກແລ້ວ';

  @override
  String get statusWaitingTransfer => 'ລໍຖ້າການຢືນຢັນການໂອນ';

  @override
  String get statusOrderConfirmed => 'ຢືນຢັນອໍເດີແລ້ວ';

  @override
  String get statusRiderOnWay => 'ໄຣເດີກຳລັງເດີນທາງມາ';

  @override
  String get statusPreparingYourOrder => 'ກຳລັງກຽມອໍເດີຂອງທ່ານ';

  @override
  String get statusTransferVerified => 'ຢືນຢັນການໂອນແລ້ວ, ກຳລັງກຽມອໍເດີ';

  @override
  String get statusArrived => 'ມາຮອດແລ້ວ';

  @override
  String get deliveryProgress => 'ຄວາມຄືບໜ້າການຈັດສົ່ງ';

  @override
  String get arrivingSoon => 'ໃກ້ຮອດແລ້ວ';

  @override
  String get deliveryLocation => 'ຕຳແໜ່ງຈັດສົ່ງ';

  @override
  String get liveRiderTracking => 'ຕິດຕາມໄຣເດີແບບສົດ';

  @override
  String get liveBadge => 'ສົດ';

  @override
  String get fetchingRiderLocation => 'ກຳລັງດຶງຕຳແໜ່ງໄຣເດີ…';

  @override
  String get noLocationData => 'ຍັງບໍ່ມີຂໍ້ມູນຕຳແໜ່ງ';

  @override
  String get riderLocationWillAppear => 'ຕຳແໜ່ງໄຣເດີຈະສະແດງຢູ່ນີ້ເມື່ອມີຂໍ້ມູນ';

  @override
  String get riderLocation => 'ຕຳແໜ່ງໄຣເດີ';

  @override
  String etaLabel(String eta) {
    return 'ຄາດວ່າຈະຮອດ: $eta';
  }

  @override
  String minutesShort(String minutes) {
    return '$minutes ນາທີ';
  }

  @override
  String hoursMinutesShort(String hours, String minutes) {
    return '$hours ຊມ $minutes ນທ';
  }

  @override
  String get noData => 'ບໍ່ມີຂໍ້ມູນ';

  @override
  String get name => 'ຊື່';

  @override
  String get phone => 'ເບີໂທລະສັບ';

  @override
  String get amount => 'ຈຳນວນເງິນ';

  @override
  String get qty => 'ຈຳນວນ';

  @override
  String get item => 'ລາຍການ';

  @override
  String get product => 'ສິນຄ້າ';

  @override
  String get products => 'ສິນຄ້າ';

  @override
  String get categories => 'ໝວດໝູ່';

  @override
  String get toppings => 'ເຄື່ອງເສີມ';

  @override
  String get category => 'ໝວດໝູ່';

  @override
  String get orders => 'ອໍເດີ';

  @override
  String get order => 'ອໍເດີ';

  @override
  String get revenue => 'ລາຍຮັບ';

  @override
  String get transactions => 'ທຸລະກຳ';

  @override
  String get payment => 'ການຊຳລະ';

  @override
  String get confirm => 'ຢືນຢັນ';

  @override
  String get remove => 'ລຶບອອກ';

  @override
  String get keep => 'ເກັບໄວ້';

  @override
  String get reject => 'ປະຕິເສດ';

  @override
  String get call => 'ໂທ';

  @override
  String get newLabel => 'ໃໝ່';

  @override
  String get active => 'ກຳລັງໃຊ້ງານ';

  @override
  String get pending => 'ລໍຖ້າ';

  @override
  String get completed => 'ສຳເລັດແລ້ວ';

  @override
  String get confirmed => 'ຢືນຢັນແລ້ວ';

  @override
  String get defaultLabel => 'ຄ່າເລີ່ມຕົ້ນ';

  @override
  String get disabled => 'ປິດໃຊ້ງານ';

  @override
  String get blocked => 'ຖືກບລັອກ';

  @override
  String get admin => 'ຜູ້ດູແລ';

  @override
  String get system => 'ລະບົບ';

  @override
  String get today => 'ມື້ນີ້';

  @override
  String get yesterday => 'ມື້ວານນີ້';

  @override
  String get today2 => 'ມື້ນີ້';

  @override
  String get yesterday2 => 'ມື້ວານນີ້';

  @override
  String get loadMore => 'ໂຫຼດເພີ່ມ';

  @override
  String get fullscreen => 'ເຕັມຈໍ';

  @override
  String get official => 'ທາງການ';

  @override
  String get unsynced => 'ຍັງບໍ່ໄດ້ຊິງຄ໌';

  @override
  String get percentage => 'ເປີເຊັນ';

  @override
  String get fixedValue => 'ຈຳນວນຄົງທີ່';

  @override
  String get manageCatalog => 'ຈັດການລາຍການສິນຄ້າ';

  @override
  String get manageYourActiveProductCatalog => 'ຈັດການລາຍການສິນຄ້າທີ່ໃຊ້ງານຢູ່';

  @override
  String get organizeProductsIntoGroups => 'ຈັດກຸ່ມສິນຄ້າ';

  @override
  String get addOnsModifiersAndVariations =>
      'ເຄື່ອງເສີມ, ຕົວເລືອກ ແລະ ຮູບແບບຕ່າງໆ';

  @override
  String get manageCategories => 'ຈັດການໝວດໝູ່';

  @override
  String get manageCombos => 'ຈັດການຊຸດອາຫານ';

  @override
  String get manageProducts => 'ຈັດການສິນຄ້າ';

  @override
  String get manageToppings => 'ຈັດການເຄື່ອງເສີມ';

  @override
  String get addProduct => 'ເພີ່ມສິນຄ້າ';

  @override
  String get addCategory => 'ເພີ່ມໝວດໝູ່';

  @override
  String get addCombo => 'ເພີ່ມຊຸດອາຫານ';

  @override
  String get addTopping => 'ເພີ່ມເຄື່ອງເສີມ';

  @override
  String get addYourFirstCategoryToGet => 'ເພີ່ມໝວດໝູ່ທຳອິດເພື່ອເລີ່ມຕົ້ນ';

  @override
  String get addYourFirstComboToGet => 'ເພີ່ມຊຸດອາຫານທຳອິດເພື່ອເລີ່ມຕົ້ນ';

  @override
  String get addYourFirstProductToGet => 'ເພີ່ມສິນຄ້າທຳອິດເພື່ອເລີ່ມຕົ້ນ';

  @override
  String get addYourFirstToppingToGet => 'ເພີ່ມເຄື່ອງເສີມທຳອິດເພື່ອເລີ່ມຕົ້ນ';

  @override
  String get noCategoriesYet => 'ຍັງບໍ່ມີໝວດໝູ່';

  @override
  String get noCombosYet => 'ຍັງບໍ່ມີຊຸດອາຫານ';

  @override
  String get noProductsYet => 'ຍັງບໍ່ມີສິນຄ້າ';

  @override
  String get noToppingsYet => 'ຍັງບໍ່ມີເຄື່ອງເສີມ';

  @override
  String get deleteCategory => 'ລຶບໝວດໝູ່';

  @override
  String get deleteCombo => 'ລຶບຊຸດອາຫານ';

  @override
  String get deleteProduct => 'ລຶບສິນຄ້າ';

  @override
  String get deleteTopping => 'ລຶບເຄື່ອງເສີມ';

  @override
  String get areYouSureYouWantTo => 'ທ່ານແນ່ໃຈບໍວ່າຈະລຶບໝວດໝູ່ນີ້?';

  @override
  String get areYouSureYouWantTo2 => 'ທ່ານແນ່ໃຈບໍວ່າຈະລຶບຊຸດອາຫານນີ້?';

  @override
  String get areYouSureYouWantTo3 => 'ທ່ານແນ່ໃຈບໍວ່າຈະລຶບສິນຄ້ານີ້?';

  @override
  String get areYouSureYouWantTo4 => 'ທ່ານແນ່ໃຈບໍວ່າຈະລຶບເຄື່ອງເສີມນີ້?';

  @override
  String get categoryDeleted => 'ລຶບໝວດໝູ່ແລ້ວ';

  @override
  String get comboDeleted => 'ລຶບຊຸດອາຫານແລ້ວ';

  @override
  String get productDeleted => 'ລຶບສິນຄ້າແລ້ວ';

  @override
  String get toppingDeleted => 'ລຶບເຄື່ອງເສີມແລ້ວ';

  @override
  String get visibleInApp => 'ສະແດງໃນແອັບ';

  @override
  String get hiddenInApp => 'ເຊື່ອງໃນແອັບ';

  @override
  String get categoryName => 'ຊື່ໝວດໝູ່*';

  @override
  String get comboName => 'ຊື່ຊຸດອາຫານ*';

  @override
  String get comboFixedPrice => 'ລາຄາຄົງທີ່ຂອງຊຸດ*';

  @override
  String get productName => 'ຊື່ສິນຄ້າ*';

  @override
  String get toppingName => 'ຊື່ເຄື່ອງເສີມ*';

  @override
  String get listPrice => 'ລາຄາຂາຍ*';

  @override
  String get extraPriceOptional => 'ລາຄາເພີ່ມ (ບໍ່ບັງຄັບ)';

  @override
  String get saveCategory => 'ບັນທຶກໝວດໝູ່';

  @override
  String get saveCombo => 'ບັນທຶກຊຸດອາຫານ';

  @override
  String get saveProduct => 'ບັນທຶກສິນຄ້າ';

  @override
  String get saveTopping => 'ບັນທຶກເຄື່ອງເສີມ';

  @override
  String get categoryAddedSuccessfully => 'ເພີ່ມໝວດໝູ່ສຳເລັດແລ້ວ';

  @override
  String get categoryUpdatedSuccessfully => 'ອັບເດດໝວດໝູ່ສຳເລັດແລ້ວ';

  @override
  String get comboSavedSuccessfully => 'ບັນທຶກຊຸດອາຫານສຳເລັດແລ້ວ';

  @override
  String get productSavedSuccessfully => 'ບັນທຶກສິນຄ້າສຳເລັດແລ້ວ';

  @override
  String get toppingSavedSuccessfully => 'ບັນທຶກເຄື່ອງເສີມສຳເລັດແລ້ວ';

  @override
  String get nameIsRequired => 'ຕ້ອງປ້ອນຊື່';

  @override
  String get validNameAndPriceAreRequired => 'ຕ້ອງປ້ອນຊື່ ແລະ ລາຄາທີ່ຖືກຕ້ອງ';

  @override
  String get comboMustHaveAtLeastOne => 'ຊຸດອາຫານຕ້ອງມີສິນຄ້າຢ່າງໜ້ອຍ 1 ລາຍການ';

  @override
  String get comboItems => 'ລາຍການໃນຊຸດ';

  @override
  String get noProductsAddedToThisCombo => 'ຍັງບໍ່ໄດ້ເພີ່ມສິນຄ້າໃສ່ຊຸດນີ້.';

  @override
  String get availableToppings => 'ເຄື່ອງເສີມທີ່ມີ';

  @override
  String get noToppingsConfigured => 'ຍັງບໍ່ໄດ້ຕັ້ງຄ່າເຄື່ອງເສີມ.';

  @override
  String get showInApp => 'ສະແດງໃນແອັບ';

  @override
  String get onlyCheckedCategoriesAreVisibleIn =>
      'ສະເພາະໝວດໝູ່ທີ່ຕິກເທົ່ານັ້ນທີ່ຈະສະແດງໃນແອັບ POS.';

  @override
  String get customerSelfOrder => 'ລູກຄ້າສັ່ງເອງ';

  @override
  String get customersCanSelectAndOrder => 'ລູກຄ້າສາມາດເລືອກ ແລະ ສັ່ງໄດ້';

  @override
  String get runOutBlocked => 'ໝົດແລ້ວ (ບລັອກ)';

  @override
  String get shownAsRunOutCannotAdd => 'ສະແດງວ່າໝົດແລ້ວ; ບໍ່ສາມາດເພີ່ມໃສ່ກະຕ່າ';

  @override
  String get couldNotSaveToppingPleaseTry =>
      'ບັນທຶກເຄື່ອງເສີມບໍ່ໄດ້. ກະລຸນາລອງໃໝ່.';

  @override
  String get currentTicket2 => 'ບິນປັດຈຸບັນ';

  @override
  String get newItems => 'ລາຍການໃໝ່';

  @override
  String get alreadyOrdered => 'ສັ່ງໄປແລ້ວ';

  @override
  String get noItems => 'ບໍ່ມີລາຍການ';

  @override
  String get noItemsInTicket => 'ບໍ່ມີລາຍການໃນບິນ';

  @override
  String get addCustomer => 'ເພີ່ມລູກຄ້າ';

  @override
  String get clearTicket2 => 'ລຶບບິນ';

  @override
  String get saveTicket => 'ບັນທຶກບິນ';

  @override
  String get charge2 => 'ຮັບເງິນ';

  @override
  String get subtotalExclVat => 'ຍອດຍ່ອຍ (ບໍ່ລວມ VAT)';

  @override
  String get amountExclVat2 => 'ຈຳນວນເງິນ (ບໍ່ລວມ VAT)';

  @override
  String get includesVat => 'ລວມ VAT ແລ້ວ';

  @override
  String get priceIncludesTax => 'ລາຄາລວມພາສີແລ້ວ';

  @override
  String get taxHiddenOnReceipt => 'ເຊື່ອງພາສີໃນໃບຮັບເງິນ';

  @override
  String get totalDue => 'ຍອດທີ່ຕ້ອງຊຳລະ';

  @override
  String get selectCustomer => 'ເລືອກລູກຄ້າ';

  @override
  String get addCustomer2 => 'ເພີ່ມລູກຄ້າ';

  @override
  String get newCustomer => 'ລູກຄ້າໃໝ່';

  @override
  String get addCustomerIfNotFound => 'ເພີ່ມລູກຄ້າຖ້າຫາບໍ່ພົບ';

  @override
  String get searchByNameOrPhone => 'ຄົ້ນຫາດ້ວຍຊື່ ຫຼື ເບີໂທ...';

  @override
  String get loadingCustomers => 'ກຳລັງໂຫຼດຂໍ້ມູນລູກຄ້າ...';

  @override
  String get noCustomersFound => 'ບໍ່ພົບລູກຄ້າ';

  @override
  String get searchFailedPleaseTryAgain => 'ຄົ້ນຫາບໍ່ສຳເລັດ. ກະລຸນາລອງໃໝ່.';

  @override
  String get couldNotCreateCustomerPleaseTry =>
      'ສ້າງລູກຄ້າບໍ່ໄດ້. ກະລຸນາລອງໃໝ່.';

  @override
  String get couldNotLoadMorePleaseTry => 'ໂຫຼດເພີ່ມບໍ່ໄດ້. ກະລຸນາລອງໃໝ່.';

  @override
  String get noOpenTickets => 'ບໍ່ມີບິນທີ່ເປີດຢູ່';

  @override
  String get noTable2 => 'ບໍ່ມີໂຕະ';

  @override
  String get orderReady => 'ອໍເດີພ້ອມແລ້ວ';

  @override
  String get discountCustomItem => 'ສ່ວນຫຼຸດ / ລາຍການກຳນົດເອງ';

  @override
  String get couldNotLoadTicketsPleaseCheck =>
      'ໂຫຼດບິນບໍ່ໄດ້. ກະລຸນາກວດການເຊື່ອມຕໍ່ ແລ້ວລອງໃໝ່.';

  @override
  String get couldNotSendNotificationPleaseTry =>
      'ສົ່ງການແຈ້ງເຕືອນບໍ່ໄດ້. ກະລຸນາລອງໃໝ່.';

  @override
  String get splitTicket => 'ແຍກບິນ';

  @override
  String get ticketName => 'ຊື່ບິນ';

  @override
  String get renameNewTicket => 'ປ່ຽນຊື່ບິນໃໝ່';

  @override
  String get allItemsMoved => 'ຍ້າຍລາຍການທັງໝົດແລ້ວ';

  @override
  String get pleaseMoveAtLeastOneItem => 'ກະລຸນາຍ້າຍຢ່າງໜ້ອຍ 1 ລາຍການໄປບິນໃໝ່.';

  @override
  String get theOriginalTicketCannotBeEmpty =>
      'ບິນເດີມຫວ່າງເປົ່າບໍ່ໄດ້. ຕ້ອງເກັບໄວ້ຢ່າງໜ້ອຍ 1 ລາຍການ.';

  @override
  String get tapItemsOnTheLeftTo => 'ແຕະລາຍການເບື້ອງຊ້າຍ\nເພື່ອຍ້າຍມາບ່ອນນີ້';

  @override
  String get discountOptions => 'ຕົວເລືອກສ່ວນຫຼຸດ';

  @override
  String get addDiscountOption => 'ເພີ່ມຕົວເລືອກສ່ວນຫຼຸດ';

  @override
  String get discountType => 'ປະເພດສ່ວນຫຼຸດ';

  @override
  String get enableDiscount => 'ເປີດໃຊ້ສ່ວນຫຼຸດ';

  @override
  String get discountHidden => 'ເຊື່ອງສ່ວນຫຼຸດ';

  @override
  String get discountWillAppearInPos => 'ສ່ວນຫຼຸດຈະສະແດງໃນ POS';

  @override
  String get discountSettingsSaved => 'ບັນທຶກການຕັ້ງຄ່າສ່ວນຫຼຸດແລ້ວ';

  @override
  String get noDiscountOptionsAddedYet => 'ຍັງບໍ່ໄດ້ເພີ່ມຕົວເລືອກສ່ວນຫຼຸດ.';

  @override
  String get optionName => 'ຊື່ຕົວເລືອກ';

  @override
  String get percentage2 => 'ເປີເຊັນ (%)';

  @override
  String get leaveEmptyForManualInput => 'ປະຫວ່າງໄວ້ເພື່ອໃຫ້ປ້ອນເອງ';

  @override
  String get tipLeaveTheValueBlankTo =>
      'ຄຳແນະນຳ: ປະຄ່າຫວ່າງໄວ້ ເພື່ອໃຫ້ພະນັກງານປ້ອນຈຳນວນເອງ.';

  @override
  String get receiptsHistory => 'ປະຫວັດໃບຮັບເງິນ';

  @override
  String get noPaidReceiptsYet => 'ຍັງບໍ່ມີໃບຮັບເງິນທີ່ຊຳລະແລ້ວ';

  @override
  String get noMoreReceipts => 'ບໍ່ມີໃບຮັບເງິນເພີ່ມ';

  @override
  String get unknownDate => 'ບໍ່ຮູ້ວັນທີ';

  @override
  String get thisReceiptIsMissingAnOrder =>
      'ໃບຮັບເງິນນີ້ບໍ່ມີລະຫັດອໍເດີ. ກະລຸນາໂຫຼດຄືນ ແລ້ວລອງໃໝ່.';

  @override
  String get refund => 'ຄືນເງິນ';

  @override
  String get refundOrder => 'ຄືນເງິນອໍເດີ';

  @override
  String get confirmRefund => 'ຢືນຢັນການຄືນເງິນ';

  @override
  String get reprintReceipt => 'ພິມໃບຮັບເງິນຄືນ';

  @override
  String get adminPin => 'PIN ຜູ້ດູແລ';

  @override
  String get adminPinIsRequired => 'ຕ້ອງປ້ອນ PIN ຜູ້ດູແລ.';

  @override
  String get thisOrderHasBeenRefunded => 'ອໍເດີນີ້ຖືກຄືນເງິນແລ້ວ';

  @override
  String get printerErrorCheckConnection =>
      'ເຄື່ອງພິມຜິດພາດ. ກະລຸນາກວດການເຊື່ອມຕໍ່.';

  @override
  String get orderRefundedSuccessfully => '✅ ຄືນເງິນອໍເດີສຳເລັດແລ້ວ.';

  @override
  String get receiptReprinted => '🖨️ ພິມໃບຮັບເງິນຄືນແລ້ວ!';

  @override
  String get noPendingSelfOrders => 'ບໍ່ມີອໍເດີລູກຄ້າທີ່ລໍຖ້າ';

  @override
  String get quickConfirm => 'ຢືນຢັນດ່ວນ';

  @override
  String get rejectOrder => 'ປະຕິເສດອໍເດີ';

  @override
  String get rejectOrder2 => 'ປະຕິເສດອໍເດີ?';

  @override
  String get orderRejectedAndCancelled => 'ປະຕິເສດ ແລະ ຍົກເລີກອໍເດີແລ້ວ.';

  @override
  String get transferConfirmedOrderMovedToOpen =>
      'ຢືນຢັນການໂອນແລ້ວ. ຍ້າຍອໍເດີໄປບິນທີ່ເປີດຢູ່.';

  @override
  String get couldNotConfirmOrderPleaseTry =>
      'ຢືນຢັນອໍເດີບໍ່ໄດ້. ກະລຸນາລອງໃໝ່.';

  @override
  String get couldNotRejectOrderPleaseTry =>
      'ປະຕິເສດອໍເດີບໍ່ໄດ້. ກະລຸນາລອງໃໝ່.';

  @override
  String get couldNotLoadOrdersPleaseCheck =>
      'ໂຫຼດອໍເດີບໍ່ໄດ້. ກະລຸນາກວດການເຊື່ອມຕໍ່ ແລ້ວລອງໃໝ່.';

  @override
  String get viewProof => 'ເບິ່ງຫຼັກຖານ';

  @override
  String get noProofImageUploaded => 'ບໍ່ໄດ້ອັບໂຫຼດຮູບຫຼັກຖານ';

  @override
  String get cannotLoadProofImage => 'ໂຫຼດຮູບຫຼັກຖານບໍ່ໄດ້';

  @override
  String get bankTransfer => 'ໂອນຜ່ານທະນາຄານ';

  @override
  String get payAtStore2 => 'ຈ່າຍທີ່ຮ້ານ';

  @override
  String get customerPlace => 'ສະຖານທີ່ລູກຄ້າ:';

  @override
  String get orderNotePickupTime => 'ໝາຍເຫດ / ເວລາຮັບເຄື່ອງ:';

  @override
  String get openMap => 'ເປີດແຜນທີ່';

  @override
  String get callCustomer => 'ໂທຫາລູກຄ້າ?';

  @override
  String get dashboard => 'ພາບລວມ';

  @override
  String get currentOrders => 'ອໍເດີປັດຈຸບັນ';

  @override
  String get orderHistory => 'ປະຫວັດອໍເດີ';

  @override
  String get ordersByStatus => 'ອໍເດີຕາມສະຖານະ';

  @override
  String get totalOrders => 'ອໍເດີທັງໝົດ';

  @override
  String get totalRevenue => 'ລາຍຮັບທັງໝົດ';

  @override
  String get onTheWay => 'ກຳລັງເດີນທາງ';

  @override
  String get noCurrentOrders => 'ບໍ່ມີອໍເດີປັດຈຸບັນ';

  @override
  String get noHistoryYet => 'ຍັງບໍ່ມີປະຫວັດ';

  @override
  String get activeOrdersWillAppearHere => 'ອໍເດີທີ່ກຳລັງດຳເນີນຈະສະແດງຢູ່ນີ້';

  @override
  String get completedOrdersWillAppearHere => 'ອໍເດີທີ່ສຳເລັດແລ້ວຈະສະແດງຢູ່ນີ້';

  @override
  String get actionFailedPleaseTryAgain => 'ດຳເນີນການບໍ່ສຳເລັດ. ກະລຸນາລອງໃໝ່.';

  @override
  String get chatWithCustomer => 'ສົນທະນາກັບລູກຄ້າ';

  @override
  String get navigateInApp => 'ນຳທາງ (ໃນແອັບ)';

  @override
  String get openInGoogleMapsApp => 'ເປີດໃນແອັບ Google Maps';

  @override
  String get deliveryTarget => 'ຈຸດໝາຍການຈັດສົ່ງ';

  @override
  String get youRider => 'ທ່ານ (ໄຣເດີ)';

  @override
  String get callCustomer2 => 'ໂທຫາລູກຄ້າ';

  @override
  String get refreshRoute => 'ໂຫຼດເສັ້ນທາງຄືນ';

  @override
  String get fitRouteOnScreen => 'ຈັດເສັ້ນທາງໃຫ້ພໍດີຈໍ';

  @override
  String get openInExternalGoogleMapsApp => 'ເປີດໃນແອັບ Google Maps ພາຍນອກ';

  @override
  String get couldNotLaunchDialer => 'ເປີດແອັບໂທບໍ່ໄດ້';

  @override
  String get couldNotLaunchExternalMapsApplication =>
      'ເປີດແອັບແຜນທີ່ພາຍນອກບໍ່ໄດ້';

  @override
  String get statusUpdatedToArrived => 'ອັບເດດສະຖານະເປັນ ມາຮອດແລ້ວ';

  @override
  String get statusUpdatedToCompleteDelivered =>
      'ອັບເດດສະຖານະເປັນ ສຳເລັດ / ຈັດສົ່ງແລ້ວ';

  @override
  String get noMessagesYet => 'ຍັງບໍ່ມີຂໍ້ຄວາມ';

  @override
  String get startTheConversationBelow => 'ເລີ່ມສົນທະນາຢູ່ດ້ານລຸ່ມ';

  @override
  String get typeAMessage => 'ພິມຂໍ້ຄວາມ…';

  @override
  String get sendImage => 'ສົ່ງຮູບ';

  @override
  String get sendImage2 => 'ສົ່ງຮູບ';

  @override
  String get takeAPhoto => 'ຖ່າຍຮູບ';

  @override
  String get chooseFromGallery => 'ເລືອກຈາກຄັງຮູບ';

  @override
  String get addACaptionOptional => 'ເພີ່ມຄຳບັນຍາຍ (ບໍ່ບັງຄັບ)';

  @override
  String get imageReadyToSend => 'ຮູບພ້ອມສົ່ງແລ້ວ';

  @override
  String get couldNotLoadImage => 'ໂຫຼດຮູບບໍ່ໄດ້';

  @override
  String get couldNotLoadMessages => 'ໂຫຼດຂໍ້ຄວາມບໍ່ໄດ້.';

  @override
  String get failedToSendImagePleaseTry => 'ສົ່ງຮູບບໍ່ສຳເລັດ. ກະລຸນາລອງໃໝ່.';

  @override
  String get failedToSendMessagePleaseTry =>
      'ສົ່ງຂໍ້ຄວາມບໍ່ສຳເລັດ. ກະລຸນາລອງໃໝ່.';

  @override
  String get sendingImage => '📷 ກຳລັງສົ່ງຮູບ…';

  @override
  String get printers => 'ເຄື່ອງພິມ';

  @override
  String get addPrinter => 'ເພີ່ມເຄື່ອງພິມ';

  @override
  String get deletePrinter => 'ລຶບເຄື່ອງພິມ';

  @override
  String get printerSaved => 'ບັນທຶກເຄື່ອງພິມແລ້ວ';

  @override
  String get printerDeleted => 'ລຶບເຄື່ອງພິມແລ້ວ';

  @override
  String get printerTestSuccessful => 'ທົດສອບເຄື່ອງພິມສຳເລັດ.';

  @override
  String get printerTestFailed => 'ທົດສອບເຄື່ອງພິມບໍ່ສຳເລັດ.';

  @override
  String get printTest => 'ທົດສອບການພິມ';

  @override
  String get printerIpAddress => 'ທີ່ຢູ່ IP ຂອງເຄື່ອງພິມ';

  @override
  String get port => 'ພອດ';

  @override
  String get paperWidth => 'ຄວາມກວ້າງເຈ້ຍ';

  @override
  String get advancedSettings => 'ການຕັ້ງຄ່າຂັ້ນສູງ';

  @override
  String get categoryRouting => 'ການກຳນົດເສັ້ນທາງໝວດໝູ່';

  @override
  String get noCategoriesFound => 'ບໍ່ພົບໝວດໝູ່';

  @override
  String get ifNoneSelectedAllCategoriesWill =>
      'ຖ້າບໍ່ເລືອກຫຍັງ ທຸກໝວດໝູ່ຈະພິມອອກເຄື່ອງນີ້.';

  @override
  String get printReceiptsAndBills => 'ພິມໃບຮັບເງິນ ແລະ ບິນ';

  @override
  String get printOrders => 'ພິມອໍເດີ';

  @override
  String get defaultPrinterForReceipts => 'ເຄື່ອງພິມຫຼັກສຳລັບໃບຮັບເງິນ';

  @override
  String get printSingleItemPerOrderTicket => 'ພິມ 1 ລາຍການຕໍ່ 1 ບິນຄົວ';

  @override
  String get groupIdenticalItemsInOrderTickets => 'ລວມລາຍການທີ່ຄືກັນໃນບິນຄົວ';

  @override
  String get noPrintersYet => 'ຍັງບໍ່ມີເຄື່ອງພິມ';

  @override
  String get tapToAddYourFirstPrinter =>
      'ແຕະ + ເພື່ອເພີ່ມເຄື່ອງພິມທຳອິດ.\nຕັ້ງຄ່າໃບຮັບເງິນ, ອໍເດີ ແລະ ໝວດໝູ່.';

  @override
  String get receipt => 'ໃບຮັບເງິນ';

  @override
  String get billPreReceipt => 'ບິນ (ກ່ອນຮັບເງິນ)';

  @override
  String get receiptPaid => 'ໃບຮັບເງິນ (ຊຳລະແລ້ວ)';

  @override
  String get kitchenOrderTicket => 'ບິນຄົວ / ບິນອໍເດີ';

  @override
  String get kitchenOrderTicket2 => 'ບິນຄົວ / ບິນອໍເດີ';

  @override
  String get refundVoid => 'ຄືນເງິນ / ຍົກເລີກ';

  @override
  String get savedTemplateSettings => 'ບັນທຶກການຕັ້ງຄ່າແມ່ແບບແລ້ວ.';

  @override
  String get noTemplateSelectedPreviewUnavailable =>
      'ຍັງບໍ່ໄດ້ເລືອກແມ່ແບບ — ບໍ່ມີຕົວຢ່າງ';

  @override
  String get adminReports => 'ລາຍງານຜູ້ດູແລ';

  @override
  String get allBranches => 'ທຸກສາຂາ';

  @override
  String get selectDateRange => 'ເລືອກຊ່ວງວັນທີ';

  @override
  String get salesByDate => 'ຍອດຂາຍຕາມວັນທີ';

  @override
  String get salesByPaymentType => 'ຍອດຂາຍຕາມປະເພດການຊຳລະ';

  @override
  String get salesByProductTop => 'ຍອດຂາຍຕາມສິນຄ້າ (ສູງສຸດ)';

  @override
  String get paymentType => 'ປະເພດການຊຳລະ';

  @override
  String get peakOrderHours => 'ຊົ່ວໂມງທີ່ສັ່ງຫຼາຍທີ່ສຸດ';

  @override
  String get noHourlyPeakDataAvailable => 'ບໍ່ມີຂໍ້ມູນຊົ່ວໂມງສູງສຸດ';

  @override
  String get noOrderTrafficRecordedInThis => 'ບໍ່ມີການສັ່ງຊື້ໃນຊ່ວງເວລານີ້.';

  @override
  String get branchRanking => 'ອັນດັບສາຂາ';

  @override
  String get forbiddenAdminOnly => 'ບໍ່ອະນຸຍາດ (ສະເພາະຜູ້ດູແລ)';

  @override
  String get cannotLoadRanking => 'ໂຫຼດອັນດັບບໍ່ໄດ້';

  @override
  String get climbTheAdventureLadder => 'ໄຕ່ອັນດັບຂຶ້ນໄປ!';

  @override
  String get yourRank => 'ອັນດັບຂອງທ່ານ: -';

  @override
  String get enterPinToUnlock => 'ປ້ອນ PIN ເພື່ອປົດລັອກ';

  @override
  String get createYour4DigitPin => 'ສ້າງ PIN 4 ຫຼັກຂອງທ່ານ';

  @override
  String get confirmYourNewPin => 'ຢືນຢັນ PIN ໃໝ່ຂອງທ່ານ';

  @override
  String get incorrectPin => 'PIN ບໍ່ຖືກຕ້ອງ';

  @override
  String get pinMismatchOrSaveFailed => 'PIN ບໍ່ກົງກັນ ຫຼື ບັນທຶກບໍ່ສຳເລັດ';

  @override
  String get switchUser => 'ປ່ຽນຜູ້ໃຊ້';

  @override
  String get setPosName => 'ຕັ້ງຊື່ເຄື່ອງ POS';

  @override
  String get posNameExCounter1Ipad =>
      'ຊື່ເຄື່ອງ POS (ຕົວຢ່າງ: Counter-1, iPad-Bar)';

  @override
  String get pleaseEnterAPosName => 'ກະລຸນາປ້ອນຊື່ເຄື່ອງ POS';

  @override
  String get posNameIsTooShort => 'ຊື່ເຄື່ອງ POS ສັ້ນເກີນໄປ';

  @override
  String get posNameIsTooLong => 'ຊື່ເຄື່ອງ POS ຍາວເກີນໄປ';

  @override
  String get thisHelpsTrackWhichDeviceWas =>
      'ຊ່ວຍໃຫ້ຮູ້ວ່າໃຊ້ເຄື່ອງໃດເມື່ອມີບັນຫາເກີດຂຶ້ນ.';

  @override
  String get refreshingMenusTablesAndSalesData =>
      'ກຳລັງໂຫຼດເມນູ, ໂຕະ ແລະ ຂໍ້ມູນການຂາຍສຳລັບເຄື່ອງນີ້';

  @override
  String get returnToLogin => 'ກັບໄປໜ້າເຂົ້າສູ່ລະບົບ';

  @override
  String get networkErrorAndNoOfflineCache =>
      'ເຄືອຂ່າຍຜິດພາດ ແລະ ບໍ່ມີຂໍ້ມູນອອບໄລນ໌.\nກະລຸນາເຊື່ອມຕໍ່ອິນເຕີເນັດ.';

  @override
  String get maintenanceMode => 'ໂໝດບຳລຸງຮັກສາ';

  @override
  String get reachTheAdmin => 'ຕິດຕໍ່ຜູ້ດູແລ';

  @override
  String get useTheOptionsYourStoreHas =>
      'ໃຊ້ຊ່ອງທາງທີ່ຮ້ານຂອງທ່ານເປີດໄວ້ໃນ Odoo.';

  @override
  String get openFacebook => 'ເປີດ Facebook';

  @override
  String get openInWhatsapp => 'ເປີດໃນ WhatsApp';

  @override
  String get notConfiguredAskStaffToSet =>
      'ຍັງບໍ່ໄດ້ຕັ້ງຄ່າ. ກະລຸນາແຈ້ງພະນັກງານໃຫ້ຕັ້ງ Facebook URL ໃນ Odoo.';

  @override
  String get notConfiguredAskStaffToSet2 =>
      'ຍັງບໍ່ໄດ້ຕັ້ງຄ່າ. ກະລຸນາແຈ້ງພະນັກງານໃຫ້ຕັ້ງເບີ WhatsApp ໃນ Odoo.';

  @override
  String get ladolcePrivacy => 'ຄວາມເປັນສ່ວນຕົວ LaDolce';

  @override
  String get failedToLoadPrivacyPolicyPlease =>
      'ໂຫຼດນະໂຍບາຍຄວາມເປັນສ່ວນຕົວບໍ່ສຳເລັດ. ກະລຸນາກວດການເຊື່ອມຕໍ່ ແລ້ວລອງໃໝ່.';

  @override
  String get orderItems => 'ລາຍການອໍເດີ';

  @override
  String get transferProof => 'ຫຼັກຖານການໂອນ';

  @override
  String get noLineItems => 'ບໍ່ມີລາຍການ';

  @override
  String get waitingReview => 'ລໍຖ້າການກວດ';

  @override
  String get complete => 'ສຳເລັດ';

  @override
  String get delivered => 'ຈັດສົ່ງແລ້ວ';

  @override
  String get cancelled => 'ຍົກເລີກແລ້ວ';

  @override
  String get offline => '⚡ ອອບໄລນ໌';
}
