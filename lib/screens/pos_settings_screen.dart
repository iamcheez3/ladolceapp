import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'printer_settings_screen.dart';
import 'bill_template_settings_screen.dart';
import 'discount_config_screen.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../theme/ladolce_pos_ui.dart';
import '../models/pos_discount_config.dart';
import '../models/product.dart';
import '../services/app_update_service.dart';
import '../widgets/app_update_flow.dart';
import '../utils/money.dart';

class PosSettingsScreen extends StatefulWidget {
  const PosSettingsScreen({super.key});

  @override
  State<PosSettingsScreen> createState() => _PosSettingsScreenState();
}

class _PosSettingsScreenState extends State<PosSettingsScreen> {
  final ApiService _apiService = ApiService();

  AppLocalizations? get _l10n => AppLocalizations.of(context);
  PosDiscountConfig _discountConfig = PosDiscountConfig.disabled;
  bool _usePromotionPrice = true;
  InstalledVersion? _installedVersion;
  List<Map<String, dynamic>> _rejected = const [];

  /// Lets staff flip the app between English and Lao. PosApp.setLocale
  /// persists the choice, so it survives a restart and applies app-wide.
  Future<void> _showLanguagePicker() async {
    final current = Localizations.localeOf(context).languageCode;
    await showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(_l10n?.chooseAppLanguage ?? 'Choose the app language'),
        children: [
          for (final option in const [
            ['en', 'English'],
            ['lo', 'ລາວ'],
          ])
            ListTile(
              title: Text(option[1]),
              trailing: current == option[0]
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                PosApp.setLocale(context, Locale(option[0], ''));
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadDiscountConfig();
    _loadPromotionPriceSetting();
    AppUpdateService().installedVersion().then((v) {
      if (mounted) setState(() => _installedVersion = v);
    });
    _apiService.rejectedOrders().then((r) {
      if (mounted) setState(() => _rejected = r);
    });
  }

  Future<void> _showRejected() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_l10n?.notSavedTitle ?? 'Not saved by the server'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(_l10n?.notSavedListHelp ??
                  'Sales or tickets the server refused. Check them in Odoo and enter them again if needed.'),
              const SizedBox(height: 8),
              for (final r in _rejected.reversed)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${(r['at'] ?? '').toString().replaceFirst('T', ' ').split('.').first}  ·  ₭${money(r['total'] as num?)}'),
                  subtitle: Text((r['reason'] ?? '').toString()),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_l10n?.clear ?? 'Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_l10n?.close ?? 'Close'),
          ),
        ],
      ),
    );
    if (clear == true) {
      await _apiService.clearRejectedOrders();
      if (mounted) setState(() => _rejected = const []);
    }
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
        title: Text(_l10n?.appSettings ?? 'App Settings'),
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        // Last tile (App update) stays above the navigation bar.
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
        children: [
          _buildMenuCard(
            context,
            icon: Icons.print,
            title: _l10n?.printerConfiguration ?? 'Printer Configuration',
            subtitle: printerService.profiles.isNotEmpty
                ? (_l10n?.printersConfigured('${printerService.profiles.length}') ??
                      '${printerService.profiles.length} printer(s) configured')
                : (printerService.isConfigured
                    ? (_l10n?.connectedTo('${printerService.printerIp}') ??
                      'Connected: ${printerService.printerIp}')
                    : (_l10n?.notConfigured ?? 'Not configured')),
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
            title: _l10n?.billTemplates ?? 'Bill Templates',
            subtitle:
                _l10n?.billTemplatesSubtitle ??
                'Select bill/receipt/refund templates for this branch',
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
            title: _l10n?.discountConfiguration ?? 'Discount Configuration',
            subtitle: _discountConfig.enabled
                ? (_l10n?.discountOptionsConfigured(
                        '${_discountConfig.options.length}',
                      ) ??
                      '${_discountConfig.options.length} discount option(s) configured')
                : (_l10n?.notConfigured ?? 'Not configured'),
            subtitleColor: _discountConfig.enabled ? Colors.green : null,
            onTap: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => DiscountConfigScreen(
                    initialConfig: _discountConfig,
                  ),
                ),
              );
              if (changed == true) _loadDiscountConfig();
            },
          ),
          const SizedBox(height: 12),
          _buildToggleCard(
            icon: Icons.campaign_outlined,
            title: _l10n?.usePromotionPrice ?? 'Use Promotion Price in POS',
            subtitle: _usePromotionPrice
                ? (_l10n?.promotionalPricesApplied ??
                      'Promotional prices will be applied')
                : (_l10n?.normalPricesApplied ??
                      'Normal base prices will be applied'),
            value: _usePromotionPrice,
            onChanged: _setPromotionPriceSetting,
          ),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            icon: Icons.language_outlined,
            title: _l10n?.language ?? 'Language',
            subtitle: Localizations.localeOf(context).languageCode == 'lo'
                ? 'ລາວ'
                : (_l10n?.english ?? 'English'),
            onTap: _showLanguagePicker,
          ),
          if (_rejected.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              icon: Icons.error_outline_rounded,
              title: _l10n?.notSavedList('${_rejected.length}') ??
                  'Not saved by the server (${_rejected.length})',
              subtitle: _l10n?.notSavedListHelp ??
                  'Sales or tickets the server refused. Check them in Odoo and enter them again if needed.',
              subtitleColor: Colors.red,
              onTap: _showRejected,
            ),
          ],
          if (AppUpdateService.isSupported) ...[
            const SizedBox(height: 12),
            _buildMenuCard(
              context,
              icon: Icons.system_update_rounded,
              title: _l10n?.appUpdate ?? 'App update',
              subtitle: _l10n?.appUpdateCurrent('${_installedVersion ?? ''}') ??
                  'Version ${_installedVersion ?? ''}',
              onTap: () => AppUpdateFlow.checkManually(context),
            ),
          ],
        ],
      ),
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
              border: Border.all(color: LaDolcePosUi.navy.withValues(alpha: 0.14)),
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
                border: Border.all(color: LaDolcePosUi.navy.withValues(alpha: 0.14)),
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
