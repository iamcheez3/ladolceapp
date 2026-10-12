import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'printer_settings_screen.dart';
import 'bill_template_settings_screen.dart';
import 'discount_config_screen.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../theme/ladolce_pos_ui.dart';
import '../models/pos_discount_config.dart';
import '../models/product.dart';
import '../utils/l10n_ext.dart';
import '../main.dart';

class PosSettingsScreen extends StatefulWidget {
  const PosSettingsScreen({super.key});

  @override
  State<PosSettingsScreen> createState() => _PosSettingsScreenState();
}

class _PosSettingsScreenState extends State<PosSettingsScreen> {
  final ApiService _apiService = ApiService();
  PosDiscountConfig _discountConfig = PosDiscountConfig.disabled;
  bool _usePromotionPrice = true;

  @override
  void initState() {
    super.initState();
    _loadDiscountConfig();
    _loadPromotionPriceSetting();
  }

  Future<void> _loadDiscountConfig() async {
    final cfg = await PosDiscountConfig.load();
    if (mounted) setState(() => _discountConfig = cfg);
  }

  Future<void> _loadPromotionPriceSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _usePromotionPrice = prefs.getBool('pos_use_promotion_price') ?? true;
      });
    }
  }

  Future<void> _setPromotionPriceSetting(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pos_use_promotion_price', val);
    Product.disablePromotionPrice = !val;
    if (mounted) {
      setState(() {
        _usePromotionPrice = val;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.appSettings),
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuCard(
            context,
            icon: Icons.print,
            title: context.l10n.printerConfiguration,
            subtitle: printerService.profiles.isNotEmpty
                ? '${printerService.profiles.length} printer(s) configured'
                : (printerService.isConfigured
                      ? 'Connected: ${printerService.printerIp}'
                      : 'Not configured'),
            subtitleColor: printerService.isConfigured ? Colors.green : null,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrinterSettingsScreen(),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            icon: Icons.receipt_long_rounded,
            title: context.l10n.billTemplates,
            subtitle: context.l10n.billTemplatesSubtitle,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BillTemplateSettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            icon: Icons.discount_outlined,
            title: context.l10n.discountConfiguration,
            subtitle: _discountConfig.enabled
                ? '${_discountConfig.options.length} discount option(s) configured'
                : 'Not configured',
            subtitleColor: _discountConfig.enabled ? Colors.green : null,
            onTap: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DiscountConfigScreen(initialConfig: _discountConfig),
                ),
              );
              if (changed == true) _loadDiscountConfig();
            },
          ),
          const SizedBox(height: 12),
          _buildToggleCard(
            icon: Icons.campaign_outlined,
            title: context.l10n.usePromotionPrice,
            subtitle: _usePromotionPrice
                ? 'Promotional prices will be applied'
                : 'Normal base prices will be applied',
            value: _usePromotionPrice,
            onChanged: _setPromotionPriceSetting,
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            icon: Icons.language_rounded,
            title: context.l10n.language,
            subtitle: Localizations.localeOf(context).languageCode == 'lo'
                ? context.l10n.laoLanguage
                : 'English',
            onTap: () => _showLanguagePicker(context),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final currentLanguage = Localizations.localeOf(context).languageCode;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: LaDolcePosUi.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.chooseAppLanguage,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: LaDolcePosUi.text,
                ),
              ),
              const SizedBox(height: 12),
              _languageOption(
                context: context,
                label: 'English',
                languageCode: 'en',
                selected: currentLanguage == 'en',
              ),
              _languageOption(
                context: context,
                label: context.l10n.laoLanguage,
                languageCode: 'lo',
                selected: currentLanguage == 'lo',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _languageOption({
    required BuildContext context,
    required String label,
    required String languageCode,
    required bool selected,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: LaDolcePosUi.navy)
          : null,
      onTap: () {
        Navigator.pop(context);
        if (!selected) PosApp.setLocale(context, Locale(languageCode));
      },
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: LaDolcePosUi.card,
        borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
        border: Border.all(color: LaDolcePosUi.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: LaDolcePosUi.navy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: LaDolcePosUi.navy.withValues(alpha: 0.14),
              ),
            ),
            child: Icon(icon, color: LaDolcePosUi.navy, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: LaDolcePosUi.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: LaDolcePosUi.mutedText,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: LaDolcePosUi.navy,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? subtitleColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LaDolcePosUi.card,
          borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
          border: Border.all(color: LaDolcePosUi.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: LaDolcePosUi.navy.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: LaDolcePosUi.navy.withValues(alpha: 0.14),
                ),
              ),
              child: Icon(icon, color: LaDolcePosUi.navy, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: LaDolcePosUi.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subtitleColor ?? LaDolcePosUi.mutedText,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, color: LaDolcePosUi.mutedText),
          ],
        ),
      ),
    );
  }
}
