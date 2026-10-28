import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'printer_settings_screen.dart';
import 'bill_template_settings_screen.dart';
import 'discount_config_screen.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../theme/ld.dart';
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

/// Settings sections. Phones list them and open each one as today; tablets
/// show the list on the left and the chosen section on the right.
enum _Sec { printers, bills, discount, promo, language, rejected, update }

class _Item {
  final _Sec sec;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final String? badge;
  final VoidCallback onOpen;
  final bool? toggle;
  final ValueChanged<bool>? onToggle;

  const _Item({
    required this.sec,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onOpen,
    this.subtitleColor,
    this.badge,
    this.toggle,
    this.onToggle,
  });
}

class _PosSettingsScreenState extends State<PosSettingsScreen> {
  final ApiService _apiService = ApiService();

  AppLocalizations? get _l10n => AppLocalizations.of(context);
  PosDiscountConfig _discountConfig = PosDiscountConfig.disabled;
  bool _usePromotionPrice = true;
  InstalledVersion? _installedVersion;
  List<Map<String, dynamic>> _rejected = const [];

  /// Section shown on the right on tablets.
  _Sec _section = _Sec.printers;

  /// Lets staff flip the app between English and Lao. PosApp.setLocale
  /// persists the choice, so it survives a restart and applies app-wide.
  Future<void> _showLanguagePicker() async {
    final current = Localizations.localeOf(context).languageCode;
    await showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(_l10n?.chooseAppLanguage ?? 'Choose the app language'),
        children: [
          for (final option in _languages)
            ListTile(
              minTileHeight: 52,
              title: Text(option[1]),
              trailing: current == option[0]
                  ? const Icon(Icons.check_rounded, color: Ld.navy)
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

  static const _languages = [
    ['en', 'English'],
    ['lo', 'ລາວ'],
  ];

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

  String _rejectedWhen(Map<String, dynamic> r) =>
      (r['at'] ?? '').toString().replaceFirst('T', ' ').split('.').first;

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
              for (final r in _rejected.reversed) _rejectedRow(r),
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
      await _clearRejected();
    }
  }

  Future<void> _clearRejected() async {
    await _apiService.clearRejectedOrders();
    if (mounted) setState(() => _rejected = const []);
  }

  Widget _rejectedRow(Map<String, dynamic> r) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Ld.lineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(_rejectedWhen(r), style: Ld.small),
              Text('₭${money(r['total'] as num?)}', style: Ld.price(15, color: Ld.ink)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            (r['reason'] ?? '').toString(),
            style: const TextStyle(fontSize: 14, color: Ld.danger, height: 1.35),
          ),
        ],
      ),
    );
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

  Future<void> _openPrinters() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PrinterSettingsScreen(),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openBillTemplates() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BillTemplateSettingsScreen(),
      ),
    );
  }

  Future<void> _openDiscount() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DiscountConfigScreen(
          initialConfig: _discountConfig,
        ),
      ),
    );
    if (changed == true) _loadDiscountConfig();
  }

  List<_Item> _items() {
    final l = _l10n;
    final isLao = Localizations.localeOf(context).languageCode == 'lo';
    return [
      _Item(
        sec: _Sec.printers,
        icon: Icons.print_outlined,
        title: l?.printerConfiguration ?? 'Printer Configuration',
        subtitle: printerService.profiles.isNotEmpty
            ? (l?.printersConfigured('${printerService.profiles.length}') ??
                '${printerService.profiles.length} printer(s) configured')
            : (printerService.isConfigured
                ? (l?.connectedTo('${printerService.printerIp}') ??
                    'Connected: ${printerService.printerIp}')
                : (l?.notConfigured ?? 'Not configured')),
        subtitleColor: printerService.isConfigured ? Ld.success : null,
        onOpen: _openPrinters,
      ),
      _Item(
        sec: _Sec.bills,
        icon: Icons.receipt_long_outlined,
        title: l?.billTemplates ?? 'Bill Templates',
        subtitle: l?.billTemplatesSubtitle ??
            'Select bill/receipt/refund templates for this branch',
        onOpen: _openBillTemplates,
      ),
      _Item(
        sec: _Sec.discount,
        icon: Icons.discount_outlined,
        title: l?.discountConfiguration ?? 'Discount Configuration',
        subtitle: _discountConfig.enabled
            ? (l?.discountOptionsConfigured('${_discountConfig.options.length}') ??
                '${_discountConfig.options.length} discount option(s) configured')
            : (l?.notConfigured ?? 'Not configured'),
        subtitleColor: _discountConfig.enabled ? Ld.success : null,
        onOpen: _openDiscount,
      ),
      _Item(
        sec: _Sec.promo,
        icon: Icons.campaign_outlined,
        title: l?.usePromotionPrice ?? 'Use Promotion Price in POS',
        subtitle: _usePromotionPrice
            ? (l?.promotionalPricesApplied ?? 'Promotional prices will be applied')
            : (l?.normalPricesApplied ?? 'Normal base prices will be applied'),
        toggle: _usePromotionPrice,
        onToggle: _setPromotionPriceSetting,
        onOpen: () => _setPromotionPriceSetting(!_usePromotionPrice),
      ),
      _Item(
        sec: _Sec.language,
        icon: Icons.language_outlined,
        title: l?.language ?? 'Language',
        subtitle: isLao ? 'ລາວ' : (l?.english ?? 'English'),
        onOpen: _showLanguagePicker,
      ),
      if (_rejected.isNotEmpty)
        _Item(
          sec: _Sec.rejected,
          icon: Icons.error_outline_rounded,
          title: l?.notSavedList('${_rejected.length}') ??
              'Not saved by the server (${_rejected.length})',
          subtitle: l?.notSavedListHelp ??
              'Sales or tickets the server refused. Check them in Odoo and enter them again if needed.',
          subtitleColor: Ld.danger,
          badge: '${_rejected.length}',
          onOpen: _showRejected,
        ),
      if (AppUpdateService.isSupported)
        _Item(
          sec: _Sec.update,
          icon: Icons.system_update_outlined,
          title: l?.appUpdate ?? 'App update',
          subtitle: l?.appUpdateCurrent('${_installedVersion ?? ''}') ??
              'Version ${_installedVersion ?? ''}',
          onOpen: () => AppUpdateFlow.checkManually(context),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    // Split view needs room for both panes; a 600 px portrait tablet keeps
    // the phone list.
    final tablet = Ld.isTablet(context) && MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
      backgroundColor: Ld.ground,
      appBar: LdHeader(title: _l10n?.appSettings ?? 'App Settings'),
      body: tablet ? _buildTablet(items) : _buildPhone(items),
    );
  }

  // ── Phone: one list, each section opens as today ──────────────────────
  Widget _buildPhone(List<_Item> items) {
    return ListView(
      // Last tile (App update) stays above the navigation bar.
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + Ld.navInset(context)),
      children: [
        Container(
          decoration: Ld.card(),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 72),
                _phoneRow(items[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _phoneRow(_Item it) {
    final danger = it.sec == _Sec.rejected;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: it.onOpen,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                LdIconTile(
                  it.icon,
                  background: danger ? Ld.dangerWash : Ld.ground,
                  color: danger ? Ld.danger : Ld.navy,
                ),
                const SizedBox(width: 14),
                Expanded(child: _texts(it, selected: false)),
                const SizedBox(width: 8),
                if (it.toggle != null)
                  Switch(value: it.toggle!, onChanged: it.onToggle)
                else
                  const Icon(Icons.chevron_right_rounded, color: Ld.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _texts(_Item it, {required bool selected}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          it.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Ld.navy : Ld.ink,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          it.subtitle,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: it.subtitleColor ?? Ld.muted, height: 1.35),
        ),
      ],
    );
  }

  // ── Tablet: sections on the left, content on the right ────────────────
  Widget _buildTablet(List<_Item> items) {
    final available = items.map((e) => e.sec).toSet();
    final sec = available.contains(_section) ? _section : _Sec.printers;
    final current = items.firstWhere((e) => e.sec == sec);
    final navWidth = MediaQuery.sizeOf(context).width >= 1000 ? 320.0 : 280.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: navWidth,
          decoration: const BoxDecoration(
            color: Ld.surface,
            border: Border(right: BorderSide(color: Ld.line)),
          ),
          child: ListView(
            padding: EdgeInsets.fromLTRB(12, 14, 12, 14 + Ld.navInset(context)),
            children: [
              for (final it in items) _navItem(it, it.sec == sec),
            ],
          ),
        ),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(sec),
            child: _pane(current),
          ),
        ),
      ],
    );
  }

  Widget _navItem(_Item it, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? Ld.ground : Colors.transparent,
        borderRadius: BorderRadius.circular(Ld.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(Ld.r),
          onTap: () => setState(() => _section = it.sec),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(it.icon, size: 22, color: selected ? Ld.navy : Ld.muted),
                  const SizedBox(width: 12),
                  Expanded(child: _texts(it, selected: selected)),
                  if (it.badge != null) ...[
                    const SizedBox(width: 8),
                    LdBadge(it.badge!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pane(_Item it) {
    switch (it.sec) {
      case _Sec.printers:
        return PrinterSettingsScreen(
          embedded: true,
          onChanged: () {
            if (mounted) setState(() {});
          },
        );
      case _Sec.bills:
        return const BillTemplateSettingsScreen(embedded: true);
      case _Sec.discount:
        return _paneList(it.title, [
          _openCard(
            icon: it.icon,
            title: it.title,
            subtitle: it.subtitle,
            subtitleColor: it.subtitleColor,
            onTap: _openDiscount,
          ),
          if (_discountConfig.enabled && _discountConfig.options.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in _discountConfig.options)
                  LdPill(
                    o.value == null
                        ? o.name
                        : '${o.name} · ${o.type == 'percentage' ? '${o.value!.toStringAsFixed(0)}%' : '₭${money(o.value)}'}',
                    icon: Icons.local_offer_outlined,
                  ),
              ],
            ),
          ],
        ]);
      case _Sec.promo:
        return _paneList(it.title, [
          Container(
            decoration: Ld.card(),
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                LdIconTile(it.icon),
                const SizedBox(width: 14),
                Expanded(child: _texts(it, selected: false)),
                const SizedBox(width: 8),
                Switch(value: _usePromotionPrice, onChanged: _setPromotionPriceSetting),
              ],
            ),
          ),
        ]);
      case _Sec.language:
        final current = Localizations.localeOf(context).languageCode;
        return _paneList(_l10n?.chooseAppLanguage ?? 'Choose the app language', [
          Container(
            decoration: Ld.card(),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < _languages.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  Material(
                    color: current == _languages[i][0] ? Ld.ground : Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        PosApp.setLocale(context, Locale(_languages[i][0], ''));
                        setState(() {});
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _languages[i][1],
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: current == _languages[i][0]
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: current == _languages[i][0] ? Ld.navy : Ld.ink,
                                  ),
                                ),
                              ),
                              if (current == _languages[i][0])
                                const Icon(Icons.check_rounded, color: Ld.navy),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ]);
      case _Sec.rejected:
        return _paneList(
          _l10n?.notSavedTitle ?? 'Not saved by the server',
          [
            Text(it.subtitle, style: Ld.label),
            const SizedBox(height: 12),
            Container(
              decoration: Ld.card(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final r in _rejected.reversed) _rejectedRow(r),
                ],
              ),
            ),
          ],
          // Same confirmation as on phones: the list dialog's Clear button.
          action: OutlinedButton.icon(
            onPressed: _showRejected,
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(_l10n?.clear ?? 'Clear'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Ld.danger,
              side: const BorderSide(color: Ld.dangerLine),
            ),
          ),
        );
      case _Sec.update:
        return _paneList(it.title, [
          _openCard(
            icon: it.icon,
            title: it.title,
            subtitle: it.subtitle,
            onTap: () => AppUpdateFlow.checkManually(context),
          ),
        ]);
    }
  }

  Widget _paneList(String title, List<Widget> children, {Widget? action}) {
    return ListView(
      padding: EdgeInsets.fromLTRB(28, 24, 28, 24 + Ld.navInset(context)),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Ld.title(24), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            if (action != null) ...[const SizedBox(width: 12), action],
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _openCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? subtitleColor,
  }) {
    return Material(
      color: Ld.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ld.rLg),
        side: const BorderSide(color: Ld.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Ld.rLg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              LdIconTile(icon, size: 52),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Ld.ink)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(fontSize: 14, color: subtitleColor ?? Ld.muted, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Ld.muted),
            ],
          ),
        ),
      ),
    );
  }
}
