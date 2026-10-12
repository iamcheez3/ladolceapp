import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart' show Color, FontWeight, TextAlign;
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';
import '../utils/localized_name.dart';

void _printerLog(String message) {
  developer.log(message, name: 'PrinterService');
  // Mirror to stdout so it shows in `flutter run` console output too.
  // ignore: avoid_print
  print('[PrinterService] $message');
}

/// Static receipt copy for code that prints outside the widget tree.
///
/// Printer jobs can continue after their screen is closed, so reading the
/// app-wide display language is safer than retaining a BuildContext.
/// Fixed English copy for every printed document.
///
/// Only menu names follow the app language on paper (see [Product.displayName]
/// and [localizedLineName]) — the labels around them stay English by decision,
/// so a bill or kitchen ticket reads the same to every staff member no matter
/// which language the cashier happens to have the app set to.
class ReceiptPrintLabels {
  final String pointOfSale;
  final String printer;
  final String date;
  final String cashier;
  final String order;
  final String table;
  final String payment;
  final String reprint;
  final String discount;
  final String total;
  final String thankYou;
  final String pleaseComeAgain;
  final String orderTicket;
  final String note;

  const ReceiptPrintLabels({
    required this.pointOfSale,
    required this.printer,
    required this.date,
    required this.cashier,
    required this.order,
    required this.table,
    required this.payment,
    required this.reprint,
    required this.discount,
    required this.total,
    required this.thankYou,
    required this.pleaseComeAgain,
    required this.orderTicket,
    required this.note,
  });

  static const ReceiptPrintLabels english = ReceiptPrintLabels(
    pointOfSale: 'Point of Sale',
    printer: 'Printer',
    date: 'Date',
    cashier: 'Cashier',
    order: 'Order',
    table: 'Table',
    payment: 'Payment',
    reprint: 'REPRINT',
    discount: 'Discount',
    total: 'TOTAL',
    thankYou: 'Thank you!',
    pleaseComeAgain: 'Please come again',
    orderTicket: 'Kitchen / Order Ticket',
    note: 'NOTE',
  );
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

  List<PrinterProfile> _profiles = [];
  String? _receiptPrinterId;
  bool _initialized = false;

  String? _printerIp;
  int _printerPort = 9100;
  PaperSize _paperSize = PaperSize.mm80;

  ReceiptPrintLabels get _labels => ReceiptPrintLabels.english;

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  double _asDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  /// ESC/POS printers commonly choke on Unicode (e.g. Lao/Thai) depending on
  /// selected code table. To avoid aborting the whole print, sanitize to a
  /// conservative ASCII subset. (Better: choose a proper code table per printer,
  /// but this keeps prints reliable.)
  String _sanitizeForEscPos(String input) {
    final sb = StringBuffer();
    for (final codeUnit in input.codeUnits) {
      // Keep printable ASCII + basic whitespace.
      if (codeUnit == 0x09 || codeUnit == 0x0A || codeUnit == 0x0D) {
        sb.writeCharCode(codeUnit);
        continue;
      }
      if (codeUnit >= 0x20 && codeUnit <= 0x7E) {
        sb.writeCharCode(codeUnit);
      } else {
        sb.write('?');
      }
    }
    return sb.toString();
  }

  /// Map common non-ASCII currency symbols (e.g. `₭`, `€`, `£`, `¥`) to safe
  /// ASCII so the ESC/POS Latin-1 encoder doesn't throw mid-print.
  String _safeCurrency(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 'LAK';
    final map = <String, String>{
      '₭': 'LAK',
      '€': 'EUR',
      '£': 'GBP',
      '¥': 'JPY',
      '฿': 'THB',
      '₫': 'VND',
      '₱': 'PHP',
      '₩': 'KRW',
      '\$': '\$',
    };
    if (map.containsKey(s)) return map[s]!;
    // Fallback: if all chars are ASCII, keep as-is, otherwise sanitize.
    final sanitized = _sanitizeForEscPos(s);
    if (sanitized.replaceAll('?', '').trim().isEmpty) return 'LAK';
    return sanitized;
  }

  String _trimToFit(String s, int maxChars) {
    if (maxChars <= 0) return '';
    if (s.length <= maxChars) return s;
    if (maxChars <= 1) return s.substring(0, maxChars);
    // Use ASCII-only truncation marker; many ESC/POS printers can't encode `…`.
    if (maxChars <= 3) return s.substring(0, maxChars);
    return '${s.substring(0, maxChars - 3)}...';
  }

  bool _needsUnicodeRaster(String text) =>
      text.codeUnits.any((codeUnit) => codeUnit > 0x7E);

  /// Prints Unicode (including Lao) as a monochrome raster image. ESC/POS text
  /// code pages do not reliably contain Lao glyphs, while bitmap printing works
  /// on standard network thermal printers.
  Future<void> _printUnicodeText(
    NetworkPrinter printer,
    String text, {
    PosStyles styles = const PosStyles(),
    PosAlign align = PosAlign.left,
    int paperWidthMm = 80,
  }) async {
    if (!_needsUnicodeRaster(text)) {
      printer.text(text, styles: styles.copyWith(align: align));
      return;
    }

    // Use the platform's bundled Lao font instead of asking google_fonts to
    // download one at print time. Android ships Noto Sans Lao and iOS resolves
    // this through its Lao-capable fallback font.
    const laoFontFamily = 'Noto Sans Lao';
    final width = paperWidthMm == 58 ? 360 : 560;
    final fontSize = styles.height == PosTextSize.size2 ? 34.0 : 24.0;
    final paragraph =
        (ui.ParagraphBuilder(
                ui.ParagraphStyle(
                  textAlign: switch (align) {
                    PosAlign.center => TextAlign.center,
                    PosAlign.right => TextAlign.right,
                    _ => TextAlign.left,
                  },
                  fontFamily: laoFontFamily,
                  fontSize: fontSize,
                  fontWeight: styles.bold ? FontWeight.w700 : FontWeight.w400,
                ),
              )
              ..pushStyle(
                ui.TextStyle(
                  color: const Color(0xFF000000),
                  fontFamily: laoFontFamily,
                  fontSize: fontSize,
                  fontWeight: styles.bold ? FontWeight.w700 : FontWeight.w400,
                ),
              )
              ..addText(text))
            .build()
          ..layout(ui.ParagraphConstraints(width: width.toDouble()));
    final height = paragraph.height.ceil().clamp(1, 1200);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const Color(0xFFFFFFFF), ui.BlendMode.src);
    canvas.drawParagraph(paragraph, ui.Offset.zero);
    final rendered = await recorder.endRecording().toImage(width, height);
    final byteData = await rendered.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    rendered.dispose();
    if (byteData == null) return;
    final image = img.Image.fromBytes(
      width,
      height,
      Uint8List.view(byteData.buffer),
      format: img.Format.rgba,
    );
    printer.imageRaster(image, align: align);
  }

  Future<void> _printItemLine(
    NetworkPrinter printer, {
    required String name,
    required String price,
    required int paperWidthMm,
    bool bold = true,
    bool large = false,
  }) async {
    final label = name;
    final styles = PosStyles(
      bold: bold,
      height: large ? PosTextSize.size2 : PosTextSize.size1,
    );
    if (!_needsUnicodeRaster(label)) {
      printer.row([
        PosColumn(text: label, width: 8, styles: styles),
        PosColumn(
          text: price,
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      return;
    }
    await _printUnicodeText(
      printer,
      label,
      styles: styles,
      paperWidthMm: paperWidthMm,
    );
    if (price.isNotEmpty) {
      printer.text(price, styles: const PosStyles(align: PosAlign.right));
    }
  }

  /// ESC/POS columns cannot encode Lao. For localized labels, print the label
  /// as a bitmap and keep the numeric value right-aligned on the following
  /// printer text line.
  Future<void> _printAmountRow(
    NetworkPrinter printer, {
    required String label,
    required String value,
    required int paperWidthMm,
    bool bold = false,
    bool large = false,
  }) async {
    final styles = PosStyles(
      bold: bold,
      height: large ? PosTextSize.size2 : PosTextSize.size1,
    );
    if (_needsUnicodeRaster(label)) {
      await _printUnicodeText(
        printer,
        label,
        styles: styles,
        paperWidthMm: paperWidthMm,
      );
      printer.text(
        value,
        styles: PosStyles(
          align: PosAlign.right,
          bold: bold,
          height: large ? PosTextSize.size2 : PosTextSize.size1,
        ),
      );
      return;
    }
    printer.row([
      PosColumn(text: label, width: 8, styles: styles),
      PosColumn(
        text: value,
        width: 4,
        styles: PosStyles(
          align: PosAlign.right,
          bold: bold,
          height: large ? PosTextSize.size2 : PosTextSize.size1,
        ),
      ),
    ]);
  }

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

  Future<bool> testProfile(PrinterProfile profile) async {
    try {
      final printer = NetworkPrinter(
        profile.paperSize,
        await CapabilityProfile.load(),
      );
      final result = await printer
          .connect(profile.ip, port: profile.port)
          .timeout(_connectTimeout);
      if (result != PosPrintResult.success) return false;
      try {
        printer.text(
          '=== LaDolce POS ===',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );
        printer.text(
          'Printer: ${profile.name}',
          styles: const PosStyles(align: PosAlign.center),
        );
        printer.text(
          'Test page OK',
          styles: const PosStyles(align: PosAlign.center),
        );
        printer.feed(3);
        printer.cut();
      } finally {
        try {
          printer.disconnect();
        } catch (_) {}
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> printOrderTicketDirect({
    required PrinterProfile profile,
    required List<CartItem> items,
    required String cashierName,
    String? headerText,
    String? footerText,
    int? queueNumber,
  }) async {
    return _printOrderTicketToProfile(
      profile,
      items: items,
      cashierName: cashierName,
      headerText: headerText,
      footerText: footerText,
      queueNumber: queueNumber,
    );
  }

  Future<bool> testConnection() async {
    await initialize();
    final p = _getReceiptPrinter();
    if (p != null) return testProfile(p);
    if (!isConfigured) return false;

    try {
      final printer = NetworkPrinter(
        _paperSize,
        await CapabilityProfile.load(),
      );
      final result = await printer
          .connect(_printerIp!, port: _printerPort)
          .timeout(_connectTimeout);

      if (result == PosPrintResult.success) {
        try {
          printer.text(
            '=== LaDolce POS ===',
            styles: const PosStyles(align: PosAlign.center, bold: true),
          );
          printer.text(
            'Printer Test OK!',
            styles: const PosStyles(align: PosAlign.center),
          );
          printer.feed(3);
          printer.cut();
        } finally {
          try {
            printer.disconnect();
          } catch (_) {}
        }
        return true;
      }
      return false;
    } catch (e) {
      _printerLog('[PRINTER] Test connection failed: $e');
      return false;
    }
  }

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
  }) async {
    await initialize();
    if (!isConfigured) return false;

    try {
      if (_profiles.isNotEmpty) {
        bool allSuccess = true;
        final receiptPrinters = _profiles
            .where((p) => p.printReceiptsAndBills)
            .toList();
        final orderPrinters = _profiles.where((p) => p.printOrders).toList();

        for (final p in receiptPrinters) {
          final ok = await _printReceiptToProfile(
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
          );
          allSuccess = allSuccess && ok;
        }

        for (final p in orderPrinters) {
          final filtered = _filterItemsForPrinter(cartItems, p);
          if (filtered.isEmpty) continue;
          final ok = await _printOrderTicketToProfile(
            p,
            items: filtered,
            cashierName: cashierName,
          );
          allSuccess = allSuccess && ok;
        }
        return allSuccess;
      }

      // Legacy fallback
      if (_printerIp == null || _printerIp!.isEmpty) return false;
      final legacy = PrinterProfile(
        id: 'legacy',
        name: 'Printer',
        ip: _printerIp!,
        port: _printerPort,
        paperWidthMm: _paperSize == PaperSize.mm58 ? 58 : 80,
        printReceiptsAndBills: true,
      );
      return _printReceiptToProfile(
        legacy,
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
      );
    } catch (e) {
      _printerLog('[PRINTER] Print receipt failed: $e');
      return false;
    }
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

  /// Helper to format queue number as #001
  String _fmtQueue(int? qn) {
    if (qn == null || qn <= 0) return '';
    return '#${qn.toString().padLeft(3, '0')}';
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
    if (!isConfigured) return false;

    final printers = _profiles.isNotEmpty
        ? _profiles.where((p) => p.printReceiptsAndBills).toList()
        : [
            PrinterProfile(
              id: 'legacy',
              name: 'Printer',
              ip: _printerIp!,
              port: _printerPort,
              paperWidthMm: _paperSize == PaperSize.mm58 ? 58 : 80,
              printReceiptsAndBills: true,
            ),
          ];

    if (printers.isEmpty) return false;

    bool allSuccess = true;
    for (final p in printers) {
      final ok = await _printBillToProfile(
        p,
        cartItems: cartItems,
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
      allSuccess = allSuccess && ok;
    }
    return allSuccess;
  }

  Future<bool> _printBillToProfile(
    PrinterProfile profile, {
    required List<CartItem> cartItems,
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
  }) async {
    final labels = _labels;
    final cap = await CapabilityProfile.load();
    final printer = NetworkPrinter(profile.paperSize, cap);
    try {
      final result = await printer
          .connect(profile.ip, port: profile.port)
          .timeout(_connectTimeout);
      if (result != PosPrintResult.success) return false;

      final head = (headerText ?? '').trim();
      if (head.isNotEmpty) {
        for (final line in head.split('\n')) {
          final t = line.trimRight();
          if (t.isEmpty) continue;
          await _printUnicodeText(
            printer,
            t,
            styles: const PosStyles(align: PosAlign.center, bold: true),
            align: PosAlign.center,
            paperWidthMm: profile.paperWidthMm,
          );
        }
      } else {
        printer.text(
          'LaDolce',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        );
        await _printUnicodeText(
          printer,
          labels.pointOfSale,
          styles: const PosStyles(align: PosAlign.center),
          align: PosAlign.center,
          paperWidthMm: profile.paperWidthMm,
        );
      }
      if (ticketName != null && ticketName.isNotEmpty) {
        await _printUnicodeText(
          printer,
          ticketName,
          styles: const PosStyles(align: PosAlign.center, bold: true),
          align: PosAlign.center,
          paperWidthMm: profile.paperWidthMm,
        );
      }
      printer.hr();
      if (queueNumber != null && queueNumber > 0) {
        printer.text(
          _fmtQueue(queueNumber),
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        );
        printer.hr();
      }
      await _printUnicodeText(
        printer,
        '${labels.date}: ${DateTime.now().toString().substring(0, 19)}',
        paperWidthMm: profile.paperWidthMm,
      );
      await _printUnicodeText(
        printer,
        '${labels.cashier}: $cashierName',
        paperWidthMm: profile.paperWidthMm,
      );
      printer.hr();

      for (final item in cartItems) {
        await _printItemLine(
          printer,
          name: '${item.quantity}x ${item.product.displayName}',
          price: 'LAK ${item.totalPrice.toStringAsFixed(2)}',
          paperWidthMm: profile.paperWidthMm,
        );
        // Print toppings as sub-lines if any
        for (final topping in item.selectedToppings) {
          await _printItemLine(
            printer,
            name: '  + ${topping.name}',
            price: topping.extraPrice > 0
                ? 'LAK${topping.extraPrice.toStringAsFixed(2)}'
                : '',
            paperWidthMm: profile.paperWidthMm,
            bold: false,
          );
        }
      }

      printer.hr();
      if (discountAmount > 0) {
        await _printAmountRow(
          printer,
          label: '${labels.discount}:',
          value: '-LAK ${discountAmount.toStringAsFixed(2)}',
          paperWidthMm: profile.paperWidthMm,
          bold: true,
        );
      }
      final showTax =
          taxRowLabel != null && taxRowLabel.isNotEmpty && tax.abs() >= 0.005;
      if (showTax) {
        await _printAmountRow(
          printer,
          label: subtotalRowLabel,
          value: 'LAK ${subtotal.toStringAsFixed(2)}',
          paperWidthMm: profile.paperWidthMm,
        );
        await _printAmountRow(
          printer,
          label: taxRowLabel,
          value: 'LAK ${tax.toStringAsFixed(2)}',
          paperWidthMm: profile.paperWidthMm,
        );
        printer.hr(ch: '=');
      }
      await _printAmountRow(
        printer,
        label: '${labels.total}:',
        value: 'LAK ${total.toStringAsFixed(2)}',
        paperWidthMm: profile.paperWidthMm,
        bold: true,
        large: true,
      );
      printer.feed(1);
      printer.text(
        '** NOT A RECEIPT **',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      printer.text(
        'Please wait for your receipt',
        styles: const PosStyles(align: PosAlign.center),
      );
      final foot = (footerText ?? '').trim();
      if (foot.isNotEmpty) {
        printer.feed(1);
        for (final line in foot.split('\n')) {
          final t = line.trimRight();
          if (t.isEmpty) continue;
          await _printUnicodeText(
            printer,
            t,
            styles: const PosStyles(align: PosAlign.center),
            align: PosAlign.center,
            paperWidthMm: profile.paperWidthMm,
          );
        }
      }
      printer.feed(3);
      printer.cut();
      return true;
    } catch (e) {
      _printerLog('[PRINTER] Print bill failed: $e');
      return false;
    } finally {
      try {
        printer.disconnect();
      } catch (_) {}
    }
  }

  /// Public version — called directly by pos_screen for receipt-only printing after charge.
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
  }) => _printReceiptToProfile(
    profile,
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
  );

  Future<bool> _printReceiptToProfile(
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
  }) async {
    final labels = _labels;
    final cap = await CapabilityProfile.load();
    final printer = NetworkPrinter(profile.paperSize, cap);
    try {
      final result = await printer
          .connect(profile.ip, port: profile.port)
          .timeout(_connectTimeout);
      if (result != PosPrintResult.success) return false;

      final head = (headerText ?? '').trim();
      if (head.isNotEmpty) {
        for (final line in head.split('\n')) {
          final t = line.trimRight();
          if (t.isEmpty) continue;
          await _printUnicodeText(
            printer,
            t,
            styles: const PosStyles(align: PosAlign.center, bold: true),
            align: PosAlign.center,
            paperWidthMm: profile.paperWidthMm,
          );
        }
      } else {
        printer.text(
          'LaDolce',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        );
        await _printUnicodeText(
          printer,
          labels.pointOfSale,
          styles: const PosStyles(align: PosAlign.center),
          align: PosAlign.center,
          paperWidthMm: profile.paperWidthMm,
        );
      }
      await _printUnicodeText(
        printer,
        '${labels.printer}: ${profile.name}',
        styles: const PosStyles(align: PosAlign.center),
        align: PosAlign.center,
        paperWidthMm: profile.paperWidthMm,
      );
      printer.hr();
      if (queueNumber != null && queueNumber > 0) {
        printer.text(
          _fmtQueue(queueNumber),
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        );
        printer.hr();
      }
      await _printUnicodeText(
        printer,
        '${labels.date}: ${DateTime.now().toString().substring(0, 19)}',
        paperWidthMm: profile.paperWidthMm,
      );
      await _printUnicodeText(
        printer,
        '${labels.cashier}: $cashierName',
        paperWidthMm: profile.paperWidthMm,
      );
      printer.hr();
      for (final item in cartItems) {
        await _printItemLine(
          printer,
          name: '${item.quantity}x ${item.product.displayName}',
          price: 'LAK${item.totalPrice.toStringAsFixed(2)}',
          paperWidthMm: profile.paperWidthMm,
        );
      }
      printer.hr();
      if (discountAmount > 0) {
        await _printAmountRow(
          printer,
          label: '${labels.discount}:',
          value: '-LAK ${discountAmount.toStringAsFixed(2)}',
          paperWidthMm: profile.paperWidthMm,
          bold: true,
        );
      }
      final showTax =
          taxRowLabel != null && taxRowLabel.isNotEmpty && tax.abs() >= 0.005;
      if (showTax) {
        await _printAmountRow(
          printer,
          label: subtotalRowLabel,
          value: 'LAK${subtotal.toStringAsFixed(2)}',
          paperWidthMm: profile.paperWidthMm,
        );
        await _printAmountRow(
          printer,
          label: taxRowLabel,
          value: 'LAK${tax.toStringAsFixed(2)}',
          paperWidthMm: profile.paperWidthMm,
        );
        printer.hr(ch: '=');
      }
      await _printAmountRow(
        printer,
        label: '${labels.total}:',
        value: 'LAK${total.toStringAsFixed(2)}',
        paperWidthMm: profile.paperWidthMm,
        bold: true,
        large: true,
      );
      printer.feed(1);
      await _printUnicodeText(
        printer,
        labels.thankYou,
        styles: const PosStyles(align: PosAlign.center, bold: true),
        align: PosAlign.center,
        paperWidthMm: profile.paperWidthMm,
      );
      await _printUnicodeText(
        printer,
        labels.pleaseComeAgain,
        styles: const PosStyles(align: PosAlign.center),
        align: PosAlign.center,
        paperWidthMm: profile.paperWidthMm,
      );
      final foot = (footerText ?? '').trim();
      if (foot.isNotEmpty) {
        printer.feed(1);
        for (final line in foot.split('\n')) {
          final t = line.trimRight();
          if (t.isEmpty) continue;
          await _printUnicodeText(
            printer,
            t,
            styles: const PosStyles(align: PosAlign.center),
            align: PosAlign.center,
            paperWidthMm: profile.paperWidthMm,
          );
        }
      }
      printer.feed(3);
      printer.cut();
      return true;
    } catch (e) {
      _printerLog('[PRINTER] Print receipt failed: $e');
      return false;
    } finally {
      try {
        printer.disconnect();
      } catch (_) {}
    }
  }

  Future<bool> _printOrderTicketToProfile(
    PrinterProfile profile, {
    required List<CartItem> items,
    required String cashierName,
    String? headerText,
    String? footerText,
    int? queueNumber,
  }) async {
    final labels = _labels;
    final cap = await CapabilityProfile.load();
    final printer = NetworkPrinter(profile.paperSize, cap);
    try {
      final result = await printer
          .connect(profile.ip, port: profile.port)
          .timeout(_connectTimeout);
      if (result != PosPrintResult.success) return false;

      final head = (headerText ?? '').trim();
      if (head.isNotEmpty) {
        for (final line in head.split('\n')) {
          final t = line.trimRight();
          if (t.isEmpty) continue;
          await _printUnicodeText(
            printer,
            t,
            styles: const PosStyles(
              align: PosAlign.center,
              bold: true,
              height: PosTextSize.size2,
            ),
            align: PosAlign.center,
            paperWidthMm: profile.paperWidthMm,
          );
        }
      } else {
        await _printUnicodeText(
          printer,
          labels.orderTicket,
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
          ),
          align: PosAlign.center,
          paperWidthMm: profile.paperWidthMm,
        );
      }
      await _printUnicodeText(
        printer,
        '${labels.printer}: ${profile.name}',
        styles: const PosStyles(align: PosAlign.center),
        align: PosAlign.center,
        paperWidthMm: profile.paperWidthMm,
      );
      printer.hr();
      if (queueNumber != null && queueNumber > 0) {
        printer.text(
          _fmtQueue(queueNumber),
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        );
        printer.hr();
      }
      await _printUnicodeText(
        printer,
        '${labels.date}: ${DateTime.now().toString().substring(0, 19)}',
        paperWidthMm: profile.paperWidthMm,
      );
      await _printUnicodeText(
        printer,
        '${labels.cashier}: $cashierName',
        paperWidthMm: profile.paperWidthMm,
      );
      printer.hr();

      if (profile.singleItemPerTicket) {
        for (final i in items) {
          for (int q = 0; q < i.quantity; q++) {
            await _printUnicodeText(
              printer,
              '1x ${i.product.displayName}',
              styles: const PosStyles(bold: true, height: PosTextSize.size2),
              paperWidthMm: profile.paperWidthMm,
            );
            for (final topping in i.selectedToppings) {
              await _printUnicodeText(
                printer,
                '  + ${topping.name}',
                paperWidthMm: profile.paperWidthMm,
              );
            }
            final note = i.kitchenNote.trim();
            if (note.isNotEmpty) {
              await _printUnicodeText(
                printer,
                '  ${labels.note}: $note',
                styles: const PosStyles(bold: true),
                paperWidthMm: profile.paperWidthMm,
              );
            }
            printer.feed(2);
            printer.cut();
          }
        }
        return true;
      }

      final rows = <Map<String, dynamic>>[];
      if (profile.groupIdenticalItems) {
        final map = <String, Map<String, dynamic>>{};
        for (final i in items) {
          final toppingNames = i.selectedToppings.map((t) => t.name).toList();
          final note = i.kitchenNote.trim();
          final key = [i.product.id, toppingNames.join('|'), note].join('__');
          final row = map.putIfAbsent(
            key,
            () => {
              'name': i.product.displayName,
              'qty': 0,
              'toppings': toppingNames,
              'note': note,
            },
          );
          row['qty'] = (row['qty'] as int) + i.quantity;
        }
        rows.addAll(map.values);
      } else {
        for (final i in items) {
          rows.add({
            'name': i.product.displayName,
            'qty': i.quantity,
            'toppings': i.selectedToppings.map((t) => t.name).toList(),
            'note': i.kitchenNote.trim(),
          });
        }
      }

      for (final r in rows) {
        await _printUnicodeText(
          printer,
          '${r['qty']}x ${r['name']}',
          styles: const PosStyles(bold: true, height: PosTextSize.size2),
          paperWidthMm: profile.paperWidthMm,
        );
        final toppings = (r['toppings'] as List?) ?? const [];
        for (final topping in toppings) {
          await _printUnicodeText(
            printer,
            '  + $topping',
            paperWidthMm: profile.paperWidthMm,
          );
        }
        final note = (r['note'] ?? '').toString().trim();
        if (note.isNotEmpty) {
          await _printUnicodeText(
            printer,
            '  ${labels.note}: $note',
            styles: const PosStyles(bold: true),
            paperWidthMm: profile.paperWidthMm,
          );
        }
        printer.feed(1);
      }
      final foot = (footerText ?? '').trim();
      if (foot.isNotEmpty) {
        printer.feed(1);
        for (final line in foot.split('\n')) {
          final t = line.trimRight();
          if (t.isEmpty) continue;
          await _printUnicodeText(
            printer,
            t,
            styles: const PosStyles(align: PosAlign.center),
            align: PosAlign.center,
            paperWidthMm: profile.paperWidthMm,
          );
        }
      }
      printer.feed(2);
      printer.cut();
      return true;
    } catch (e) {
      _printerLog('[PRINTER] Print order ticket failed: $e');
      return false;
    } finally {
      try {
        printer.disconnect();
      } catch (_) {}
    }
  }

  Future<bool> openCashDrawer() async {
    await initialize();
    final p = _getReceiptPrinter();
    if (p == null && !isConfigured) return false;

    final profile =
        p ??
        PrinterProfile(
          id: 'legacy',
          name: 'Printer',
          ip: _printerIp!,
          port: _printerPort,
          paperWidthMm: _paperSize == PaperSize.mm58 ? 58 : 80,
        );

    try {
      final cap = await CapabilityProfile.load();
      final printer = NetworkPrinter(profile.paperSize, cap);
      final result = await printer
          .connect(profile.ip, port: profile.port)
          .timeout(_connectTimeout);
      if (result != PosPrintResult.success) return false;
      try {
        // ESC/POS cash drawer pulse: ESC p m t1 t2
        // Pin 2: ESC p 0 25 250
        // Pin 5: ESC p 1 25 250
        printer.rawBytes([0x1B, 0x70, 0x00, 0x19, 0xFA]); // pin 2
      } finally {
        try {
          printer.disconnect();
        } catch (_) {}
      }
      return true;
    } catch (e) {
      _printerLog('[PRINTER] Open cash drawer failed: $e');
      return false;
    }
  }

  /// Reprint a historical receipt using raw order data from the API.
  /// [receiptData] is the map returned by fetchOrderReceipt() / the receipt
  /// history detail screen. Lines must contain 'product_name', 'qty', 'subtotal'.
  Future<bool> printReceiptFromRawData(
    Map<String, dynamic> receiptData, {
    int? queueNumber,
  }) async {
    final labels = _labels;
    _printerLog('REPRINT >> START');
    _printerLog('REPRINT >> raw keys = ${receiptData.keys.toList()}');
    await initialize();
    if (!isConfigured) {
      _printerLog('REPRINT >> ABORT: printer not configured');
      return false;
    }

    final printers = _profiles.isNotEmpty
        ? _profiles.where((p) => p.printReceiptsAndBills).toList()
        : [
            PrinterProfile(
              id: 'legacy',
              name: 'Printer',
              ip: _printerIp ?? '',
              port: _printerPort,
              paperWidthMm: _paperSize == PaperSize.mm58 ? 58 : 80,
              printReceiptsAndBills: true,
            ),
          ];
    _printerLog(
      'REPRINT >> candidate printers = ${printers.length} '
      '${printers.map((p) => '${p.name}@${p.ip}:${p.port}/${p.paperWidthMm}mm').toList()}',
    );

    if (printers.isEmpty ||
        (printers.length == 1 && printers.first.ip.isEmpty)) {
      _printerLog('REPRINT >> ABORT: no usable printer profile');
      return false;
    }

    bool anyOk = false;
    for (final profile in printers) {
      _printerLog(
        'REPRINT >> profile=${profile.name} ip=${profile.ip}:${profile.port} paper=${profile.paperWidthMm}mm',
      );
      final cap = await CapabilityProfile.load();
      final printer = NetworkPrinter(profile.paperSize, cap);
      int step = 0;
      String currentStep = 'init';
      try {
        currentStep = 'connect';
        _printerLog('REPRINT >> [${++step}] connect…');
        final result = await printer
            .connect(profile.ip, port: profile.port)
            .timeout(_connectTimeout);
        _printerLog('REPRINT >> [${step}] connect result = $result');
        if (result != PosPrintResult.success) {
          _printerLog('REPRINT >> ABORT after connect (result != success)');
          continue;
        }

        final orderRef = receiptData['order_reference']?.toString() ?? '';
        final cashier = receiptData['cashier']?.toString() ?? '';
        final table = receiptData['table']?.toString() ?? '';
        final payment = receiptData['payment_method']?.toString() ?? '';
        final total = _asDouble(receiptData['amount_total']);
        final lines = receiptData['lines'] as List? ?? [];
        final rawCurrency = receiptData['currency']?.toString() ?? 'LAK';
        // ESC/POS-safe currency. Map common non-ASCII symbols to ASCII so the
        // Latin-1 encoder used by esc_pos_utils never throws.
        final currency = _safeCurrency(rawCurrency);
        final dateStr = receiptData['date_order']?.toString() ?? '';
        _printerLog(
          'REPRINT >> data: order=$orderRef cashier=$cashier table=$table '
          'payment=$payment currency(raw="$rawCurrency", safe="$currency") '
          'total=$total date=$dateStr lines=${lines.length}',
        );

        final head = (receiptData['header_text'] ?? '').toString().trim();
        currentStep = 'header';
        _printerLog(
          'REPRINT >> [${++step}] header (custom=${head.isNotEmpty})',
        );
        if (head.isNotEmpty) {
          for (final line in head.split('\n')) {
            final t = line.trimRight();
            if (t.isEmpty) continue;
            await _printUnicodeText(
              printer,
              t,
              styles: const PosStyles(align: PosAlign.center, bold: true),
              align: PosAlign.center,
              paperWidthMm: profile.paperWidthMm,
            );
          }
        } else {
          printer.text(
            'LaDolce',
            styles: const PosStyles(
              align: PosAlign.center,
              bold: true,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
            ),
          );
          await _printUnicodeText(
            printer,
            labels.pointOfSale,
            styles: const PosStyles(align: PosAlign.center),
            align: PosAlign.center,
            paperWidthMm: profile.paperWidthMm,
          );
        }
        currentStep = 'reprint label';
        _printerLog('REPRINT >> [${++step}] REPRINT label');
        await _printUnicodeText(
          printer,
          '** ${labels.reprint} **',
          styles: const PosStyles(align: PosAlign.center, bold: true),
          align: PosAlign.center,
          paperWidthMm: profile.paperWidthMm,
        );
        currentStep = 'hr#1';
        _printerLog('REPRINT >> [${++step}] hr (-)');
        printer.hr();
        currentStep = 'meta';
        _printerLog('REPRINT >> [${++step}] meta lines');
        if (queueNumber != null && queueNumber > 0) {
          printer.text(
            _fmtQueue(queueNumber),
            styles: const PosStyles(
              align: PosAlign.center,
              bold: true,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
            ),
          );
          printer.hr();
        }
        await _printUnicodeText(
          printer,
          '${labels.order}: $orderRef',
          paperWidthMm: profile.paperWidthMm,
        );
        if (dateStr.isNotEmpty) {
          await _printUnicodeText(
            printer,
            '${labels.date}: ${dateStr.substring(0, dateStr.length > 19 ? 19 : dateStr.length)}',
            paperWidthMm: profile.paperWidthMm,
          );
        }
        if (cashier.isNotEmpty) {
          await _printUnicodeText(
            printer,
            '${labels.cashier}: $cashier',
            paperWidthMm: profile.paperWidthMm,
          );
        }
        if (table.isNotEmpty) {
          await _printUnicodeText(
            printer,
            '${labels.table}: $table',
            paperWidthMm: profile.paperWidthMm,
          );
        }
        if (payment.isNotEmpty) {
          await _printUnicodeText(
            printer,
            '${labels.payment}: $payment',
            paperWidthMm: profile.paperWidthMm,
          );
        }
        currentStep = 'hr#2';
        _printerLog('REPRINT >> [${++step}] hr (-)');
        printer.hr();

        currentStep = 'items';
        _printerLog(
          'REPRINT >> [${++step}] items begin (count=${lines.length})',
        );
        int idx = 0;
        for (final line in lines) {
          idx++;
          try {
            final m = (line is Map)
                ? Map<String, dynamic>.from(line)
                : const <String, dynamic>{};
            final rawName = localizedLineName(m);
            final qty = _asInt(m['qty'], fallback: 1);
            final subtotal = _asDouble(m['subtotal']);

            final nameMax = profile.paperWidthMm == 58 ? 22 : 34;
            final left = _trimToFit('${qty}x $rawName', nameMax);
            final right = _sanitizeForEscPos(
              '$currency ${subtotal.toStringAsFixed(2)}',
            );
            _printerLog(
              'REPRINT >> item[$idx] qtyType=${m['qty']?.runtimeType} '
              'subType=${m['subtotal']?.runtimeType} '
              'left="$left" right="$right" rawName="$rawName"',
            );

            await _printItemLine(
              printer,
              name: left,
              price: right,
              paperWidthMm: profile.paperWidthMm,
            );
          } catch (e, st) {
            _printerLog('REPRINT >> item[$idx] ERROR: $e\n$st');
            try {
              printer.text(
                _sanitizeForEscPos('1x Item'),
                styles: const PosStyles(bold: true),
              );
            } catch (_) {}
          }
        }
        _printerLog('REPRINT >> items done');

        currentStep = 'discount';
        final discountAmt = _asDouble(receiptData['amount_discount']);
        if (discountAmt > 0) {
          _printerLog('REPRINT >> [${++step}] discount line');
          await _printAmountRow(
            printer,
            label: '${labels.discount}:',
            value: '-$currency ${discountAmt.toStringAsFixed(2)}',
            paperWidthMm: profile.paperWidthMm,
            bold: true,
          );
        }

        currentStep = 'hr#3 (=)';
        _printerLog('REPRINT >> [${++step}] hr (=)');
        printer.hr(ch: '=');
        currentStep = 'TOTAL row';
        final totalText = _sanitizeForEscPos(
          '$currency ${total.toStringAsFixed(2)}',
        );
        _printerLog('REPRINT >> [${++step}] TOTAL row text="$totalText"');
        await _printAmountRow(
          printer,
          label: '${labels.total}:',
          value: totalText,
          paperWidthMm: profile.paperWidthMm,
          bold: true,
        );
        currentStep = 'feed1';
        _printerLog('REPRINT >> [${++step}] feed(1) + thanks');
        printer.feed(1);
        await _printUnicodeText(
          printer,
          labels.thankYou,
          styles: const PosStyles(align: PosAlign.center, bold: true),
          align: PosAlign.center,
          paperWidthMm: profile.paperWidthMm,
        );
        await _printUnicodeText(
          printer,
          labels.pleaseComeAgain,
          styles: const PosStyles(align: PosAlign.center),
          align: PosAlign.center,
          paperWidthMm: profile.paperWidthMm,
        );
        final foot = (receiptData['footer_text'] ?? '').toString().trim();
        if (foot.isNotEmpty) {
          currentStep = 'footer';
          _printerLog(
            'REPRINT >> [${++step}] footer (${foot.split('\n').length} lines)',
          );
          printer.feed(1);
          for (final line in foot.split('\n')) {
            final t = line.trimRight();
            if (t.isEmpty) continue;
            await _printUnicodeText(
              printer,
              t,
              styles: const PosStyles(align: PosAlign.center),
              align: PosAlign.center,
              paperWidthMm: profile.paperWidthMm,
            );
          }
        }
        currentStep = 'feed3 + cut';
        _printerLog('REPRINT >> [${++step}] feed(3) + cut');
        printer.feed(3);
        printer.cut();
        currentStep = 'flush wait';
        _printerLog('REPRINT >> [${++step}] sleeping 800ms before disconnect…');
        await Future.delayed(const Duration(milliseconds: 800));
        anyOk = true;
        _printerLog('REPRINT >> COMPLETED OK on ${profile.name}');
      } catch (e, st) {
        _printerLog(
          'REPRINT >> EXCEPTION at step=$currentStep on ${profile.name}: $e\n$st',
        );
      } finally {
        try {
          printer.disconnect();
          _printerLog('REPRINT >> disconnect done');
        } catch (e) {
          _printerLog('REPRINT >> disconnect error: $e');
        }
      }
    }
    _printerLog('REPRINT >> END (anyOk=$anyOk)');
    return anyOk;
  }

  /// Print a refund slip using raw order receipt data.
  ///
  /// This is designed for the "Refund Order" flow so the printer always receives
  /// a clean cut+disconnect even if the print fails mid-way.
  Future<bool> printRefundFromRawData(
    Map<String, dynamic> receiptData, {
    String? headerText,
    String? footerText,
    int? queueNumber,
  }) async {
    _printerLog('REFUND >> START');
    _printerLog('REFUND >> raw keys = ${receiptData.keys.toList()}');
    await initialize();
    if (!isConfigured) {
      _printerLog('REFUND >> ABORT: printer not configured');
      return false;
    }

    final printers = _profiles.isNotEmpty
        ? _profiles.where((p) => p.printReceiptsAndBills).toList()
        : [
            PrinterProfile(
              id: 'legacy',
              name: 'Printer',
              ip: _printerIp ?? '',
              port: _printerPort,
              paperWidthMm: _paperSize == PaperSize.mm58 ? 58 : 80,
              printReceiptsAndBills: true,
            ),
          ];
    _printerLog(
      'REFUND >> candidate printers = ${printers.length} '
      '${printers.map((p) => '${p.name}@${p.ip}:${p.port}/${p.paperWidthMm}mm').toList()}',
    );

    if (printers.isEmpty ||
        (printers.length == 1 && printers.first.ip.isEmpty)) {
      _printerLog('REFUND >> ABORT: no usable printer profile');
      return false;
    }

    bool anyOk = false;
    for (final profile in printers) {
      _printerLog(
        'REFUND >> profile=${profile.name} ip=${profile.ip}:${profile.port} paper=${profile.paperWidthMm}mm',
      );
      final cap = await CapabilityProfile.load();
      final printer = NetworkPrinter(profile.paperSize, cap);
      int step = 0;
      String currentStep = 'init';
      try {
        currentStep = 'connect';
        _printerLog('REFUND >> [${++step}] connect…');
        final result = await printer
            .connect(profile.ip, port: profile.port)
            .timeout(_connectTimeout);
        _printerLog('REFUND >> [$step] connect result = $result');
        if (result != PosPrintResult.success) {
          _printerLog('REFUND >> ABORT after connect (result != success)');
          continue;
        }

        final orderRef = receiptData['order_reference']?.toString() ?? '';
        final cashier = receiptData['cashier']?.toString() ?? '';
        final payment = receiptData['payment_method']?.toString() ?? '';
        final total = _asDouble(receiptData['amount_total']);
        final rawCurrency = receiptData['currency']?.toString() ?? 'LAK';
        final currency = _safeCurrency(rawCurrency);
        final lines = receiptData['lines'] as List? ?? [];
        _printerLog(
          'REFUND >> data: order=$orderRef cashier=$cashier payment=$payment '
          'currency(raw="$rawCurrency", safe="$currency") '
          'total=$total lines=${lines.length}',
        );

        final head = (headerText ?? receiptData['header_text'] ?? '')
            .toString()
            .trim();
        currentStep = 'header';
        _printerLog('REFUND >> [${++step}] header (custom=${head.isNotEmpty})');
        if (head.isNotEmpty) {
          for (final line in head.split('\n')) {
            final t = line.trimRight();
            if (t.isEmpty) continue;
            printer.text(
              _sanitizeForEscPos(t),
              styles: const PosStyles(align: PosAlign.center, bold: true),
            );
          }
        } else {
          printer.text(
            'LaDolce',
            styles: const PosStyles(
              align: PosAlign.center,
              bold: true,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
            ),
          );
          printer.text(
            'Point of Sale',
            styles: const PosStyles(align: PosAlign.center),
          );
        }

        currentStep = 'refund label';
        _printerLog('REFUND >> [${++step}] REFUND label');
        printer.text(
          '** REFUND **',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );
        currentStep = 'hr#1';
        _printerLog('REFUND >> [${++step}] hr (-)');
        printer.hr();
        currentStep = 'meta';
        _printerLog('REFUND >> [${++step}] meta lines');
        if (queueNumber != null && queueNumber > 0) {
          printer.text(
            _fmtQueue(queueNumber),
            styles: const PosStyles(
              align: PosAlign.center,
              bold: true,
              height: PosTextSize.size2,
              width: PosTextSize.size2,
            ),
          );
          printer.hr();
        }
        if (orderRef.isNotEmpty)
          printer.text('Order: ${_sanitizeForEscPos(orderRef)}');
        printer.text(
          'Refund Date: ${DateTime.now().toString().substring(0, 19)}',
        );
        if (cashier.isNotEmpty)
          printer.text('Cashier: ${_sanitizeForEscPos(cashier)}');
        if (payment.isNotEmpty)
          printer.text('Payment: ${_sanitizeForEscPos(payment)}');
        currentStep = 'hr#2';
        _printerLog('REFUND >> [${++step}] hr (-)');
        printer.hr();

        currentStep = 'items';
        _printerLog(
          'REFUND >> [${++step}] items begin (count=${lines.length})',
        );
        int idx = 0;
        for (final line in lines) {
          idx++;
          try {
            final m = (line is Map)
                ? Map<String, dynamic>.from(line)
                : const <String, dynamic>{};
            final rawName = m['product_name']?.toString() ?? 'Item';
            final qty = _asInt(m['qty'], fallback: 1);
            final subtotal = _asDouble(m['subtotal']);

            final nameMax = profile.paperWidthMm == 58 ? 22 : 34;
            final left = _trimToFit(
              _sanitizeForEscPos('${qty}x $rawName'),
              nameMax,
            );
            final right = _sanitizeForEscPos(
              '$currency ${subtotal.toStringAsFixed(2)}',
            );
            _printerLog(
              'REFUND >> item[$idx] qtyType=${m['qty']?.runtimeType} '
              'subType=${m['subtotal']?.runtimeType} '
              'left="$left" right="$right" rawName="$rawName"',
            );

            printer.row([
              PosColumn(
                text: left,
                width: 8,
                styles: const PosStyles(bold: true),
              ),
              PosColumn(
                text: right,
                width: 4,
                styles: const PosStyles(align: PosAlign.right),
              ),
            ]);
          } catch (e, st) {
            _printerLog('REFUND >> item[$idx] ERROR: $e\n$st');
            try {
              printer.text(
                _sanitizeForEscPos('1x Item'),
                styles: const PosStyles(bold: true),
              );
            } catch (_) {}
          }
        }
        _printerLog('REFUND >> items done');

        currentStep = 'hr#3 (=)';
        _printerLog('REFUND >> [${++step}] hr (=)');
        printer.hr(ch: '=');
        currentStep = 'REFUND AMOUNT row';
        final totalText = _sanitizeForEscPos(
          '$currency ${total.toStringAsFixed(2)}',
        );
        _printerLog(
          'REFUND >> [${++step}] REFUND AMOUNT row text="$totalText"',
        );
        printer.row([
          PosColumn(
            text: 'REFUND AMOUNT:',
            width: 8,
            styles: const PosStyles(bold: true),
          ),
          PosColumn(
            text: totalText,
            width: 4,
            styles: const PosStyles(align: PosAlign.right, bold: true),
          ),
        ]);
        currentStep = 'feed1 + processed';
        _printerLog('REFUND >> [${++step}] feed(1) + Refund Processed');
        printer.feed(1);
        printer.text(
          'Refund Processed',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );

        final foot = (footerText ?? receiptData['footer_text'] ?? '')
            .toString()
            .trim();
        if (foot.isNotEmpty) {
          currentStep = 'footer';
          _printerLog(
            'REFUND >> [${++step}] footer (${foot.split('\n').length} lines)',
          );
          printer.feed(1);
          for (final line in foot.split('\n')) {
            final t = line.trimRight();
            if (t.isEmpty) continue;
            printer.text(
              _sanitizeForEscPos(t),
              styles: const PosStyles(align: PosAlign.center),
            );
          }
        }
        currentStep = 'feed3 + cut';
        _printerLog('REFUND >> [${++step}] feed(3) + cut');
        printer.feed(3);
        printer.cut();
        currentStep = 'flush wait';
        _printerLog('REFUND >> [${++step}] sleeping 800ms before disconnect…');
        await Future.delayed(const Duration(milliseconds: 800));
        anyOk = true;
        _printerLog('REFUND >> COMPLETED OK on ${profile.name}');
      } catch (e, st) {
        _printerLog(
          'REFUND >> EXCEPTION at step=$currentStep on ${profile.name}: $e\n$st',
        );
      } finally {
        try {
          printer.disconnect();
          _printerLog('REFUND >> disconnect done');
        } catch (e) {
          _printerLog('REFUND >> disconnect error: $e');
        }
      }
    }
    _printerLog('REFUND >> END (anyOk=$anyOk)');
    return anyOk;
  }
}

// Singleton instance
final printerService = PrinterService();
