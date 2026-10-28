import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../models/pos_discount_config.dart';
import '../theme/ld.dart';
import '../utils/money.dart';

class DiscountConfigScreen extends StatefulWidget {
  final PosDiscountConfig initialConfig;

  const DiscountConfigScreen({super.key, required this.initialConfig});

  @override
  State<DiscountConfigScreen> createState() => _DiscountConfigScreenState();
}

class _DiscountConfigScreenState extends State<DiscountConfigScreen> {
  late bool _enabled;
  late List<PosDiscountOption> _options;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialConfig.enabled;
    _options = List.from(widget.initialConfig.options);
  }

  Future<void> _save() async {
    final cfg = PosDiscountConfig(enabled: _enabled, options: _options);
    await cfg.save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.discountSettingsSaved ?? 'Discount settings saved'), backgroundColor: Ld.success),
      );
      Navigator.pop(context, true);
    }
  }

  void _showAddOptionDialog() {
    String optType = 'percentage';
    double? optValue;
    final nameCtrl = TextEditingController();
    final valueCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context)?.addDiscountOption ?? 'Add Discount Option'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)?.optionName ?? 'Option Name',
                    prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)?.discountType ?? 'Discount Type',
                  style: Ld.label,
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'percentage', label: Text(AppLocalizations.of(context)?.percentage ?? 'Percentage')),
                    ButtonSegment(value: 'value', label: Text(AppLocalizations.of(context)?.fixedValue ?? 'Fixed Value')),
                  ],
                  selected: {optType},
                  onSelectionChanged: (sel) => setDialogState(() => optType = sel.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: valueCtrl,
                  decoration: InputDecoration(
                    labelText: optType == 'percentage' ? (AppLocalizations.of(context)?.percentage2 ?? 'Percentage (%)') : 'Amount (₭)',
                    hintText: AppLocalizations.of(context)?.leaveEmptyForManualInput ?? 'Leave empty for manual input',
                    suffixText: optType == 'percentage' ? '%' : null,
                    prefixText: optType == 'value' ? '₭ ' : null,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => optValue = double.tryParse(v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                final newOpt = PosDiscountOption(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  type: optType,
                  value: optValue ?? (optType == 'percentage' ? 0.0 : 0),
                  name: nameCtrl.text.trim(),
                );
                setState(() => _options.add(newOpt));
                Navigator.pop(ctx);
              },
              child: Text(AppLocalizations.of(context)?.add ?? 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Ld.ground,
      appBar: LdHeader(
        title: l10n?.discountConfiguration ?? 'Discount Configuration',
        actions: [
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: Ld.gold,
              foregroundColor: Ld.navy,
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: Text(l10n?.save ?? 'Save'),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + Ld.navInset(context)),
            children: [
              Material(
                color: Ld.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Ld.rLg),
                  side: const BorderSide(color: Ld.line),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Ld.rLg),
                  onTap: () => setState(() => _enabled = !_enabled),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                    child: Row(
                      children: [
                        const LdIconTile(Icons.discount_outlined),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n?.enableDiscount ?? 'Enable Discount',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Ld.ink),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _enabled
                                    ? (l10n?.discountWillAppearInPos ?? 'Discount will appear in POS')
                                    : (l10n?.discountHidden ?? 'Discount hidden'),
                                style: TextStyle(fontSize: 13, color: _enabled ? Ld.success : Ld.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _enabled,
                          onChanged: (v) => setState(() => _enabled = v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_enabled) ...[
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n?.discountOptions ?? 'Discount Options',
                        style: Ld.title(19),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _showAddOptionDialog,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: Text(l10n?.add ?? 'Add'),
                      style: OutlinedButton.styleFrom(backgroundColor: Ld.surface),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_options.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                    alignment: Alignment.center,
                    decoration: Ld.card(),
                    child: Text(
                      l10n?.noDiscountOptionsAddedYet ?? 'No discount options added yet.',
                      textAlign: TextAlign.center,
                      style: Ld.label,
                    ),
                  )
                else
                  Container(
                    decoration: Ld.card(),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final entry in _options.asMap().entries) ...[
                          if (entry.key > 0) const Divider(height: 1, indent: 72),
                          _optionRow(entry.key, entry.value),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Ld.infoWash,
                    borderRadius: BorderRadius.circular(Ld.r),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: Ld.info),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n?.tipLeaveTheValueBlankTo ?? 'Tip: Leave the value blank to let cashiers enter a custom amount.',
                          style: const TextStyle(fontSize: 14, color: Ld.info, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionRow(int i, PosDiscountOption opt) {
    String valueText = '';
    if (opt.value == null || (opt.value is num && (opt.value as num) == 0 && opt.type == 'percentage')) {
      valueText = opt.type == 'percentage' ? 'Custom %' : 'Custom ₭';
    } else {
      valueText = opt.type == 'percentage'
          ? '${(opt.value as num).toStringAsFixed(0)}%'
          : '₭${money((opt.value as num))}';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          const LdIconTile(Icons.local_offer_outlined),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opt.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Ld.ink),
                ),
                const SizedBox(height: 2),
                Text(valueText, style: Ld.price(15)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 22),
            color: Ld.danger,
            onPressed: () => setState(() => _options.removeAt(i)),
            tooltip: AppLocalizations.of(context)?.remove ?? 'Remove',
          ),
        ],
      ),
    );
  }
}
