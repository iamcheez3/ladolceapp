import 'package:flutter/material.dart';
import 'printer_settings_screen.dart';
import 'bill_template_settings_screen.dart';
import '../services/api_service.dart';
import '../services/printer_service.dart';
import '../theme/ladolce_pos_ui.dart';
import '../models/pos_discount_config.dart';

class PosSettingsScreen extends StatefulWidget {
  final Future<void> Function() onSyncRequested;

  const PosSettingsScreen({
    super.key,
    required this.onSyncRequested,
  });

  @override
  State<PosSettingsScreen> createState() => _PosSettingsScreenState();
}

class _PosSettingsScreenState extends State<PosSettingsScreen> {
  final ApiService _apiService = ApiService();
  PosDiscountConfig _discountConfig = PosDiscountConfig.disabled;

  @override
  void initState() {
    super.initState();
    _loadDiscountConfig();
  }

  Future<void> _loadDiscountConfig() async {
    final cfg = await PosDiscountConfig.load();
    if (mounted) setState(() => _discountConfig = cfg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuCard(
            context,
            icon: Icons.print,
            title: 'Printer Configuration',
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
            title: 'Bill Templates',
            subtitle: 'Select bill/receipt/refund templates for this branch',
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
          _buildDiscountCard(context),
          const SizedBox(height: 12),
          _buildMenuCard(
            context,
            icon: Icons.sync,
            title: 'Sync All Data',
            subtitle: 'Manually refresh all local data from Odoo server',
            onTap: () async {
              await widget.onSyncRequested();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountCard(BuildContext context) {
    final discountEnabled = _discountConfig.enabled;
    final subtitle = discountEnabled
        ? '${_discountConfig.options.length} discount option(s) configured'
        : 'Not configured';
    return _buildMenuCard(
      context,
      icon: Icons.discount_outlined,
      title: 'Discount Configuration',
      subtitle: discountEnabled ? 'Enabled: $subtitle' : subtitle,
      subtitleColor: discountEnabled ? Colors.green : null,
      onTap: () => _showDiscountConfigDialog(context),
    );
  }

  Future<void> _showAddOptionDialog(
      BuildContext context, Function(PosDiscountOption) onAdded) async {
    String optType = 'percentage';
    double? optValue;

    final nameCtrl = TextEditingController();
    final valueCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Discount Option'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Option Name',
                    hintText: 'e.g. Discount 15%',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Discount Type',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'percentage', label: Text('Percentage')),
                    ButtonSegment(value: 'value', label: Text('Fixed Value')),
                  ],
                  selected: {optType},
                  onSelectionChanged: (sel) =>
                      setDialogState(() => optType = sel.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: valueCtrl,
                  decoration: InputDecoration(
                    labelText: optType == 'percentage'
                        ? 'Percentage (%)'
                        : 'Amount (₭)',
                    hintText: 'Leave empty for manual input',
                    border: const OutlineInputBorder(),
                    suffixText: optType == 'percentage' ? '%' : null,
                    prefixText: optType == 'value' ? '₭ ' : null,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    optValue = double.tryParse(v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                final newOpt = PosDiscountOption(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  type: optType,
                  value: optValue,
                  name: nameCtrl.text.trim(),
                );
                onAdded(newOpt);
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDiscountConfigDialog(BuildContext context) async {
    bool enabled = _discountConfig.enabled;
    List<PosDiscountOption> options = List.from(_discountConfig.options);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Discount Configuration'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Enable Discount'),
                    subtitle: Text(
                      enabled
                          ? 'Discount will appear in POS'
                          : 'Discount hidden',
                      style: TextStyle(
                        color: enabled ? Colors.green : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    value: enabled,
                    activeColor: LaDolcePosUi.navy,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setDialogState(() => enabled = v),
                  ),
                  const SizedBox(height: 12),
                  if (enabled) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Discount Options',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            _showAddOptionDialog(ctx, (newOpt) {
                              setDialogState(() {
                                options.add(newOpt);
                              });
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (options.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No discount options added yet.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final opt = options[index];
                          String valueText = '';
                          if (opt.value == null) {
                            valueText = opt.type == 'percentage'
                                ? 'Custom %'
                                : 'Custom ₭';
                          } else {
                            valueText = opt.type == 'percentage'
                                ? '${opt.value!.toStringAsFixed(0)}%'
                                : '₭${opt.value!.toStringAsFixed(0)}';
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(opt.name),
                              subtitle: Text(
                                  'Type: ${opt.type} | Value: $valueText'),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setDialogState(() {
                                    options.removeAt(index);
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: LaDolcePosUi.navy,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final newCfg = PosDiscountConfig(
                  enabled: enabled,
                  options: options,
                );
                await newCfg.save();
                if (!ctx.mounted) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _loadDiscountConfig();
    }
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
              color: Colors.black.withOpacity(0.04),
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
                color: LaDolcePosUi.navy.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LaDolcePosUi.navy.withOpacity(0.14)),
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
