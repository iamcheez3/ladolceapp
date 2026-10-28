import 'dart:convert';
import 'package:ladolce/l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/ld.dart';
import '../utils/money.dart';

class BillTemplateSettingsScreen extends StatefulWidget {
  /// True when shown inside the tablet Settings screen (right-hand pane):
  /// no own app bar, Save sits in the section header.
  final bool embedded;

  const BillTemplateSettingsScreen({super.key, this.embedded = false});

  @override
  State<BillTemplateSettingsScreen> createState() =>
      _BillTemplateSettingsScreenState();
}

class _BillTemplateSettingsScreenState
    extends State<BillTemplateSettingsScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _billTemplates = const [];
  List<Map<String, dynamic>> _receiptTemplates = const [];
  List<Map<String, dynamic>> _refundTemplates = const [];
  List<Map<String, dynamic>> _kitchenTemplates = const [];

  int? _selectedBillId;
  int? _selectedReceiptId;
  int? _selectedRefundId;
  int? _selectedKitchenId;

  int? _toId(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  Map<String, dynamic>? _findTemplate(
      List<Map<String, dynamic>> list, int? id) {
    if (id == null) return null;
    try {
      return list.firstWhere((t) => _toId(t['id']) == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // All 8 cache reads run in parallel — instant if cached.
      final results = await Future.wait([
        _api.fetchBillTemplates(type: 'bill', forceRefresh: false),
        _api.fetchBillTemplates(type: 'receipt', forceRefresh: false),
        _api.fetchBillTemplates(type: 'refund', forceRefresh: false),
        _api.fetchBillTemplates(type: 'kitchen', forceRefresh: false),
        _api.fetchBillTemplate(type: 'bill', forceRefresh: false),
        _api.fetchBillTemplate(type: 'receipt', forceRefresh: false),
        _api.fetchBillTemplate(type: 'refund', forceRefresh: false),
        _api.fetchBillTemplate(type: 'kitchen', forceRefresh: false),
      ]);

      if (!mounted) return;
      setState(() {
        _billTemplates = results[0] as List<Map<String, dynamic>>;
        _receiptTemplates = results[1] as List<Map<String, dynamic>>;
        _refundTemplates = results[2] as List<Map<String, dynamic>>;
        _kitchenTemplates = results[3] as List<Map<String, dynamic>>;
        _selectedBillId = _toId((results[4] as Map<String, dynamic>)['id']);
        _selectedReceiptId = _toId((results[5] as Map<String, dynamic>)['id']);
        _selectedRefundId = _toId((results[6] as Map<String, dynamic>)['id']);
        _selectedKitchenId = _toId((results[7] as Map<String, dynamic>)['id']);
        _loading = false;
      });

      // Background network refresh — all 8 in parallel, silently.
      Future(() async {
        try {
          await Future.wait([
            _api.fetchBillTemplates(type: 'bill', forceRefresh: true),
            _api.fetchBillTemplates(type: 'receipt', forceRefresh: true),
            _api.fetchBillTemplates(type: 'refund', forceRefresh: true),
            _api.fetchBillTemplates(type: 'kitchen', forceRefresh: true),
            _api.fetchBillTemplate(type: 'bill', forceRefresh: true),
            _api.fetchBillTemplate(type: 'receipt', forceRefresh: true),
            _api.fetchBillTemplate(type: 'refund', forceRefresh: true),
            _api.fetchBillTemplate(type: 'kitchen', forceRefresh: true),
          ]);
        } catch (_) {}
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await _api.setBranchBillTemplates(
        billTemplateId: _selectedBillId,
        receiptTemplateId: _selectedReceiptId,
        refundTemplateId: _selectedRefundId,
        kitchenTemplateId: _selectedKitchenId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.savedTemplateSettings ?? (AppLocalizations.of(context)?.savedTemplateSettings ?? 'Saved template settings.'))),
      );
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Ld.danger),
      );
    }
  }

  Widget _dropdown({
    required String label,
    required List<Map<String, dynamic>> items,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Ld.ink)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: value,
          isExpanded: true,
          items: items
              .map(
                (t) => DropdownMenuItem<int>(
                  value: _toId(t['id']),
                  child: Text(
                    (t['name'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: _loading ? null : onChanged,
          decoration: const InputDecoration(),
        ),
      ],
    );
  }

  Widget _templateSection({
    required String label,
    required List<Map<String, dynamic>> items,
    required int? value,
    required ValueChanged<int?> onChanged,
    required String type,
  }) {
    return Container(
      decoration: Ld.card(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dropdown(label: label, items: items, value: value, onChanged: onChanged),
          const SizedBox(height: 14),
          _ReceiptPreview(
            template: _findTemplate(items, value),
            templateType: type,
          ),
        ],
      ),
    );
  }

  Widget _saveButton({required bool onNavy}) {
    final label = Text(AppLocalizations.of(context)?.save ?? 'Save');
    if (onNavy) {
      return FilledButton(
        onPressed: _loading ? null : _save,
        style: FilledButton.styleFrom(
          backgroundColor: Ld.gold,
          foregroundColor: Ld.navy,
          disabledBackgroundColor: Ld.navyRaised,
          disabledForegroundColor: Ld.onNavyMuted,
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: label,
      );
    }
    return FilledButton(onPressed: _loading ? null : _save, child: label);
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LdIconTile(Icons.error_outline_rounded, size: 56, background: Ld.dangerWash, color: Ld.danger),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Ld.danger, fontSize: 15)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final l10n = AppLocalizations.of(context);
    final sections = <Widget>[
      _templateSection(
        label: l10n?.billPreReceipt ?? 'Bill (pre-receipt)',
        items: _billTemplates,
        value: _selectedBillId,
        onChanged: (v) => setState(() => _selectedBillId = v),
        type: 'bill',
      ),
      _templateSection(
        label: l10n?.receiptPaid ?? 'Receipt (paid)',
        items: _receiptTemplates,
        value: _selectedReceiptId,
        onChanged: (v) => setState(() => _selectedReceiptId = v),
        type: 'receipt',
      ),
      _templateSection(
        label: l10n?.refundVoid ?? 'Refund / Void',
        items: _refundTemplates,
        value: _selectedRefundId,
        onChanged: (v) => setState(() => _selectedRefundId = v),
        type: 'refund',
      ),
      _templateSection(
        label: l10n?.kitchenOrderTicket2 ?? 'Kitchen / Order ticket',
        items: _kitchenTemplates,
        value: _selectedKitchenId,
        onChanged: (v) => setState(() => _selectedKitchenId = v),
        type: 'kitchen',
      ),
    ];

    final tip = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Ld.infoWash, borderRadius: BorderRadius.circular(Ld.r)),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: Ld.info),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tip: Duplicate a standard template in Odoo, change the name and text, then select it here.',
              style: TextStyle(color: Ld.info, fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );

    final hPad = widget.embedded ? 28.0 : 16.0;
    return LayoutBuilder(
      builder: (context, c) {
        final twoCols = c.maxWidth >= 760;
        return ListView(
          padding: EdgeInsets.fromLTRB(hPad, widget.embedded ? 8 : 16, hPad, 24 + Ld.navInset(context)),
          children: [
            if (twoCols)
              for (var i = 0; i < sections.length; i += 2) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: sections[i]),
                    const SizedBox(width: 16),
                    Expanded(child: i + 1 < sections.length ? sections[i + 1] : const SizedBox()),
                  ],
                ),
                const SizedBox(height: 16),
              ]
            else
              for (final s in sections) ...[s, const SizedBox(height: 16)],
            tip,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = AppLocalizations.of(context)?.billTemplates ?? 'Bill Templates';
    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: Ld.title(24), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 12),
                _saveButton(onNavy: false),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      );
    }
    return Scaffold(
      backgroundColor: Ld.ground,
      appBar: LdHeader(
        title: title,
        actions: [_saveButton(onNavy: true)],
      ),
      body: _body(),
    );
  }
}

// ---------------------------------------------------------------------------
// Receipt Preview Canvas
// ---------------------------------------------------------------------------

class _ReceiptPreview extends StatelessWidget {
  final Map<String, dynamic>? template;
  final String templateType;

  const _ReceiptPreview({
    required this.template,
    required this.templateType,
  });

  static const _sampleItems = [
    {'name': 'Americano', 'qty': 1, 'price': 25000.0},
    {'name': 'Croissant', 'qty': 2, 'price': 35000.0},
    {'name': 'Iced Latte', 'qty': 1, 'price': 30000.0},
  ];

  // ── Template-driven style helpers ─────────────────────────────────────────
  double get _fontSize =>
      ((template?['font_size'] ?? 11.5) as num).toDouble();
  double get _headerFontSize =>
      ((template?['header_font_size'] ?? 13.0) as num).toDouble();
  double get _footerFontSize =>
      ((template?['footer_font_size'] ?? 10.5) as num).toDouble();
  double get _lineSpacing =>
      ((template?['line_spacing'] ?? 1.45) as num).toDouble();
  String get _fontFamily =>
      (template?['font_family'] ?? 'monospace').toString();
  int get _paddingH => ((template?['padding_left'] ?? 12) as num).toInt();
  bool get _showQueueNumber => template?['show_queue_number'] != false; // default true

  TextStyle get _mono => TextStyle(
        fontFamily: _fontFamily,
        fontSize: _fontSize,
        color: Colors.black87,
        height: _lineSpacing,
      );

  TextStyle get _monoBold => TextStyle(
        fontFamily: _fontFamily,
        fontSize: _fontSize,
        color: Colors.black87,
        fontWeight: FontWeight.w700,
        height: _lineSpacing,
      );

  TextStyle get _monoSmall => TextStyle(
        fontFamily: _fontFamily,
        fontSize: _footerFontSize,
        color: Colors.black54,
        height: _lineSpacing,
      );

  TextStyle get _monoHeader => TextStyle(
        fontFamily: _fontFamily,
        fontSize: _headerFontSize,
        color: Colors.black87,
        fontWeight: FontWeight.w700,
        height: _lineSpacing,
      );

  String _hr([String ch = '-']) => ch * 32;

  String _center(String text, {int width = 32}) {
    if (text.length >= width) return text;
    final pad = (width - text.length) ~/ 2;
    return ' ' * pad + text;
  }

  Widget _line(String text,
      {bool bold = false,
      bool center = false,
      bool small = false,
      bool header = false,
      Color? color}) {
    TextStyle style = small
        ? _monoSmall
        : header
            ? _monoHeader
            : (bold ? _monoBold : _mono);
    if (color != null) style = style.copyWith(color: color);
    return Text(
      center ? _center(text) : text,
      style: style,
    );
  }

  List<Widget> _buildHeader(String? rawLogo, String headerText) {
    final rows = <Widget>[];

    if (rawLogo != null && rawLogo.isNotEmpty) {
      try {
        final bytes = base64Decode(rawLogo
            .replaceAll(RegExp(r'data:image/[^;]+;base64,'), '')
            .trim());
        rows.add(
          Center(
            child: Image.memory(bytes, height: 60, fit: BoxFit.contain),
          ),
        );
        rows.add(const SizedBox(height: 4));
      } catch (_) {}
    }

    if (headerText.isNotEmpty) {
      for (final line in headerText.split('\n')) {
        final t = line.trimRight();
        if (t.isEmpty) {
          rows.add(const SizedBox(height: 3));
        } else {
          rows.add(_line(t, header: true, center: true));
        }
      }
    } else {
      rows.add(_line('LaDolce', header: true, center: true));
      rows.add(_line('Point of Sale', center: true));
    }
    return rows;
  }

  List<Widget> _buildKitchenBody() {
    return [
      _line(_center('Kitchen / Order Ticket'), bold: true),
      _line(_hr()),
      if (_showQueueNumber) ...[
        _line(_center('Queue:'), small: true, color: Colors.grey[700]),
        _line(_center('Q42'), bold: true, header: true),
        _line(_hr()),
      ],
      _line('Date: 2026-05-28 12:00:00'),
      _line('Cashier: Sample Staff'),
      _line(_hr()),
      _line('2x  Americano', bold: true),
      _line('1x  Croissant', bold: true),
      _line('     + Extra Shot'),
      _line('     NOTE: Less sweet', bold: true),
      _line('1x  Iced Latte', bold: true),
      _line(_hr()),
    ];
  }

  List<Widget> _buildItemsAndTotals(String type) {
    final rows = <Widget>[];
    if (_showQueueNumber) {
      rows.add(_line(_center('Queue:'), small: true, color: Colors.grey[700]));
      rows.add(_line(_center('Q42'), bold: true, header: true));
      rows.add(_line(_hr()));
    }
    rows.add(_line('Date: 2026-05-28 12:00:00'));
    rows.add(_line('Cashier: Sample Staff'));
    rows.add(_line(_hr()));

    if (type == 'refund') {
      rows.add(_line(_center('*** REFUND / VOID ***'),
          bold: true, color: Colors.red[700]));
      rows.add(_line(_hr()));
    }

    double subtotal = 0;
    for (final item in _sampleItems) {
      final name = item['name'] as String;
      final qty = item['qty'] as int;
      final price = item['price'] as double;
      final lineTotal = qty * price;
      subtotal += lineTotal;
      rows.add(Row(
        children: [
          Expanded(child: Text('${qty}x $name', style: _monoBold)),
          Text('LAK ${money(lineTotal)}', style: _mono),
        ],
      ));
    }

    rows.add(_line(_hr()));
    if (type == 'receipt' || type == 'refund') {
      rows.add(Row(children: [
        Expanded(child: Text('Subtotal:', style: _mono)),
        Text('LAK ${money(subtotal)}', style: _mono),
      ]));
      final tax = subtotal * 0.07;
      rows.add(Row(children: [
        Expanded(child: Text('VAT (7%):', style: _mono)),
        Text('LAK ${money(tax)}', style: _mono),
      ]));
      rows.add(_line(_hr('=')));
      final total = subtotal + tax;
      rows.add(Row(children: [
        Expanded(child: Text('TOTAL:', style: _monoBold.copyWith(fontSize: _fontSize + 1.5))),
        Text('LAK ${money(total)}',
            style: _monoBold.copyWith(fontSize: _fontSize + 1.5)),
      ]));
    } else {
      rows.add(Row(children: [
        Expanded(child: Text('TOTAL:', style: _monoBold.copyWith(fontSize: _fontSize + 1.5))),
        Text('LAK ${money(subtotal)}',
            style: _monoBold.copyWith(fontSize: _fontSize + 1.5)),
      ]));
    }

    rows.add(const SizedBox(height: 6));
    if (type == 'bill') {
      rows.add(_line(_center('** NOT A RECEIPT **'), bold: true));
      rows.add(_line(_center('Please wait for your receipt'), small: true));
    } else if (type == 'receipt') {
      rows.add(_line(_center('Thank you!'), bold: true));
      rows.add(_line(_center('Please come again'), small: true));
    } else if (type == 'refund') {
      rows.add(_line(_center('Refund Processed'), bold: true));
      rows.add(_line(_center('Sorry for the inconvenience'), small: true));
    }

    return rows;
  }

  List<Widget> _buildFooter(String? footerLogoRaw, String footerText) {
    final rows = <Widget>[];
    if (footerText.isNotEmpty) {
      rows.add(const SizedBox(height: 4));
      for (final line in footerText.split('\n')) {
        final t = line.trimRight();
        if (t.isEmpty) {
          rows.add(const SizedBox(height: 3));
        } else {
          rows.add(_line(t, center: true, small: true));
        }
      }
    }
    if (footerLogoRaw != null && footerLogoRaw.isNotEmpty) {
      try {
        final bytes = base64Decode(footerLogoRaw
            .replaceAll(RegExp(r'data:image/[^;]+;base64,'), '')
            .trim());
        rows.add(const SizedBox(height: 6));
        rows.add(
          Center(
            child: Image.memory(bytes, height: 48, fit: BoxFit.contain),
          ),
        );
      } catch (_) {}
    }
    rows.add(const SizedBox(height: 4));
    rows.add(_line(_center('- - - - - - - - - - - - - - - -'), small: true));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (template == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Ld.ground,
          borderRadius: BorderRadius.circular(Ld.r),
        ),
        child: Row(
          children: [
            const Icon(Icons.receipt_long_outlined, color: Ld.muted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(AppLocalizations.of(context)?.noTemplateSelectedPreviewUnavailable ?? 'No template selected — preview unavailable',
                style: Ld.small,
              ),
            ),
          ],
        ),
      );
    }

    final headerText = (template!['header_text'] ?? '').toString().trim();
    final footerText = (template!['footer_text'] ?? '').toString().trim();
    final logoRaw = template!['logo']?.toString();
    final footerLogoRaw = template!['footer_logo']?.toString();

    final contentRows = <Widget>[];
    contentRows.addAll(_buildHeader(logoRaw, headerText));
    contentRows.add(_line(_hr()));

    if (templateType == 'kitchen') {
      contentRows.addAll(_buildKitchenBody());
    } else {
      contentRows.addAll(_buildItemsAndTotals(templateType));
    }

    contentRows.addAll(_buildFooter(footerLogoRaw, footerText));

    // The paper sits on a porcelain well, with the torn ticket edge below.
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: Ld.ground,
        borderRadius: BorderRadius.circular(Ld.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_outlined, size: 16, color: Ld.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Preview — ${(template!['name'] ?? templateType).toString()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Ld.small,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: SizedBox(
              width: 240,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: Colors.white,
                    padding: EdgeInsets.only(
                      left: _paddingH.toDouble(),
                      right: _paddingH.toDouble(),
                      top: ((template!['padding_top'] ?? 10) as num).toDouble(),
                      bottom: ((template!['padding_bottom'] ?? 10) as num).toDouble(),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: contentRows,
                    ),
                  ),
                  const LdTicketEdge(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
