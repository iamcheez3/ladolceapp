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
}
