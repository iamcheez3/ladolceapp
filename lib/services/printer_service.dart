import 'dart:async';
import '../utils/bilingual_name.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'dart:ui' show TextAlign;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'escpos_text_image.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';
import '../utils/money.dart';

void _printerLog(String message) {
  developer.log(message, name: 'PrinterService');
  // Mirror to stdout so it shows in `flutter run` console output too.
  // ignore: avoid_print
  print('[PrinterService] $message');
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

  PaperSize get paperSize => paperWidthMm == 58 ? PaperSize.mm58 : PaperSize.mm80;

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
          ? (json['categoryFilters'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
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
      printReceiptsAndBills: printReceiptsAndBills ?? this.printReceiptsAndBills,
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

  /// Dot width of the print head for this paper size, matching the values
  /// esc_pos_utils uses internally for its column maths.
  int _dotsFor(PrinterProfile profile) =>
      profile.paperWidthMm == 58 ? 372 : 558;

  /// Raster size for the shop name and queue number: about the height of the
  /// printer's double-size text they replaced.
  static const double _bigFontSize = 48;

  static img.Image? _bundledLogo;

  /// Company logo at the top of receipts and bills: the bill template's logo
  /// (Odoo, base64) when one is uploaded, else the app's black-on-white bear.
  /// Flattened onto white so a transparent PNG does not print as a black block.
  Future<void> _emitLogo(
    NetworkPrinter printer, {
    required int dots,
    String? logoBase64,
  }) async {
    try {
      img.Image? logo;
      final raw = (logoBase64 ?? '').trim();
      if (raw.isNotEmpty) {
        final comma = raw.indexOf(',');
        final b64 = raw.startsWith('data:') && comma > 0 ? raw.substring(comma + 1) : raw;
        logo = img.decodeImage(base64Decode(b64));
        // The backend's default templates ship a 68-byte placeholder pixel;
        // scaled up it prints as a blank/black square, so use the bear.
        if (logo != null && (logo.width < 32 || logo.height < 32)) logo = null;
      }
      if (logo == null) {
        if (_bundledLogo == null) {
          final data = await rootBundle.load('assets/images/receipt_logo.png');
          _bundledLogo = img.decodePng(Uint8List.view(data.buffer));
        }
        logo = _bundledLogo;
      }
      if (logo == null) return;
      final width = (dots * 0.4).round().clamp(120, 260);
      final resized = img.copyResize(logo, width: width);
      final flat = img.Image(resized.width, resized.height);
      img.fill(flat, img.getColor(255, 255, 255));
      img.drawImage(flat, resized);
      printer.imageRaster(img.grayscale(flat), align: PosAlign.center);
      printer.feed(1);
    } catch (e) {
      _printerLog('[PRINTER] logo skipped: $e');
    }
  }

  /// Prints one line, rasterising it when it contains characters ESC/POS cannot
  /// encode. `esc_pos_utils` pushes text through `latin1.encode`, which throws a
  /// FormatException above U+00FF, so one Lao product name used to abort the
  /// entire receipt. Printers have no Lao glyphs either, so a bitmap is the only
  /// way the text actually appears. ASCII keeps the fast native-text path.
  ///
  /// [inPrintFont] rasterises ASCII too, so the whole ticket shares the print
  /// font (order tickets and receipts); [fontSize] overrides the raster size.
  Future<void> _emitLine(
    NetworkPrinter printer,
    String text, {
    required int dots,
    bool bold = false,
    bool large = false,
    PosAlign align = PosAlign.left,
    bool inPrintFont = false,
    double? fontSize,
  }) async {
    final line = text.trimRight();
    if (line.isEmpty) return;
    if (!inPrintFont && !escPosNeedsImage(line)) {
      printer.text(
        line,
        styles: PosStyles(
          align: align,
          bold: bold,
          height: large ? PosTextSize.size2 : PosTextSize.size1,
          width: large ? PosTextSize.size2 : PosTextSize.size1,
        ),
      );
      return;
    }
    try {
      final image = await renderEscPosLine(
        text: line,
        widthDots: dots,
        bold: bold,
        fontSize: fontSize ?? (large ? 40 : 26),
        align: align == PosAlign.center
            ? TextAlign.center
            : align == PosAlign.right
            ? TextAlign.right
            : TextAlign.left,
      );
      if (image != null) {
        printer.imageRaster(image, align: align);
        return;
      }
    } catch (e) {
      _printerLog('[PRINTER] raster line failed, falling back to ASCII: $e');
    }
    // Last resort: never let an unprintable glyph abort the job.
    printer.text(
      _sanitizeForEscPos(line),
      styles: PosStyles(align: align, bold: bold),
    );
  }

  /// Two-column "label .... value" row with the same rasterising fallback.
  Future<void> _emitRow(
    NetworkPrinter printer,
    String left,
    String right, {
    required int dots,
    bool bold = false,
    bool large = false,
    bool inPrintFont = false,
  }) async {
    if (!inPrintFont && !escPosNeedsImage(left) && !escPosNeedsImage(right)) {
      final h = large ? PosTextSize.size2 : PosTextSize.size1;
      printer.row([
        PosColumn(
          text: left,
          width: 8,
          styles: PosStyles(bold: bold, height: h),
        ),
        PosColumn(
          text: right,
          width: 4,
          styles: PosStyles(align: PosAlign.right, bold: bold, height: h),
        ),
      ]);
      return;
    }
    try {
      final image = await renderEscPosRow(
        left: left,
        right: right,
        widthDots: dots,
        bold: bold,
        fontSize: large ? 40 : 26,
      );
      if (image != null) {
        printer.imageRaster(image);
        return;
      }
    } catch (e) {
      _printerLog('[PRINTER] raster row failed, falling back to ASCII: $e');
    }
    printer.row([
      PosColumn(
        text: _sanitizeForEscPos(left),
        width: 8,
        styles: PosStyles(bold: bold),
      ),
      PosColumn(
        text: _sanitizeForEscPos(right),
        width: 4,
        styles: PosStyles(align: PosAlign.right, bold: bold),
      ),
    ]);
  }

  String _trimToFit(String s, int maxChars) {
    if (maxChars <= 0) return '';
    if (s.length <= maxChars) return s;
    if (maxChars <= 1) return s.substring(0, maxChars);
    // Use ASCII-only truncation marker; many ESC/POS printers can't encode `…`.
    if (maxChars <= 3) return s.substring(0, maxChars);
    return '${s.substring(0, maxChars - 3)}...';
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
    await prefs.setString(_printersKey, jsonEncode(_profiles.map((p) => p.toJson()).toList()));
    if (_receiptPrinterId == null || _receiptPrinterId!.isEmpty) {
      await prefs.remove(_receiptPrinterIdKey);
    } else {
      await prefs.setString(_receiptPrinterIdKey, _receiptPrinterId!);
    }
  }

  PrinterProfile? _getReceiptPrinter() {
    if (_profiles.isEmpty) return null;
    if (_receiptPrinterId != null) {
      final selected = _profiles.where((p) => p.id == _receiptPrinterId).firstOrNull;
      if (selected != null) return selected;
    }
    final enabled = _profiles.where((p) => p.printReceiptsAndBills).toList();
    return enabled.isNotEmpty ? enabled.first : _profiles.first;
  }

  void configure({required String ip, int port = 9100, PaperSize paperSize = PaperSize.mm80}) {
    _printerIp = ip;
    _printerPort = port;
    _paperSize = paperSize;
  }

  bool get isConfigured => _profiles.isNotEmpty || (_printerIp != null && _printerIp!.isNotEmpty);

  Future<void> savePrinter(PrinterProfile profile, {bool setAsReceiptPrinter = false}) async {
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
      final printer = NetworkPrinter(profile.paperSize, await CapabilityProfile.load());
      final dots = _dotsFor(profile);
      final result = await printer
          .connect(profile.ip, port: profile.port)
          .timeout(_connectTimeout);
      if (result != PosPrintResult.success) return false;
      try {
        printer.text('=== LaDolce POS ===', styles: const PosStyles(align: PosAlign.center, bold: true));
        await _emitLine(
        printer,
        'Printer: ${profile.name}',
        dots: dots,
        align: PosAlign.center,
      );
        printer.text('Test page OK', styles: const PosStyles(align: PosAlign.center));
        printer.feed(3);
        printer.cut();
      } finally {
        try { printer.disconnect(); } catch (_) {}
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
      final printer = NetworkPrinter(_paperSize, await CapabilityProfile.load());
      final result = await printer
          .connect(_printerIp!, port: _printerPort)
          .timeout(_connectTimeout);
      
      if (result == PosPrintResult.success) {
        try {
          printer.text('=== LaDolce POS ===', styles: const PosStyles(align: PosAlign.center, bold: true));
          printer.text('Printer Test OK!', styles: const PosStyles(align: PosAlign.center));
          printer.feed(3);
          printer.cut();
        } finally {
          try { printer.disconnect(); } catch (_) {}
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
        final receiptPrinters = _profiles.where((p) => p.printReceiptsAndBills).toList();
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

   List<CartItem> _filterItemsForPrinter(List<CartItem> items, PrinterProfile printer) {
    if (printer.categoryFilters.isEmpty) return items;
    final filters = printer.categoryFilters.map((e) => e.trim().toLowerCase()).toSet();
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
    String? logoBase64,
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
            )
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
        logoBase64: logoBase64,
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
  String? logoBase64,
}) async {
  final cap = await CapabilityProfile.load();
  final printer = NetworkPrinter(profile.paperSize, cap);
  try {
    final result = await printer
        .connect(profile.ip, port: profile.port)
        .timeout(_connectTimeout);
    if (result != PosPrintResult.success) return false;

    final dots = _dotsFor(profile);
    // Every line in the print font, like the receipt. English names used to go
    // out in the printer's own font and Lao names as an image, so "1x Butter
    // croissant" and "1x <Lao name>" did not line up.
    Future<void> printLine(String t, {bool bold = false, double? size, PosAlign align = PosAlign.left}) =>
        _emitLine(printer, t, dots: dots, bold: bold, fontSize: size, align: align, inPrintFont: true);
    Future<void> printRow(String l, String r, {bool bold = false, bool large = false}) =>
        _emitRow(printer, l, r, dots: dots, bold: bold, large: large, inPrintFont: true);

    await _emitLogo(printer, dots: dots, logoBase64: logoBase64);
    final head = (headerText ?? '').trim();
    if (head.isNotEmpty) {
      for (final line in head.split('\n')) {
        final t = line.trimRight();
        if (t.isEmpty) continue;
        await printLine(t, bold: true, align: PosAlign.center);
      }
    } else {
      await printLine('LaDolce', bold: true, size: _bigFontSize, align: PosAlign.center);
    }
    if (ticketName != null && ticketName.isNotEmpty) {
      await printLine(ticketName, bold: true, align: PosAlign.center);
    }
    printer.hr();
    if (queueNumber != null && queueNumber > 0) {
      await printLine(_fmtQueue(queueNumber), bold: true, size: _bigFontSize, align: PosAlign.center);
      printer.hr();
    }
    await printLine('Date: ${DateTime.now().toString().substring(0, 19)}');
    await printLine('Cashier: $cashierName');
    printer.hr();

    for (final line in mergeSamePrintLines(cartItems)) {
      final item = line.item;
      await printRow(
        '${line.quantity}x ${item.product.displayName}',
        item.isFreePromo ? 'FREE' : 'LAK ${money(line.totalPrice)}',
        bold: true,
      );
      for (final topping in item.selectedToppings) {
        await printRow(
          '  + ${topping.displayName}',
          !item.isFreePromo && topping.extraPrice > 0
              ? 'LAK ${money(topping.extraPrice)}'
              : '',
        );
      }
    }

    printer.hr();
    if (discountAmount > 0) {
      await printRow('Discount', '-LAK ${money(discountAmount)}', bold: true);
    }
    final showTax = taxRowLabel != null && taxRowLabel.isNotEmpty && tax.abs() >= 0.005;
    if (showTax) {
      await printRow(subtotalRowLabel, 'LAK ${money(subtotal)}');
      await printRow(taxRowLabel, 'LAK ${money(tax)}');
      printer.hr(ch: '=');
    }
    await printRow('TOTAL:', 'LAK ${money(total)}', bold: true, large: true);
    printer.feed(1);
    await printLine('** NOT A RECEIPT **', bold: true, align: PosAlign.center);
    await printLine('Please wait for your receipt', align: PosAlign.center);
    final foot = (footerText ?? '').trim();
    if (foot.isNotEmpty) {
      printer.feed(1);
      for (final line in foot.split('\n')) {
        final t = line.trimRight();
        if (t.isEmpty) continue;
        await printLine(t, align: PosAlign.center);
      }
    }
    printer.feed(3);
    printer.cut();
    return true;
  } catch (e) {
    _printerLog('[PRINTER] Print bill failed: $e');
    return false;
  } finally {
    try { printer.disconnect(); } catch (_) {}
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
    String? logoBase64,
    String? customerName,
    int? pointsEarned,
    int? pointsBalance,
    String pointsLabel = 'Points',
    List<Map<String, dynamic>> payments = const [],
    double change = 0,
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
        logoBase64: logoBase64,
        customerName: customerName,
        pointsEarned: pointsEarned,
        pointsBalance: pointsBalance,
        pointsLabel: pointsLabel,
        payments: payments,
        change: change,
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
    String? logoBase64,
    String? customerName,
    int? pointsEarned,
    int? pointsBalance,
    String pointsLabel = 'Points',
    List<Map<String, dynamic>> payments = const [],
    double change = 0,
  }) async {
    final cap = await CapabilityProfile.load();
    final printer = NetworkPrinter(profile.paperSize, cap);
    try {
      final result = await printer
          .connect(profile.ip, port: profile.port)
          .timeout(_connectTimeout);
      if (result != PosPrintResult.success) return false;

      final dots = _dotsFor(profile);
      // Every line in the print font, including the English and the prices.
      Future<void> printLine(String t, {bool bold = false, double? size, PosAlign align = PosAlign.left}) =>
          _emitLine(printer, t, dots: dots, bold: bold, fontSize: size, align: align, inPrintFont: true);
      Future<void> printRow(String l, String r, {bool bold = false, bool large = false}) =>
          _emitRow(printer, l, r, dots: dots, bold: bold, large: large, inPrintFont: true);

      await _emitLogo(printer, dots: dots, logoBase64: logoBase64);
      final head = (headerText ?? '').trim();
      if (head.isNotEmpty) {
        for (final line in head.split('\n')) {
          final t = line.trimRight();
          if (t.isEmpty) continue;
          await printLine(t, bold: true, align: PosAlign.center);
        }
      } else {
        await printLine('LaDolce', bold: true, size: _bigFontSize, align: PosAlign.center);
      }
      printer.hr();
      if (queueNumber != null && queueNumber > 0) {
        await printLine(_fmtQueue(queueNumber), bold: true, size: _bigFontSize, align: PosAlign.center);
        printer.hr();
      }
      await printLine('Date: ${DateTime.now().toString().substring(0, 19)}');
      await printLine('Cashier: $cashierName');
      printer.hr();
      for (final line in mergeSamePrintLines(cartItems)) {
        final item = line.item;
        await printRow(
          '${line.quantity}x ${item.product.displayName}',
          item.isFreePromo ? 'FREE' : 'LAK ${money(line.totalPrice)}',
          bold: true,
        );
        // Choices such as "Size L" explain the line price.
        for (final topping in item.selectedToppings) {
          await printLine('  + ${topping.displayName}');
        }
      }
      printer.hr();
      if (discountAmount > 0) {
        await printRow('Discount', '-LAK ${money(discountAmount)}', bold: true);
      }
      final showTax = taxRowLabel != null && taxRowLabel.isNotEmpty && tax.abs() >= 0.005;
      if (showTax) {
        await printRow(subtotalRowLabel, 'LAK ${money(subtotal)}');
        await printRow(taxRowLabel, 'LAK ${money(tax)}');
        printer.hr(ch: '=');
      }
      await printRow('TOTAL:', 'LAK ${money(total)}', bold: true, large: true);
      // How it was paid: one line per method (split payment), then change.
      for (final pay in payments) {
        final amount = (pay['amount'] as num?)?.toDouble() ?? 0;
        await printRow((pay['payment_method'] ?? '').toString(), 'LAK ${money(amount)}');
      }
      if (change > 0) {
        await printRow('Change', 'LAK ${money(change)}');
      }
      // Loyalty: what this purchase earned (only when a customer is on it).
      final customer = (customerName ?? '').trim();
      if (customer.isNotEmpty || pointsEarned != null) {
        printer.hr();
        if (customer.isNotEmpty) await printLine('Customer: $customer');
        if (pointsEarned != null) {
          await printRow('$pointsLabel earned', '+$pointsEarned', bold: true);
          if (pointsBalance != null) {
            await printRow('Total $pointsLabel', '$pointsBalance');
          }
        }
      }
      printer.feed(1);
      // The template footer (Odoo bill template) replaces the built-in
      // English thank-you instead of printing both.
      final foot = (footerText ?? '').trim();
      if (foot.isNotEmpty) {
        for (final line in foot.split('\n')) {
          final t = line.trimRight();
          if (t.isEmpty) continue;
          await printLine(t, align: PosAlign.center);
        }
      } else {
        await printLine('Thank you!', bold: true, align: PosAlign.center);
        await printLine('Please come again', align: PosAlign.center);
      }
      printer.feed(3);
      printer.cut();
      return true;
    } catch (e) {
      _printerLog('[PRINTER] Print receipt failed: $e');
      return false;
    } finally {
      try { printer.disconnect(); } catch (_) {}
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
    final cap = await CapabilityProfile.load();
    final printer = NetworkPrinter(profile.paperSize, cap);
    final dots = _dotsFor(profile);
    try {
      final result = await printer
          .connect(profile.ip, port: profile.port)
          .timeout(_connectTimeout);
      if (result != PosPrintResult.success) return false;

      // Every line in the print font, including the English and the date.
      Future<void> printLine(String t, {bool bold = false, bool large = false, double? size, PosAlign align = PosAlign.left}) =>
          _emitLine(printer, t, dots: dots, bold: bold, large: large, fontSize: size, align: align, inPrintFont: true);

      final head = (headerText ?? '').trim();
      if (head.isNotEmpty) {
        for (final line in head.split('\n')) {
          final t = line.trimRight();
          if (t.isEmpty) continue;
          await printLine(t, bold: true, large: true, align: PosAlign.center);
        }
      } else {
        await printLine('Order Ticket', bold: true, large: true, align: PosAlign.center);
      }
      printer.hr();
      if (queueNumber != null && queueNumber > 0) {
        await printLine(_fmtQueue(queueNumber), bold: true, size: _bigFontSize, align: PosAlign.center);
        printer.hr();
      }
      await printLine('Date: ${DateTime.now().toString().substring(0, 19)}');
      await printLine('Cashier: $cashierName');
      printer.hr();

      if (profile.singleItemPerTicket) {
        for (final i in items) {
          for (int q = 0; q < i.quantity; q++) {
            await printLine('1x ${i.product.displayName}${i.isFreePromo ? ' (FREE)' : ''}', bold: true, large: true);
            // Same size as the item line, so the kitchen can read the choices.
            for (final topping in i.selectedToppings) {
              await printLine('  + ${topping.displayName}', large: true);
            }
            final note = i.kitchenNote.trim();
            if (note.isNotEmpty) {
              await printLine('  NOTE: $note', bold: true);
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
          final toppingNames = i.selectedToppings.map((t) => t.displayName).toList();
          final note = i.kitchenNote.trim();
          // Key on the canonical English name so switching language never
          // changes how lines group; only the printed label follows the locale.
          final key = [
            i.product.name,
            i.isFreePromo ? 'free' : '',
            i.selectedToppings.map((t) => t.name).join('|'),
            note,
          ].join('__');
          final row = map.putIfAbsent(
            key,
            () => {
              'name': '${i.product.displayName}${i.isFreePromo ? ' (FREE)' : ''}',
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
            'name': '${i.product.displayName}${i.isFreePromo ? ' (FREE)' : ''}',
            'qty': i.quantity,
            'toppings': i.selectedToppings.map((t) => t.displayName).toList(),
            'note': i.kitchenNote.trim(),
          });
        }
      }

      for (final r in rows) {
        await printLine('${r['qty']}x ${r['name']}', bold: true, large: true);
        final toppings = (r['toppings'] as List?) ?? const [];
        // Same size as the item line, so the kitchen can read the choices.
        for (final topping in toppings) {
          await printLine('  + $topping', large: true);
        }
        final note = (r['note'] ?? '').toString().trim();
        if (note.isNotEmpty) {
          // Notes are typed in Lao, which printer.text cannot encode: it threw
          // mid-job, so the kitchen got a cut-off ticket and the save reported
          // a print failure. Rasterised like the item names.
          await printLine('  NOTE: $note', bold: true);
        }
        printer.feed(1);
      }
      final foot = (footerText ?? '').trim();
      if (foot.isNotEmpty) {
        printer.feed(1);
        for (final line in foot.split('\n')) {
          final t = line.trimRight();
          if (t.isEmpty) continue;
          await printLine(t, align: PosAlign.center);
        }
      }
      printer.feed(2);
      printer.cut();
      return true;
    } catch (e) {
      _printerLog('[PRINTER] Print order ticket failed: $e');
      return false;
    } finally {
      try { printer.disconnect(); } catch (_) {}
    }
  }
  Future<bool> openCashDrawer() async {
  await initialize();
  final p = _getReceiptPrinter();
  if (p == null && !isConfigured) return false;

  final profile = p ?? PrinterProfile(
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
      // NetworkPrinter.disconnect() destroys the socket at once and drops
      // anything not yet sent: the pulse was lost and the drawer never opened.
      await Future.delayed(const Duration(milliseconds: 600));
    } finally {
      try { printer.disconnect(); } catch (_) {}
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
  Future<bool> printReceiptFromRawData(Map<String, dynamic> receiptData, {int? queueNumber}) async {
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
            )
          ];
    _printerLog('REPRINT >> candidate printers = ${printers.length} '
        '${printers.map((p) => '${p.name}@${p.ip}:${p.port}/${p.paperWidthMm}mm').toList()}');

    if (printers.isEmpty || (printers.length == 1 && printers.first.ip.isEmpty)) {
      _printerLog('REPRINT >> ABORT: no usable printer profile');
      return false;
    }

    bool anyOk = false;
    for (final profile in printers) {
      _printerLog('REPRINT >> profile=${profile.name} ip=${profile.ip}:${profile.port} paper=${profile.paperWidthMm}mm');
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

        final orderRef  = receiptData['order_reference']?.toString() ?? '';
        final cashier   = receiptData['cashier']?.toString() ?? '';
        final table     = receiptData['table']?.toString() ?? '';
        final payment   = receiptData['payment_method']?.toString() ?? '';
        final total     = _asDouble(receiptData['amount_total']);
        final lines     = receiptData['lines'] as List? ?? [];
        final rawCurrency = receiptData['currency']?.toString() ?? 'LAK';
        // ESC/POS-safe currency. Map common non-ASCII symbols to ASCII so the
        // Latin-1 encoder used by esc_pos_utils never throws.
        final currency = _safeCurrency(rawCurrency);
        final dateStr   = receiptData['date_order']?.toString() ?? '';
        _printerLog('REPRINT >> data: order=$orderRef cashier=$cashier table=$table '
            'payment=$payment currency(raw="$rawCurrency", safe="$currency") '
            'total=$total date=$dateStr lines=${lines.length}');

        currentStep = 'logo';
        await _emitLogo(printer, dots: _dotsFor(profile), logoBase64: receiptData['logo']?.toString());
        final head = (receiptData['header_text'] ?? '').toString().trim();
        currentStep = 'header';
        _printerLog('REPRINT >> [${++step}] header (custom=${head.isNotEmpty})');
        if (head.isNotEmpty) {
          for (final line in head.split('\n')) {
            final t = line.trimRight();
            if (t.isEmpty) continue;
            printer.text(_sanitizeForEscPos(t), styles: const PosStyles(align: PosAlign.center, bold: true));
          }
        } else {
          printer.text('LaDolce', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
        }
        currentStep = 'reprint label';
        _printerLog('REPRINT >> [${++step}] REPRINT label');
        printer.text('** REPRINT **', styles: const PosStyles(align: PosAlign.center, bold: true));
        currentStep = 'hr#1';
        _printerLog('REPRINT >> [${++step}] hr (-)');
        printer.hr();
        currentStep = 'meta';
        _printerLog('REPRINT >> [${++step}] meta lines');
        if (queueNumber != null && queueNumber > 0) {
          printer.text(_fmtQueue(queueNumber), styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
          printer.hr();
        }
        printer.text('Order: ${_sanitizeForEscPos(orderRef)}');
        if (dateStr.isNotEmpty) {
          printer.text('Date: ${_sanitizeForEscPos(dateStr.substring(0, dateStr.length > 19 ? 19 : dateStr.length))}');
        }
        if (cashier.isNotEmpty) printer.text('Cashier: ${_sanitizeForEscPos(cashier)}');
        if (table.isNotEmpty)   printer.text('Table: ${_sanitizeForEscPos(table)}');
        if (payment.isNotEmpty) printer.text('Payment: ${_sanitizeForEscPos(payment)}');
        currentStep = 'hr#2';
        _printerLog('REPRINT >> [${++step}] hr (-)');
        printer.hr();

        currentStep = 'items';
        _printerLog('REPRINT >> [${++step}] items begin (count=${lines.length})');
        int idx = 0;
        for (final line in lines) {
          idx++;
          try {
            final m = (line is Map) ? Map<String, dynamic>.from(line) : const <String, dynamic>{};
            // Printed in whatever language the POS is set to; the backend
            // ships both spellings on every line.
            final rawName = bilingualName(m, fallback: 'Item');
            final qty = _asInt(m['qty'], fallback: 1);
            final subtotal = _asDouble(m['subtotal']);

            final nameMax = profile.paperWidthMm == 58 ? 22 : 34;
            final left = _trimToFit(_sanitizeForEscPos('${qty}x $rawName'), nameMax);
            final right = m['is_free_promo'] == true
                ? 'FREE'
                : _sanitizeForEscPos('$currency ${money(subtotal)}');
            _printerLog('REPRINT >> item[$idx] qtyType=${m['qty']?.runtimeType} '
                'subType=${m['subtotal']?.runtimeType} '
                'left="$left" right="$right" rawName="$rawName"');

            printer.row([
              PosColumn(text: left, width: 8, styles: const PosStyles(bold: true)),
              PosColumn(text: right, width: 4, styles: const PosStyles(align: PosAlign.right)),
            ]);
          } catch (e, st) {
            _printerLog('REPRINT >> item[$idx] ERROR: $e\n$st');
            try {
              printer.text(_sanitizeForEscPos('1x Item'), styles: const PosStyles(bold: true));
            } catch (_) {}
          }
        }
        _printerLog('REPRINT >> items done');

        currentStep = 'discount';
        final discountAmt = _asDouble(receiptData['amount_discount']);
        if (discountAmt > 0) {
          _printerLog('REPRINT >> [${++step}] discount line');
          printer.row([
            PosColumn(text: 'Discount:', width: 8, styles: const PosStyles(bold: true)),
            PosColumn(text: '-$currency ${money(discountAmt)}', width: 4, styles: const PosStyles(align: PosAlign.right, bold: true)),
          ]);
        }

        currentStep = 'hr#3 (=)';
        _printerLog('REPRINT >> [${++step}] hr (=)');
        printer.hr(ch: '=');
        currentStep = 'TOTAL row';
        final totalText = _sanitizeForEscPos('$currency ${money(total)}');
        _printerLog('REPRINT >> [${++step}] TOTAL row text="$totalText"');
        printer.row([
          PosColumn(text: 'TOTAL:', width: 8, styles: const PosStyles(bold: true)),
          PosColumn(text: totalText, width: 4, styles: const PosStyles(align: PosAlign.right, bold: true)),
        ]);
        currentStep = 'payments';
        final pays = receiptData['payments'];
        if (pays is List) {
          for (final pay in pays) {
            if (pay is! Map) continue;
            await _emitRow(
              printer,
              (pay['payment_method'] ?? '').toString(),
              '$currency ${money(_asDouble(pay['amount']))}',
              dots: _dotsFor(profile),
            );
          }
        }
        currentStep = 'points';
        final customer = (receiptData['customer'] ?? '').toString().trim();
        final pointsEarned = receiptData['points_earned'];
        if (customer.isNotEmpty || pointsEarned != null) {
          final dots = _dotsFor(profile);
          final label = (receiptData['points_label'] ?? 'Points').toString();
          printer.hr();
          // Customer names are often Lao: _emitLine rasterises them.
          if (customer.isNotEmpty) await _emitLine(printer, 'Customer: $customer', dots: dots);
          if (pointsEarned != null) {
            await _emitRow(printer, '$label earned', '+${_asInt(pointsEarned)}', dots: dots, bold: true);
            final balance = receiptData['customer_points'];
            if (balance != null) {
              await _emitRow(printer, 'Total $label', '${_asInt(balance)}', dots: dots);
            }
          }
        }
        currentStep = 'feed1';
        _printerLog('REPRINT >> [${++step}] feed(1) + thanks');
        printer.feed(1);
        final foot = (receiptData['footer_text'] ?? '').toString().trim();
        if (foot.isEmpty) {
          printer.text('Thank you!', styles: const PosStyles(align: PosAlign.center, bold: true));
          printer.text('Please come again', styles: const PosStyles(align: PosAlign.center));
        } else {
          currentStep = 'footer';
          _printerLog('REPRINT >> [${++step}] footer (${foot.split('\n').length} lines)');
          printer.feed(1);
          for (final line in foot.split('\n')) {
            final t = line.trimRight();
            if (t.isEmpty) continue;
            printer.text(_sanitizeForEscPos(t), styles: const PosStyles(align: PosAlign.center));
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
        _printerLog('REPRINT >> EXCEPTION at step=$currentStep on ${profile.name}: $e\n$st');
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
            )
          ];
    _printerLog('REFUND >> candidate printers = ${printers.length} '
        '${printers.map((p) => '${p.name}@${p.ip}:${p.port}/${p.paperWidthMm}mm').toList()}');

    if (printers.isEmpty || (printers.length == 1 && printers.first.ip.isEmpty)) {
      _printerLog('REFUND >> ABORT: no usable printer profile');
      return false;
    }

    bool anyOk = false;
    for (final profile in printers) {
      _printerLog('REFUND >> profile=${profile.name} ip=${profile.ip}:${profile.port} paper=${profile.paperWidthMm}mm');
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
        _printerLog('REFUND >> data: order=$orderRef cashier=$cashier payment=$payment '
            'currency(raw="$rawCurrency", safe="$currency") '
            'total=$total lines=${lines.length}');

        final head = (headerText ?? receiptData['header_text'] ?? '').toString().trim();
        currentStep = 'header';
        _printerLog('REFUND >> [${++step}] header (custom=${head.isNotEmpty})');
        if (head.isNotEmpty) {
          for (final line in head.split('\n')) {
            final t = line.trimRight();
            if (t.isEmpty) continue;
            printer.text(_sanitizeForEscPos(t), styles: const PosStyles(align: PosAlign.center, bold: true));
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
        }

        currentStep = 'refund label';
        _printerLog('REFUND >> [${++step}] REFUND label');
        printer.text('** REFUND **', styles: const PosStyles(align: PosAlign.center, bold: true));
        currentStep = 'hr#1';
        _printerLog('REFUND >> [${++step}] hr (-)');
        printer.hr();
        currentStep = 'meta';
        _printerLog('REFUND >> [${++step}] meta lines');
        if (queueNumber != null && queueNumber > 0) {
          printer.text(_fmtQueue(queueNumber), styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
          printer.hr();
        }
        if (orderRef.isNotEmpty) printer.text('Order: ${_sanitizeForEscPos(orderRef)}');
        printer.text('Refund Date: ${DateTime.now().toString().substring(0, 19)}');
        if (cashier.isNotEmpty) printer.text('Cashier: ${_sanitizeForEscPos(cashier)}');
        if (payment.isNotEmpty) printer.text('Payment: ${_sanitizeForEscPos(payment)}');
        currentStep = 'hr#2';
        _printerLog('REFUND >> [${++step}] hr (-)');
        printer.hr();

        currentStep = 'items';
        _printerLog('REFUND >> [${++step}] items begin (count=${lines.length})');
        int idx = 0;
        for (final line in lines) {
          idx++;
          try {
            final m = (line is Map) ? Map<String, dynamic>.from(line) : const <String, dynamic>{};
            // Printed in whatever language the POS is set to; the backend
            // ships both spellings on every line.
            final rawName = bilingualName(m, fallback: 'Item');
            final qty = _asInt(m['qty'], fallback: 1);
            final subtotal = _asDouble(m['subtotal']);

            final nameMax = profile.paperWidthMm == 58 ? 22 : 34;
            final left = _trimToFit(_sanitizeForEscPos('${qty}x $rawName'), nameMax);
            final right = m['is_free_promo'] == true
                ? 'FREE'
                : _sanitizeForEscPos('$currency ${money(subtotal)}');
            _printerLog('REFUND >> item[$idx] qtyType=${m['qty']?.runtimeType} '
                'subType=${m['subtotal']?.runtimeType} '
                'left="$left" right="$right" rawName="$rawName"');

            printer.row([
              PosColumn(text: left, width: 8, styles: const PosStyles(bold: true)),
              PosColumn(
                text: right,
                width: 4,
                styles: const PosStyles(align: PosAlign.right),
              ),
            ]);
          } catch (e, st) {
            _printerLog('REFUND >> item[$idx] ERROR: $e\n$st');
            try {
              printer.text(_sanitizeForEscPos('1x Item'), styles: const PosStyles(bold: true));
            } catch (_) {}
          }
        }
        _printerLog('REFUND >> items done');

        currentStep = 'hr#3 (=)';
        _printerLog('REFUND >> [${++step}] hr (=)');
        printer.hr(ch: '=');
        currentStep = 'REFUND AMOUNT row';
        final totalText = _sanitizeForEscPos('$currency ${money(total)}');
        _printerLog('REFUND >> [${++step}] REFUND AMOUNT row text="$totalText"');
        printer.row([
          PosColumn(text: 'REFUND AMOUNT:', width: 8, styles: const PosStyles(bold: true)),
          PosColumn(text: totalText, width: 4, styles: const PosStyles(align: PosAlign.right, bold: true)),
        ]);
        currentStep = 'feed1 + processed';
        _printerLog('REFUND >> [${++step}] feed(1) + Refund Processed');
        printer.feed(1);
        printer.text('Refund Processed', styles: const PosStyles(align: PosAlign.center, bold: true));

        final foot = (footerText ?? receiptData['footer_text'] ?? '').toString().trim();
        if (foot.isNotEmpty) {
          currentStep = 'footer';
          _printerLog('REFUND >> [${++step}] footer (${foot.split('\n').length} lines)');
          printer.feed(1);
          for (final line in foot.split('\n')) {
            final t = line.trimRight();
            if (t.isEmpty) continue;
            printer.text(_sanitizeForEscPos(t), styles: const PosStyles(align: PosAlign.center));
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
        _printerLog('REFUND >> EXCEPTION at step=$currentStep on ${profile.name}: $e\n$st');
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

/// One bill / receipt line: [quantity] of [item], priced [totalPrice].
class PrintLine {
  final CartItem item;
  int quantity;
  double totalPrice;

  PrintLine(this.item, this.quantity, this.totalPrice);
}

/// Joins cart lines that are the same item into one "2x" line for the bill
/// and the receipt. A reopened ticket keeps its saved lines and the newly
/// added ones apart (only the new ones go to the kitchen), so two croissants
/// used to print as "1x Butter croissant" twice. Lines stay apart when
/// anything differs: choices, kitchen note, unit price, free or redeemed.
List<PrintLine> mergeSamePrintLines(List<CartItem> items) {
  final byKey = <String, PrintLine>{};
  final lines = <PrintLine>[];
  for (final it in items) {
    final unit = it.quantity == 0 ? 0.0 : it.totalPrice / it.quantity;
    final toppingIds = it.selectedToppings.map((t) => t.id).toList()..sort();
    final key = [
      it.product.id,
      toppingIds.join(','),
      it.kitchenNote.trim(),
      unit.toStringAsFixed(2),
      it.isFreePromo,
      it.promotionId ?? '',
      it.isRedeemed,
    ].join('|');
    final existing = byKey[key];
    if (existing != null) {
      existing.quantity += it.quantity;
      existing.totalPrice += it.totalPrice;
      continue;
    }
    final line = PrintLine(it, it.quantity, it.totalPrice);
    byKey[key] = line;
    lines.add(line);
  }
  return lines;
}
