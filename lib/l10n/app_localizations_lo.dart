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
}
