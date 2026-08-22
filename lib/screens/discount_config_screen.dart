import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../models/pos_discount_config.dart';
import '../theme/ladolce_pos_ui.dart';
import '../theme/luxury_background.dart';

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
        SnackBar(content: Text(AppLocalizations.of(context)?.discountSettingsSaved ?? (AppLocalizations.of(context)?.discountSettingsSaved ?? 'Discount settings saved')), backgroundColor: Colors.green),
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
          title: Text(AppLocalizations.of(context)?.addDiscountOption ?? (AppLocalizations.of(context)?.addDiscountOption ?? 'Add Discount Option')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: LaDolcePosUi.input(
                    hintText: AppLocalizations.of(context)?.optionName ?? (AppLocalizations.of(context)?.optionName ?? 'Option Name'),
                    prefixIcon: const Icon(Icons.label_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)?.discountType ?? (AppLocalizations.of(context)?.discountType ?? 'Discount Type'), style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'percentage', label: Text(AppLocalizations.of(context)?.percentage ?? (AppLocalizations.of(context)?.percentage ?? 'Percentage'))),
                    ButtonSegment(value: 'value', label: Text(AppLocalizations.of(context)?.fixedValue ?? (AppLocalizations.of(context)?.fixedValue ?? 'Fixed Value'))),
                  ],
                  selected: {optType},
                  onSelectionChanged: (sel) => setDialogState(() => optType = sel.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: valueCtrl,
                  decoration: InputDecoration(
                    labelText: optType == 'percentage' ? (AppLocalizations.of(context)?.percentage2 ?? 'Percentage (%)') : 'Amount (₭)',
                    hintText: AppLocalizations.of(context)?.leaveEmptyForManualInput ?? (AppLocalizations.of(context)?.leaveEmptyForManualInput ?? 'Leave empty for manual input'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(LaDolcePosUi.radiusSm)),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)?.cancel ?? (AppLocalizations.of(context)?.cancel ?? 'Cancel'))),
            ElevatedButton(
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
              child: Text(AppLocalizations.of(context)?.add ?? (AppLocalizations.of(context)?.add ?? 'Add')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.discountConfiguration ?? (AppLocalizations.of(context)?.discountConfiguration ?? 'Discount Configuration')),
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(AppLocalizations.of(context)?.save ?? (AppLocalizations.of(context)?.save ?? 'Save'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],
      ),
      body: LuxuryPatternBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: LaDolcePosUi.card,
                borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
                border: Border.all(color: LaDolcePosUi.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: LaDolcePosUi.navy.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: LaDolcePosUi.navy.withValues(alpha: 0.14)),
                        ),
                        child: const Icon(Icons.discount_outlined, color: LaDolcePosUi.navy, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context)?.enableDiscount ?? (AppLocalizations.of(context)?.enableDiscount ?? 'Enable Discount'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            Text(
                              _enabled
                                  ? (AppLocalizations.of(context)?.discountWillAppearInPos ?? 'Discount will appear in POS')
                                  : (AppLocalizations.of(context)?.discountHidden ?? 'Discount hidden'),
                              style: TextStyle(fontSize: 12, color: _enabled ? Colors.green : LaDolcePosUi.mutedText),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _enabled,
                        activeColor: LaDolcePosUi.navy,
                        onChanged: (v) => setState(() => _enabled = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_enabled) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.list_alt_outlined, size: 18, color: LaDolcePosUi.mutedText),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)?.discountOptions ?? (AppLocalizations.of(context)?.discountOptions ?? 'Discount Options'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _showAddOptionDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(AppLocalizations.of(context)?.add ?? (AppLocalizations.of(context)?.add ?? 'Add'), style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(foregroundColor: LaDolcePosUi.navy),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_options.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: LaDolcePosUi.card,
                    borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
                    border: Border.all(color: LaDolcePosUi.border.withValues(alpha: 0.6)),
                  ),
                  child: Text(AppLocalizations.of(context)?.noDiscountOptionsAddedYet ?? (AppLocalizations.of(context)?.noDiscountOptionsAddedYet ?? 'No discount options added yet.'),
                      style: TextStyle(color: LaDolcePosUi.mutedText, fontSize: 13)),
                )
              else
                ..._options.asMap().entries.map((entry) {
                  final i = entry.key;
                  final opt = entry.value;
                  String valueText = '';
                  if (opt.value == null || (opt.value is num && (opt.value as num) == 0 && opt.type == 'percentage')) {
                    valueText = opt.type == 'percentage' ? 'Custom %' : 'Custom ₭';
                  } else {
                    valueText = opt.type == 'percentage'
                        ? '${(opt.value as num).toStringAsFixed(0)}%'
                        : '₭${(opt.value as num).toStringAsFixed(0)}';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: LaDolcePosUi.card,
                        borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
                        border: Border.all(color: LaDolcePosUi.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: LaDolcePosUi.navy.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.local_offer_outlined, color: LaDolcePosUi.navy, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(opt.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(valueText, style: TextStyle(fontSize: 12, color: LaDolcePosUi.mutedText)),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 36, height: 36,
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                              color: Colors.red.withValues(alpha: 0.7),
                              onPressed: () => setState(() => _options.removeAt(i)),
                              padding: EdgeInsets.zero,
                              tooltip: AppLocalizations.of(context)?.remove ?? (AppLocalizations.of(context)?.remove ?? 'Remove'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LaDolcePosUi.surface,
                  borderRadius: BorderRadius.circular(LaDolcePosUi.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: LaDolcePosUi.mutedText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(AppLocalizations.of(context)?.tipLeaveTheValueBlankTo ?? (AppLocalizations.of(context)?.tipLeaveTheValueBlankTo ?? 'Tip: Leave the value blank to let cashiers enter a custom amount.'),
                        style: TextStyle(fontSize: 12, color: LaDolcePosUi.mutedText),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
