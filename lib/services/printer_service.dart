import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart' show Color, FontWeight, TextAlign;
import 'package:flutter/services.dart' show rootBundle;
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';
import '../models/topping.dart';
import '../utils/localized_name.dart';

void _printerLog(String message) {
  developer.log(message, name: 'PrinterService');
  // Mirror to stdout so it shows in `flutter run` console output too.
  // ignore: avoid_print
  print('[PrinterService] $message');
}

/// Fixed English copy for every printed document.
///
/// Only menu and topping names follow the app language on paper (see
/// [Product.displayName], [Topping.displayName] and [localizedLineName]) — the
/// labels around them stay English by decision, so a bill or kitchen ticket
/// reads the same to every staff member no matter which language the cashier
/// happens to have the app set to.
class ReceiptPrintLabels {
  final String date;
  final String cashier;
  final String customer;
  final String order;
  final String table;
  final String reprint;
  final String refund;
  final String discount;
  final String total;
  final String change;
  final String free;
  final String thankYou;
  final String orderTicket;
  final String note;

  const ReceiptPrintLabels({
    required this.date,
    required this.cashier,
    required this.customer,
    required this.order,
    required this.table,
    required this.reprint,
    required this.refund,
    required this.discount,
    required this.total,
    required this.change,
    required this.free,
    required this.thankYou,
    required this.orderTicket,
    required this.note,
  });

  static const ReceiptPrintLabels english = ReceiptPrintLabels(
    date: 'Date',
    cashier: 'Cashier',
    customer: 'Customer',
    order: 'Order',
    table: 'Table',
    reprint: 'REPRINT',
    refund: 'REFUND',
    discount: 'Discount',
    total: 'TOTAL',
    change: 'Change',
    free: 'FREE',
    thankYou: 'Thank you, see you again',
    orderTicket: 'Order Ticket',
    note: 'NOTE',
  );
}

/// One payment row on a receipt (a split payment has several).
class ReceiptPayment {
  final String method;
  final double amount;

  const ReceiptPayment(this.method, this.amount);
}

/// The customer block at the bottom of a receipt: name and the points this
/// order earned. The customer's point balance is not printed.
class ReceiptCustomer {
  final String name;
  final int? pointsEarned;

  /// What the shop calls its points (backend `points_label`, e.g. "Points").
  final String pointsLabel;

  const ReceiptCustomer({
    required this.name,
    this.pointsEarned,
    this.pointsLabel = 'Points',
  });

  bool get isEmpty => name.trim().isEmpty && pointsEarned == null;
}

enum PrintLineKind { text, row, rule, logo, feed, cut }

enum PrintSize { small, normal, medium, large, huge }

enum PrintAlign { left, center, right }

/// One line of a printed document, before it is drawn.
///
/// Documents are laid out as a list of these first ([PrintLayouts]) and only
/// then drawn ([PrintRenderer]), so their wording can be checked in tests
/// without a printer.
class PrintLine {
  final PrintLineKind kind;
  final String text;

  /// Right-hand column of a [PrintLineKind.row] (prices).
  final String right;
  final PrintSize size;
  final bool bold;
  final PrintAlign align;

  /// Left inset in dots (topping and note lines sit under their item).
  final int indent;

  /// Blank lines for [PrintLineKind.feed].
  final int lines;

  const PrintLine._(
    this.kind, {
    this.text = '',
    this.right = '',
    this.size = PrintSize.normal,
    this.bold = false,
    this.align = PrintAlign.left,
    this.indent = 0,
    this.lines = 0,
  });

  const PrintLine.text(
    String text, {
    PrintSize size = PrintSize.normal,
    bool bold = false,
    PrintAlign align = PrintAlign.left,
    int indent = 0,
  }) : this._(
         PrintLineKind.text,
         text: text,
         size: size,
         bold: bold,
         align: align,
         indent: indent,
       );

  const PrintLine.row(
    String left,
    String right, {
    PrintSize size = PrintSize.normal,
    bool bold = false,
  }) : this._(
         PrintLineKind.row,
         text: left,
         right: right,
         size: size,
         bold: bold,
       );

  const PrintLine.rule() : this._(PrintLineKind.rule);

  const PrintLine.logo() : this._(PrintLineKind.logo);

  const PrintLine.feed(int lines) : this._(PrintLineKind.feed, lines: lines);

  const PrintLine.cut() : this._(PrintLineKind.cut);

  @override
  String toString() => switch (kind) {
    PrintLineKind.row => '$text | $right',
    PrintLineKind.rule => '----',
    PrintLineKind.logo => '[logo]',
    PrintLineKind.feed => '',
    PrintLineKind.cut => '[cut]',
    PrintLineKind.text => text,
  };
}

/// Wording and order of every printed document.
class PrintLayouts {
  PrintLayouts._();

  static const ReceiptPrintLabels _labels = ReceiptPrintLabels.english;

  static const int _subIndent = 28;

  /// `LAK 35000.00` — with a space, as on the Android receipts.
  static String money(double value, {String currency = 'LAK'}) =>
      '$currency ${value.toStringAsFixed(2)}';

  static String queue(int? number) {
    if (number == null || number <= 0) return '';
    return '#${number.toString().padLeft(3, '0')}';
  }

  static String _stamp(DateTime at) => at.toString().substring(0, 19);

  static List<String> _templateLines(String? raw) => (raw ?? '')
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.trim().isNotEmpty)
      .toList();

  static List<PrintLine> _header(String? headerText) => [
    const PrintLine.logo(),
    for (final line in _templateLines(headerText))
      PrintLine.text(line, bold: true, align: PrintAlign.center),
  ];

  static List<PrintLine> _footer(String? footerText) {
    final lines = _templateLines(footerText);
    if (lines.isEmpty) lines.add(_labels.thankYou);
    return [
      const PrintLine.feed(1),
      for (final line in lines) PrintLine.text(line, align: PrintAlign.center),
    ];
  }

  static List<PrintLine> _queue(int? number) {
    final q = queue(number);
    if (q.isEmpty) return const [];
    return [
      PrintLine.text(
        q,
        size: PrintSize.huge,
        bold: true,
        align: PrintAlign.center,
      ),
      const PrintLine.rule(),
    ];
  }

  static String _itemName(CartItem item) {
    final name = '${item.quantity}x ${item.product.displayName}';
    return item.isFreePromo ? '$name (${_labels.free})' : name;
  }

  static List<PrintLine> _choices(
    CartItem item, {
    PrintSize size = PrintSize.small,
  }) => [
    for (final t in Topping.sorted(item.selectedToppings))
      PrintLine.text('+ ${t.displayName}', size: size, indent: _subIndent),
  ];

  static List<PrintLine> _totals({
    required double subtotal,
    required double tax,
    required double total,
    required String subtotalRowLabel,
    String? taxRowLabel,
    double discountAmount = 0.0,
    String currency = 'LAK',
  }) {
    final showTax =
        taxRowLabel != null && taxRowLabel.isNotEmpty && tax.abs() >= 0.005;
    return [
      if (discountAmount > 0)
        PrintLine.row(
          '${_labels.discount}:',
          '-${money(discountAmount, currency: currency)}',
        ),
      if (showTax) ...[
        PrintLine.row(subtotalRowLabel, money(subtotal, currency: currency)),
        PrintLine.row(taxRowLabel, money(tax, currency: currency)),
      ],
      PrintLine.row(
        '${_labels.total}:',
        money(total, currency: currency),
        size: PrintSize.large,
        bold: true,
      ),
    ];
  }

  static List<PrintLine> _payments(
    List<ReceiptPayment> payments,
    double changeAmount, {
    String currency = 'LAK',
  }) => [
    for (final p in payments)
      if (p.method.trim().isNotEmpty)
        PrintLine.row(p.method.trim(), money(p.amount, currency: currency)),
    if (changeAmount >= 0.005)
      PrintLine.row(_labels.change, money(changeAmount, currency: currency)),
  ];

  static List<PrintLine> _customer(ReceiptCustomer? customer) {
    if (customer == null || customer.isEmpty) return const [];
    final label = customer.pointsLabel.trim().isEmpty
        ? 'Points'
        : customer.pointsLabel.trim();
    return [
      const PrintLine.rule(),
      if (customer.name.trim().isNotEmpty)
        PrintLine.text('${_labels.customer}: ${customer.name.trim()}'),
      if (customer.pointsEarned != null)
        PrintLine.row('$label earned', '+${customer.pointsEarned}'),
    ];
  }

  /// Receipt printed after a charge.
  static List<PrintLine> receipt({
    required List<CartItem> items,
    required double subtotal,
    required double tax,
    required double total,
    required String cashierName,
    String subtotalRowLabel = 'Subtotal:',
    String? taxRowLabel,
    String? headerText,
    String? footerText,
    double discountAmount = 0.0,
    int? queueNumber,
    List<ReceiptPayment> payments = const [],
    double changeAmount = 0.0,
    ReceiptCustomer? customer,
    DateTime? at,
  }) {
    return [
      ..._header(headerText),
      const PrintLine.rule(),
      ..._queue(queueNumber),
      PrintLine.text('${_labels.date}: ${_stamp(at ?? DateTime.now())}'),
      PrintLine.text('${_labels.cashier}: $cashierName'),
      const PrintLine.rule(),
      for (final item in items) ...[
        PrintLine.row(_itemName(item), money(item.totalPrice)),
        ..._choices(item),
      ],
      const PrintLine.rule(),
      ..._totals(
        subtotal: subtotal,
        tax: tax,
        total: total,
        subtotalRowLabel: subtotalRowLabel,
        taxRowLabel: taxRowLabel,
        discountAmount: discountAmount,
      ),
      ..._payments(payments, changeAmount),
      ..._customer(customer),
      ..._footer(footerText),
      const PrintLine.feed(3),
      const PrintLine.cut(),
    ];
  }

  /// Bill printed before payment ("NOT A RECEIPT").
  static List<PrintLine> bill({
    required List<CartItem> items,
    required double subtotal,
    required double tax,
    required double total,
    required String cashierName,
    String? ticketName,
    String subtotalRowLabel = 'Subtotal:',
    String? taxRowLabel,
    String? headerText,
    String? footerText,
    double discountAmount = 0.0,
    int? queueNumber,
    DateTime? at,
  }) {
    final name = (ticketName ?? '').trim();
    return [
      ..._header(headerText),
      if (name.isNotEmpty)
        PrintLine.text(name, bold: true, align: PrintAlign.center),
      const PrintLine.rule(),
      ..._queue(queueNumber),
      PrintLine.text('${_labels.date}: ${_stamp(at ?? DateTime.now())}'),
      PrintLine.text('${_labels.cashier}: $cashierName'),
      const PrintLine.rule(),
      for (final item in items) ...[
        PrintLine.row(_itemName(item), money(item.totalPrice)),
        ..._choices(item),
      ],
      const PrintLine.rule(),
      ..._totals(
        subtotal: subtotal,
        tax: tax,
        total: total,
        subtotalRowLabel: subtotalRowLabel,
        taxRowLabel: taxRowLabel,
        discountAmount: discountAmount,
      ),
      const PrintLine.feed(1),
      const PrintLine.text(
        '** NOT A RECEIPT **',
        bold: true,
        align: PrintAlign.center,
      ),
      const PrintLine.text(
        'Please wait for your receipt',
        align: PrintAlign.center,
      ),
      for (final line in _templateLines(footerText))
        PrintLine.text(line, align: PrintAlign.center),
      const PrintLine.feed(3),
      const PrintLine.cut(),
    ];
  }

  static List<PrintLine> _ticketHeader(
    String cashierName,
    int? queueNumber,
    DateTime at,
  ) => [
    PrintLine.text(
      _labels.orderTicket,
      size: PrintSize.large,
      bold: true,
      align: PrintAlign.center,
    ),
    const PrintLine.rule(),
    ..._queue(queueNumber),
    PrintLine.text('${_labels.date}: ${_stamp(at)}'),
    PrintLine.text('${_labels.cashier}: $cashierName'),
    const PrintLine.rule(),
  ];

  static List<PrintLine> _ticketItem(
    String name,
    List<String> choices,
    String note,
  ) => [
    PrintLine.text(name, size: PrintSize.large, bold: true),
    for (final c in choices)
      // Kitchen choices are bigger than on the receipt (21), still under the
      // item name (32).
      PrintLine.text('+ $c', size: PrintSize.medium, indent: _subIndent),
    // As big as the item name, so the kitchen does not miss it.
    if (note.trim().isNotEmpty)
      PrintLine.text(
        '${_labels.note}: ${note.trim()}',
        size: PrintSize.large,
        bold: true,
        indent: _subIndent,
      ),
    const PrintLine.feed(1),
  ];

  /// Kitchen / bar ticket.
  static List<PrintLine> orderTicket({
    required List<CartItem> items,
    required String cashierName,
    String? footerText,
    int? queueNumber,
    bool singleItemPerTicket = false,
    bool groupIdenticalItems = true,
    DateTime? at,
  }) {
    final when = at ?? DateTime.now();
    final out = <PrintLine>[..._ticketHeader(cashierName, queueNumber, when)];

    List<String> choicesOf(CartItem i) =>
        Topping.sorted(i.selectedToppings).map((t) => t.displayName).toList();
    String nameOf(CartItem i, int qty) {
      final name = '${qty}x ${i.product.displayName}';
      return i.isFreePromo ? '$name (${_labels.free})' : name;
    }

    if (singleItemPerTicket) {
      for (final i in items) {
        for (int q = 0; q < i.quantity; q++) {
          out.addAll(_ticketItem(nameOf(i, 1), choicesOf(i), i.kitchenNote));
          out.addAll(const [PrintLine.feed(1), PrintLine.cut()]);
        }
      }
      return out;
    }

    final rows = <({CartItem item, int qty})>[];
    if (groupIdenticalItems) {
      final index = <String, int>{};
      for (final i in items) {
        final key = [
          i.product.id,
          Topping.sorted(i.selectedToppings).map((t) => t.id).join('|'),
          i.kitchenNote.trim(),
          i.isFreePromo,
        ].join('__');
        final existing = index[key];
        if (existing == null) {
          index[key] = rows.length;
          rows.add((item: i, qty: i.quantity));
        } else {
          rows[existing] = (
            item: rows[existing].item,
            qty: rows[existing].qty + i.quantity,
          );
        }
      }
    } else {
      rows.addAll(items.map((i) => (item: i, qty: i.quantity)));
    }

    for (final r in rows) {
      out.addAll(
        _ticketItem(
          nameOf(r.item, r.qty),
          choicesOf(r.item),
          r.item.kitchenNote,
        ),
      );
    }
    for (final line in _templateLines(footerText)) {
      out.add(PrintLine.text(line, align: PrintAlign.center));
    }
    out.addAll(const [PrintLine.feed(2), PrintLine.cut()]);
    return out;
  }

  static double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  static int? _asIntOrNull(dynamic v) {
    if (v == null || v == false) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  /// Payment rows from a receipt payload: `payments` (split payment) or the
  /// single `payment_method` with the order total.
  static List<ReceiptPayment> paymentsFromRaw(
    Map<String, dynamic> data, {
    double? total,
  }) {
    final raw = data['payments'];
    if (raw is List && raw.isNotEmpty) {
      return [
        for (final p in raw)
          if (p is Map)
            ReceiptPayment(
              (p['payment_method'] ?? '').toString(),
              _asDouble(p['amount']),
            ),
      ];
    }
    final method = (data['payment_method'] ?? '').toString().trim();
    if (method.isEmpty || method.toLowerCase() == 'unpaid') return const [];
    return [ReceiptPayment(method, total ?? _asDouble(data['amount_total']))];
  }

  /// Customer and points earned from a receipt payload (`customer`,
  /// `points_earned`, `points_label`). `customer_points` (the balance) is not
  /// printed.
  static ReceiptCustomer? customerFromRaw(Map<String, dynamic> data) {
    final name = (data['customer'] ?? '').toString().trim();
    final earned = _asIntOrNull(data['points_earned']);
    if (name.isEmpty && earned == null) return null;
    return ReceiptCustomer(
      name: name,
      pointsEarned: earned,
      pointsLabel: (data['points_label'] ?? 'Points').toString(),
    );
  }

  static String _rawLineName(Map<String, dynamic> m) {
    final qty = (m['qty'] is num)
        ? (m['qty'] as num).toInt()
        : int.tryParse('${m['qty']}') ?? 1;
    final name = '${qty}x ${localizedLineName(m)}';
    final free = m['is_free_promo'] == true;
    // full_product_name already ends in "(FREE)" / "(ຟຣີ)" on new servers.
    if (free && !name.contains('(FREE)') && !name.contains('(ຟຣີ)')) {
      return '$name (${_labels.free})';
    }
    return name;
  }

  static String _currency(Map<String, dynamic> data) =>
      safeCurrency((data['currency'] ?? 'LAK').toString());

  /// Reprint of a past receipt from `/api/pos/order/<id>/receipt` data.
  static List<PrintLine> reprint(
    Map<String, dynamic> data, {
    int? queueNumber,
  }) {
    final currency = _currency(data);
    final total = _asDouble(data['amount_total']);
    final date = (data['date_order'] ?? '').toString();
    final lines = (data['lines'] as List?) ?? const [];
    String field(String key) => (data[key] ?? '').toString().trim();
    return [
      ..._header(data['header_text']?.toString()),
      PrintLine.text(
        '** ${_labels.reprint} **',
        bold: true,
        align: PrintAlign.center,
      ),
      const PrintLine.rule(),
      ..._queue(queueNumber),
      if (field('order_reference').isNotEmpty)
        PrintLine.text('${_labels.order}: ${field('order_reference')}'),
      if (date.isNotEmpty)
        PrintLine.text(
          '${_labels.date}: ${date.substring(0, date.length > 19 ? 19 : date.length)}',
        ),
      if (field('cashier').isNotEmpty)
        PrintLine.text('${_labels.cashier}: ${field('cashier')}'),
      if (field('table').isNotEmpty)
        PrintLine.text('${_labels.table}: ${field('table')}'),
      const PrintLine.rule(),
      for (final line in lines)
        if (line is Map)
          PrintLine.row(
            _rawLineName(Map<String, dynamic>.from(line)),
            money(_asDouble(line['subtotal']), currency: currency),
          ),
      const PrintLine.rule(),
      if (_asDouble(data['amount_discount']) > 0)
        PrintLine.row(
          '${_labels.discount}:',
          '-${money(_asDouble(data['amount_discount']), currency: currency)}',
        ),
      PrintLine.row(
        '${_labels.total}:',
        money(total, currency: currency),
        size: PrintSize.large,
        bold: true,
      ),
      ..._payments(paymentsFromRaw(data, total: total), 0, currency: currency),
      ..._customer(customerFromRaw(data)),
      ..._footer(data['footer_text']?.toString()),
      const PrintLine.feed(3),
      const PrintLine.cut(),
    ];
  }

  /// Refund slip from receipt data.
  static List<PrintLine> refund(
    Map<String, dynamic> data, {
    String? headerText,
    String? footerText,
    int? queueNumber,
    DateTime? at,
  }) {
    final currency = _currency(data);
    final total = _asDouble(data['amount_total']);
    final lines = (data['lines'] as List?) ?? const [];
    String field(String key) => (data[key] ?? '').toString().trim();
    return [
      ..._header(headerText ?? data['header_text']?.toString()),
      PrintLine.text(
        '** ${_labels.refund} **',
        bold: true,
        align: PrintAlign.center,
      ),
      const PrintLine.rule(),
      ..._queue(queueNumber),
      if (field('order_reference').isNotEmpty)
        PrintLine.text('${_labels.order}: ${field('order_reference')}'),
      PrintLine.text('Refund ${_labels.date}: ${_stamp(at ?? DateTime.now())}'),
      if (field('cashier').isNotEmpty)
        PrintLine.text('${_labels.cashier}: ${field('cashier')}'),
      if (field('payment_method').isNotEmpty)
        PrintLine.text('Payment: ${field('payment_method')}'),
      const PrintLine.rule(),
      for (final line in lines)
        if (line is Map)
          PrintLine.row(
            _rawLineName(Map<String, dynamic>.from(line)),
            money(_asDouble(line['subtotal']), currency: currency),
          ),
      const PrintLine.rule(),
      PrintLine.row(
        'REFUND AMOUNT:',
        money(total, currency: currency),
        size: PrintSize.large,
        bold: true,
      ),
      const PrintLine.feed(1),
      const PrintLine.text(
        'Refund Processed',
        bold: true,
        align: PrintAlign.center,
      ),
      for (final line in _templateLines(
        footerText ?? data['footer_text']?.toString(),
      ))
        PrintLine.text(line, align: PrintAlign.center),
      const PrintLine.feed(3),
      const PrintLine.cut(),
    ];
  }

  /// Map common non-ASCII currency symbols (e.g. `₭`, `€`) to their code.
  static String safeCurrency(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 'LAK';
    const map = <String, String>{
      '₭': 'LAK',
      '€': 'EUR',
      '£': 'GBP',
      '¥': 'JPY',
      '฿': 'THB',
      '₫': 'VND',
      '₱': 'PHP',
      '₩': 'KRW',
    };
    return map[s] ?? s;
  }
}

/// Draws [PrintLine]s as ESC/POS bytes.
///
/// Every line of text is drawn with the bundled Noto Serif Lao font and sent
/// as a bitmap: printer code pages have no Lao glyphs, and one font for all
/// text keeps Lao and English lines the same height and weight. Only the
/// dashed rules are printer text.
class PrintRenderer {
  PrintRenderer(this.paperSize);

  final PaperSize paperSize;

  static const String fontFamily = 'NotoSerifLao';
  static const String logoAsset = 'assets/images/receipt_logo.png';

  static img.Image? _logo;
  static bool _logoLoaded = false;

  /// Width of a bitmap line, in printer dots.
  int get width => paperSize.width;

  static double fontSize(PrintSize size) => switch (size) {
    PrintSize.small => 21,
    PrintSize.normal => 24,
    PrintSize.medium => 28,
    PrintSize.large => 32,
    PrintSize.huge => 46,
  };

  static Future<img.Image?> _loadLogo() async {
    if (_logoLoaded) return _logo;
    _logoLoaded = true;
    try {
      final data = await rootBundle.load(logoAsset);
      _logo = img.decodePng(data.buffer.asUint8List());
    } catch (e) {
      _printerLog('Receipt logo unavailable: $e');
    }
    return _logo;
  }

  Future<List<int>> render(List<PrintLine> lines) async {
    final gen = Generator(paperSize, await CapabilityProfile.load());
    final out = <int>[...gen.reset()];
    for (final line in lines) {
      switch (line.kind) {
        case PrintLineKind.rule:
          out.addAll(gen.hr());
        case PrintLineKind.feed:
          if (line.lines > 0) out.addAll(gen.feed(line.lines));
        case PrintLineKind.cut:
          out.addAll(gen.cut());
        case PrintLineKind.logo:
          final logo = await _loadLogo();
          if (logo != null) {
            out.addAll(gen.imageRaster(logo, align: PosAlign.center));
          }
        case PrintLineKind.text:
        case PrintLineKind.row:
          if (line.text.isEmpty && line.right.isEmpty) continue;
          final bitmap = await _draw(line);
          if (bitmap != null) {
            out.addAll(gen.imageRaster(bitmap, align: PosAlign.left));
          }
      }
    }
    return out;
  }

  ui.Paragraph _paragraph(
    String text,
    PrintLine line, {
    required double maxWidth,
    TextAlign align = TextAlign.left,
  }) {
    final size = fontSize(line.size);
    final weight = line.bold ? FontWeight.w700 : FontWeight.w400;
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: align,
              fontFamily: fontFamily,
              fontSize: size,
              fontWeight: weight,
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: const Color(0xFF000000),
              fontFamily: fontFamily,
              fontSize: size,
              fontWeight: weight,
            ),
          )
          ..addText(text);
    return builder.build()..layout(ui.ParagraphConstraints(width: maxWidth));
  }

  Future<img.Image?> _draw(PrintLine line) async {
    const pad = 3.0;
    const gap = 16.0;
    final w = width.toDouble();
    final indent = line.indent.toDouble().clamp(0.0, w / 2).toDouble();

    ui.Paragraph? right;
    double rightWidth = 0;
    if (line.kind == PrintLineKind.row && line.right.isNotEmpty) {
      right = _paragraph(line.right, line, maxWidth: w);
      rightWidth = right.maxIntrinsicWidth.ceilToDouble();
    }
    // A price that leaves the name less than 40% of the line goes below it.
    final stacked = right != null && w - rightWidth - gap < w * 0.4;
    final leftWidth = (right == null || stacked)
        ? w - indent
        : w - indent - rightWidth - gap;
    final left = _paragraph(
      line.text,
      line,
      maxWidth: leftWidth,
      align: switch (line.align) {
        PrintAlign.center => TextAlign.center,
        PrintAlign.right => TextAlign.right,
        PrintAlign.left => TextAlign.left,
      },
    );

    var height = left.height;
    if (right != null) {
      height = stacked
          ? left.height + right.height
          : (right.height > height ? right.height : height);
    }
    final h = (height + pad * 2).ceil().clamp(1, 2000).toInt();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const Color(0xFFFFFFFF), ui.BlendMode.src);
    canvas.drawParagraph(left, ui.Offset(indent, pad));
    if (right != null) {
      final dy = stacked
          ? pad + left.height
          : pad + left.alphabeticBaseline - right.alphabeticBaseline;
      canvas.drawParagraph(right, ui.Offset(w - rightWidth, dy));
    }
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(width, h);
    picture.dispose();
    final byteData = await rendered.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    rendered.dispose();
    if (byteData == null) return null;
    return img.Image.fromBytes(
      width,
      h,
      Uint8List.view(byteData.buffer),
      format: img.Format.rgba,
    );
  }
}

class PrinterProfile {
  final String id;
  final String name;
  final String ip;
  final int port;
  final int paperWidthMm;
  final bool printReceiptsAndBills;
  final bool printOrders;
  final bool singleItemPerTicket;
  final bool groupIdenticalItems;
  final List<String> categoryFilters;

  const PrinterProfile({
    required this.id,
    required this.name,
    required this.ip,
    this.port = 9100,
    this.paperWidthMm = 80,
    this.printReceiptsAndBills = true,
    this.printOrders = false,
    this.singleItemPerTicket = false,
    this.groupIdenticalItems = true,
    this.categoryFilters = const [],
  });

  PaperSize get paperSize =>
      paperWidthMm == 58 ? PaperSize.mm58 : PaperSize.mm80;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ip': ip,
    'port': port,
    'paperWidthMm': paperWidthMm,
    'printReceiptsAndBills': printReceiptsAndBills,
    'printOrders': printOrders,
    'singleItemPerTicket': singleItemPerTicket,
    'groupIdenticalItems': groupIdenticalItems,
    'categoryFilters': categoryFilters,
  };

  factory PrinterProfile.fromJson(Map<String, dynamic> json) {
    return PrinterProfile(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Printer').toString(),
      ip: (json['ip'] ?? '').toString(),
      port: int.tryParse((json['port'] ?? 9100).toString()) ?? 9100,
      paperWidthMm: int.tryParse((json['paperWidthMm'] ?? 80).toString()) ?? 80,
      printReceiptsAndBills: json['printReceiptsAndBills'] == true,
      printOrders: json['printOrders'] == true,
      singleItemPerTicket: json['singleItemPerTicket'] == true,
      groupIdenticalItems: json['groupIdenticalItems'] != false,
      categoryFilters: (json['categoryFilters'] is List)
          ? (json['categoryFilters'] as List)
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList()
          : <String>[],
    );
  }

  PrinterProfile copyWith({
    String? id,
    String? name,
    String? ip,
    int? port,
    int? paperWidthMm,
    bool? printReceiptsAndBills,
    bool? printOrders,
    bool? singleItemPerTicket,
    bool? groupIdenticalItems,
    List<String>? categoryFilters,
  }) {
    return PrinterProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      printReceiptsAndBills:
          printReceiptsAndBills ?? this.printReceiptsAndBills,
      printOrders: printOrders ?? this.printOrders,
      singleItemPerTicket: singleItemPerTicket ?? this.singleItemPerTicket,
      groupIdenticalItems: groupIdenticalItems ?? this.groupIdenticalItems,
      categoryFilters: categoryFilters ?? this.categoryFilters,
    );
  }
}

class PrinterService {
  static const _printersKey = 'printer_profiles_v1';
  static const _receiptPrinterIdKey = 'receipt_printer_id_v1';
  static const Duration _connectTimeout = Duration(seconds: 4);

  /// Time to keep the connection open after the last byte is written.
  /// Closing at once dropped the tail of a job on some printers — most
  /// visibly the cash-drawer pulse, which is only a few bytes.
  static const Duration _settleDelay = Duration(milliseconds: 600);

  List<PrinterProfile> _profiles = [];
  String? _receiptPrinterId;
  bool _initialized = false;

  String? _printerIp;
  int _printerPort = 9100;
  PaperSize _paperSize = PaperSize.mm80;

  List<PrinterProfile> get profiles => List.unmodifiable(_profiles);
  String? get selectedReceiptPrinterId => _receiptPrinterId;

  String? get printerIp {
    final p = _getReceiptPrinter();
    return p?.ip ?? _printerIp;
  }

  int get printerPort {
    final p = _getReceiptPrinter();
    return p?.port ?? _printerPort;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_printersKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _profiles = decoded
              .whereType<Map>()
              .map((e) => PrinterProfile.fromJson(Map<String, dynamic>.from(e)))
              .where((p) => p.ip.trim().isNotEmpty)
              .toList();
        }
      } catch (_) {
        _profiles = [];
      }
    }
    _receiptPrinterId = prefs.getString(_receiptPrinterIdKey);
    _initialized = true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _printersKey,
      jsonEncode(_profiles.map((p) => p.toJson()).toList()),
    );
    if (_receiptPrinterId == null || _receiptPrinterId!.isEmpty) {
      await prefs.remove(_receiptPrinterIdKey);
    } else {
      await prefs.setString(_receiptPrinterIdKey, _receiptPrinterId!);
    }
  }

  PrinterProfile? _getReceiptPrinter() {
    if (_profiles.isEmpty) return null;
    if (_receiptPrinterId != null) {
      final selected = _profiles
          .where((p) => p.id == _receiptPrinterId)
          .firstOrNull;
      if (selected != null) return selected;
    }
    final enabled = _profiles.where((p) => p.printReceiptsAndBills).toList();
    return enabled.isNotEmpty ? enabled.first : _profiles.first;
  }

  PrinterProfile? get _legacyProfile {
    if (_printerIp == null || _printerIp!.isEmpty) return null;
    return PrinterProfile(
      id: 'legacy',
      name: 'Printer',
      ip: _printerIp!,
      port: _printerPort,
      paperWidthMm: _paperSize == PaperSize.mm58 ? 58 : 80,
      printReceiptsAndBills: true,
    );
  }

  /// Printers that take receipts and bills (or the legacy single printer).
  List<PrinterProfile> get _receiptPrinters {
    if (_profiles.isNotEmpty) {
      return _profiles.where((p) => p.printReceiptsAndBills).toList();
    }
    final legacy = _legacyProfile;
    return legacy == null ? const [] : [legacy];
  }

  void configure({
    required String ip,
    int port = 9100,
    PaperSize paperSize = PaperSize.mm80,
  }) {
    _printerIp = ip;
    _printerPort = port;
    _paperSize = paperSize;
  }

  bool get isConfigured =>
      _profiles.isNotEmpty || (_printerIp != null && _printerIp!.isNotEmpty);

  Future<void> savePrinter(
    PrinterProfile profile, {
    bool setAsReceiptPrinter = false,
  }) async {
    await initialize();
    final idx = _profiles.indexWhere((p) => p.id == profile.id);
    if (idx >= 0) {
      _profiles[idx] = profile;
    } else {
      _profiles.add(profile);
    }
    if (setAsReceiptPrinter || _receiptPrinterId == null) {
      _receiptPrinterId = profile.id;
    }
    await _persist();
  }

  Future<void> deletePrinter(String id) async {
    await initialize();
    _profiles.removeWhere((p) => p.id == id);
    if (_receiptPrinterId == id) {
      _receiptPrinterId = _profiles.isNotEmpty ? _profiles.first.id : null;
    }
    await _persist();
  }

  Future<void> setReceiptPrinter(String id) async {
    await initialize();
    _receiptPrinterId = id;
    await _persist();
  }

  /// Opens a raw TCP connection (port 9100), writes [bytes] and waits for
  /// them to leave before closing. `NetworkPrinter.disconnect()` destroyed
  /// the socket straight away, which could drop whatever was still buffered.
  Future<bool> _send(PrinterProfile profile, List<int> bytes) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        profile.ip,
        profile.port,
        timeout: _connectTimeout,
      );
      socket.add(bytes);
      await socket.flush();
      await Future<void>.delayed(_settleDelay);
      return true;
    } catch (e) {
      _printerLog(
        'Send to ${profile.name} (${profile.ip}:${profile.port}) failed: $e',
      );
      return false;
    } finally {
      socket?.destroy();
    }
  }

  Future<bool> _printLines(
    PrinterProfile profile,
    List<PrintLine> lines,
    String what,
  ) async {
    try {
      final bytes = await PrintRenderer(profile.paperSize).render(lines);
      return _send(profile, bytes);
    } catch (e, st) {
      _printerLog('Print $what on ${profile.name} failed: $e\n$st');
      return false;
    }
  }

  Future<bool> testProfile(PrinterProfile profile) {
    return _printLines(profile, [
      const PrintLine.text(
        '=== LaDolce POS ===',
        bold: true,
        align: PrintAlign.center,
      ),
      PrintLine.text('Printer: ${profile.name}', align: PrintAlign.center),
      const PrintLine.text('Test page OK', align: PrintAlign.center),
      const PrintLine.feed(3),
      const PrintLine.cut(),
    ], 'test page');
  }

  Future<bool> testConnection() async {
    await initialize();
    final p = _getReceiptPrinter() ?? _legacyProfile;
    if (p == null) return false;
    return testProfile(p);
  }

  Future<bool> printOrderTicketDirect({
    required PrinterProfile profile,
    required List<CartItem> items,
    required String cashierName,
    String? headerText,
    String? footerText,
    int? queueNumber,
  }) {
    return _printLines(
      profile,
      PrintLayouts.orderTicket(
        items: items,
        cashierName: cashierName,
        footerText: footerText,
        queueNumber: queueNumber,
        singleItemPerTicket: profile.singleItemPerTicket,
        groupIdenticalItems: profile.groupIdenticalItems,
      ),
      'order ticket',
    );
  }

  /// Receipt on every receipt printer, plus order tickets on order printers.
  Future<bool> printReceipt({
    required List<CartItem> cartItems,
    required double subtotal,
    required double tax,
    required double total,
    String cashierName = 'Cashier',
    String subtotalRowLabel = 'Subtotal:',
    String? taxRowLabel,
    String? headerText,
    String? footerText,
    double discountAmount = 0.0,
    int? queueNumber,
    List<ReceiptPayment> payments = const [],
    double changeAmount = 0.0,
    ReceiptCustomer? customer,
  }) async {
    await initialize();
    if (!isConfigured) return false;

    bool allSuccess = true;
    for (final p in _receiptPrinters) {
      final ok = await printReceiptToProfile(
        p,
        cartItems: cartItems,
        subtotal: subtotal,
        tax: tax,
        total: total,
        cashierName: cashierName,
        subtotalRowLabel: subtotalRowLabel,
        taxRowLabel: taxRowLabel,
        headerText: headerText,
        footerText: footerText,
        discountAmount: discountAmount,
        queueNumber: queueNumber,
        payments: payments,
        changeAmount: changeAmount,
        customer: customer,
      );
      allSuccess = allSuccess && ok;
    }
    for (final p in _profiles.where((p) => p.printOrders)) {
      final filtered = _filterItemsForPrinter(cartItems, p);
      if (filtered.isEmpty) continue;
      final ok = await printOrderTicketDirect(
        profile: p,
        items: filtered,
        cashierName: cashierName,
      );
      allSuccess = allSuccess && ok;
    }
    return allSuccess;
  }

  List<CartItem> _filterItemsForPrinter(
    List<CartItem> items,
    PrinterProfile printer,
  ) {
    if (printer.categoryFilters.isEmpty) return items;
    final filters = printer.categoryFilters
        .map((e) => e.trim().toLowerCase())
        .toSet();
    return items
        .where((i) => filters.contains(i.product.category.trim().toLowerCase()))
        .toList();
  }

  Future<bool> printBill({
    required List<CartItem> cartItems,
    required double subtotal,
    required double tax,
    required double total,
    String cashierName = 'Cashier',
    String? ticketName,
    String subtotalRowLabel = 'Subtotal:',
    String? taxRowLabel,
    String? headerText,
    String? footerText,
    double discountAmount = 0.0,
    int? queueNumber,
  }) async {
    await initialize();
    final printers = _receiptPrinters;
    if (printers.isEmpty) return false;

    final lines = PrintLayouts.bill(
      items: cartItems,
      subtotal: subtotal,
      tax: tax,
      total: total,
      cashierName: cashierName,
      ticketName: ticketName,
      subtotalRowLabel: subtotalRowLabel,
      taxRowLabel: taxRowLabel,
      headerText: headerText,
      footerText: footerText,
      discountAmount: discountAmount,
      queueNumber: queueNumber,
    );
    bool allSuccess = true;
    for (final p in printers) {
      final ok = await _printLines(p, lines, 'bill');
      allSuccess = allSuccess && ok;
    }
    return allSuccess;
  }

  /// Receipt on one printer — called by pos_screen after a charge.
  Future<bool> printReceiptToProfile(
    PrinterProfile profile, {
    required List<CartItem> cartItems,
    required double subtotal,
    required double tax,
    required double total,
    required String cashierName,
    String subtotalRowLabel = 'Subtotal:',
    String? taxRowLabel,
    String? headerText,
    String? footerText,
    double discountAmount = 0.0,
    int? queueNumber,
    List<ReceiptPayment> payments = const [],
    double changeAmount = 0.0,
    ReceiptCustomer? customer,
  }) {
    return _printLines(
      profile,
      PrintLayouts.receipt(
        items: cartItems,
        subtotal: subtotal,
        tax: tax,
        total: total,
        cashierName: cashierName,
        subtotalRowLabel: subtotalRowLabel,
        taxRowLabel: taxRowLabel,
        headerText: headerText,
        footerText: footerText,
        discountAmount: discountAmount,
        queueNumber: queueNumber,
        payments: payments,
        changeAmount: changeAmount,
        customer: customer,
      ),
      'receipt',
    );
  }

  /// Kicks the cash drawer wired to the receipt printer (pin 2).
  Future<bool> openCashDrawer() async {
    await initialize();
    final profile = _getReceiptPrinter() ?? _legacyProfile;
    if (profile == null) return false;
    // ESC @ (reset), then ESC p 0 25 250: pulse pin 2 for 50 ms / 500 ms.
    return _send(profile, const [0x1B, 0x40, 0x1B, 0x70, 0x00, 0x19, 0xFA]);
  }

  /// Reprint a historical receipt using raw order data from the API.
  /// [receiptData] is the map returned by fetchOrderReceipt() / the receipt
  /// history detail screen. Lines must contain 'product_name', 'qty', 'subtotal'.
  Future<bool> printReceiptFromRawData(
    Map<String, dynamic> receiptData, {
    int? queueNumber,
  }) async {
    await initialize();
    final printers = _receiptPrinters.where((p) => p.ip.isNotEmpty).toList();
    if (printers.isEmpty) {
      _printerLog('REPRINT >> no usable printer profile');
      return false;
    }
    final lines = PrintLayouts.reprint(receiptData, queueNumber: queueNumber);
    bool anyOk = false;
    for (final p in printers) {
      if (await _printLines(p, lines, 'reprint')) anyOk = true;
    }
    return anyOk;
  }

  /// Print a refund slip using raw order receipt data.
  Future<bool> printRefundFromRawData(
    Map<String, dynamic> receiptData, {
    String? headerText,
    String? footerText,
    int? queueNumber,
  }) async {
    await initialize();
    final printers = _receiptPrinters.where((p) => p.ip.isNotEmpty).toList();
    if (printers.isEmpty) {
      _printerLog('REFUND >> no usable printer profile');
      return false;
    }
    final lines = PrintLayouts.refund(
      receiptData,
      headerText: headerText,
      footerText: footerText,
      queueNumber: queueNumber,
    );
    bool anyOk = false;
    for (final p in printers) {
      if (await _printLines(p, lines, 'refund')) anyOk = true;
    }
    return anyOk;
  }
}

// Singleton instance
final printerService = PrinterService();
