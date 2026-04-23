import 'dart:convert';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';

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
      final result = await printer.connect(profile.ip, port: profile.port);
      if (result == PosPrintResult.success) {
        printer.text('=== LaDolce POS ===', styles: const PosStyles(align: PosAlign.center, bold: true));
        printer.text('Printer: ${profile.name}', styles: const PosStyles(align: PosAlign.center));
        printer.text('Test page OK', styles: const PosStyles(align: PosAlign.center));
        printer.feed(3);
        printer.cut();
        printer.disconnect();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> printOrderTicketDirect({
    required PrinterProfile profile,
    required List<CartItem> items,
    required String cashierName,
  }) async {
    return _printOrderTicketToProfile(profile, items: items, cashierName: cashierName);
  }

  Future<bool> testConnection() async {
    await initialize();
    final p = _getReceiptPrinter();
    if (p != null) return testProfile(p);
    if (!isConfigured) return false;
    
    try {
      final printer = NetworkPrinter(_paperSize, await CapabilityProfile.load());
      final result = await printer.connect(_printerIp!, port: _printerPort);
      
      if (result == PosPrintResult.success) {
        printer.text('=== LaDolce POS ===', styles: const PosStyles(align: PosAlign.center, bold: true));
        printer.text('Printer Test OK!', styles: const PosStyles(align: PosAlign.center));
        printer.feed(3);
        printer.cut();
        printer.disconnect();
        return true;
      }
      return false;
    } catch (e) {
      print('[PRINTER] Test connection failed: $e');
      return false;
    }
  }

  Future<bool> printReceipt({
    required List<CartItem> cartItems,
    required double subtotal,
    required double tax,
    required double total,
    String cashierName = 'Cashier',
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
      );
    } catch (e) {
      print('[PRINTER] Print receipt failed: $e');
      return false;
    }
  }

  List<CartItem> _filterItemsForPrinter(List<CartItem> items, PrinterProfile printer) {
    if (printer.categoryFilters.isEmpty) return items;
    final filters = printer.categoryFilters.map((e) => e.toLowerCase()).toSet();
    return items.where((i) => filters.contains(i.product.category.toLowerCase())).toList();
  }


  Future<bool> printBill({
    required List<CartItem> cartItems,
    required double subtotal,
    required double tax,
    required double total,
    String cashierName = 'Cashier',
    String? ticketName,
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
}) async {
  try {
    final cap = await CapabilityProfile.load();
    final printer = NetworkPrinter(profile.paperSize, cap);
    final result = await printer.connect(profile.ip, port: profile.port);
    if (result != PosPrintResult.success) return false;

    printer.text('LaDolce', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    printer.text('Point of Sale', styles: const PosStyles(align: PosAlign.center));
    if (ticketName != null && ticketName.isNotEmpty) {
      printer.text(ticketName, styles: const PosStyles(align: PosAlign.center, bold: true));
    }
    printer.hr();
    printer.text('Date: ${DateTime.now().toString().substring(0, 19)}');
    printer.text('Cashier: $cashierName');
    printer.hr();

    for (final item in cartItems) {
      printer.row([
        PosColumn(text: '${item.quantity}x ${item.product.name}', width: 8, styles: const PosStyles(bold: true)),
        PosColumn(text: 'LAK ${item.totalPrice.toStringAsFixed(2)}', width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
      // Print toppings as sub-lines if any
      for (final topping in item.selectedToppings) {
        printer.row([
          PosColumn(text: '  + ${topping.name}', width: 8),
          PosColumn(
            text: topping.extraPrice > 0 ? 'LAK${topping.extraPrice.toStringAsFixed(2)}' : '',
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }
    }

    printer.hr();
    printer.row([
      PosColumn(text: 'Subtotal:', width: 8),
      PosColumn(text: 'LAK ${subtotal.toStringAsFixed(2)}', width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    printer.row([
      PosColumn(text: 'Tax (10%):', width: 8),
      PosColumn(text: 'LAK ${tax.toStringAsFixed(2)}', width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    printer.hr(ch: '=');
    printer.row([
      PosColumn(text: 'TOTAL:', width: 8, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(text: 'LAK ${total.toStringAsFixed(2)}', width: 4, styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2)),
    ]);
    printer.feed(1);
    printer.text('** NOT A RECEIPT **', styles: const PosStyles(align: PosAlign.center, bold: true));
    printer.text('Please wait for your receipt', styles: const PosStyles(align: PosAlign.center));
    printer.feed(3);
    printer.cut();
    printer.disconnect();
    return true;
  } catch (e) {
    print('[PRINTER] Print bill failed: $e');
    return false;
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
  }) => _printReceiptToProfile(
        profile,
        cartItems: cartItems,
        subtotal: subtotal,
        tax: tax,
        total: total,
        cashierName: cashierName,
      );

  Future<bool> _printReceiptToProfile(
    PrinterProfile profile, {
    required List<CartItem> cartItems,
    required double subtotal,
    required double tax,
    required double total,
    required String cashierName,
    
  }) async {
    final cap = await CapabilityProfile.load();
    final printer = NetworkPrinter(profile.paperSize, cap);
    final result = await printer.connect(profile.ip, port: profile.port);
    if (result != PosPrintResult.success) return false;

    printer.text('LaDolce', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    printer.text('Point of Sale', styles: const PosStyles(align: PosAlign.center));
    printer.text('Printer: ${profile.name}', styles: const PosStyles(align: PosAlign.center));
    printer.hr();
    printer.text('Date: ${DateTime.now().toString().substring(0, 19)}');
    printer.text('Cashier: $cashierName');
    printer.hr();
    for (final item in cartItems) {
      printer.row([
        PosColumn(text: '${item.quantity}x ${item.product.name}', width: 8, styles: const PosStyles(bold: true)),
        PosColumn(text: 'LAK${item.totalPrice.toStringAsFixed(2)}', width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    printer.hr();
    printer.row([
      PosColumn(text: 'Subtotal:', width: 8),
      PosColumn(text: 'LAK${subtotal.toStringAsFixed(2)}', width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    printer.row([
      PosColumn(text: 'Tax (10%):', width: 8),
      PosColumn(text: 'LAK${tax.toStringAsFixed(2)}', width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    printer.hr(ch: '=');
    printer.row([
      PosColumn(text: 'TOTAL:', width: 8, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(text: 'LAK${total.toStringAsFixed(2)}', width: 4, styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2)),
    ]);
    printer.feed(1);
    printer.text('Thank you!', styles: const PosStyles(align: PosAlign.center, bold: true));
    printer.text('Please come again', styles: const PosStyles(align: PosAlign.center));
    printer.feed(3);
    printer.cut();
    printer.disconnect();
    return true;
  }

  Future<bool> _printOrderTicketToProfile(
    PrinterProfile profile, {
    required List<CartItem> items,
    required String cashierName,
  }) async {
    final cap = await CapabilityProfile.load();
    final printer = NetworkPrinter(profile.paperSize, cap);
    final result = await printer.connect(profile.ip, port: profile.port);
    if (result != PosPrintResult.success) return false;

    printer.text('Kitchen / Order Ticket', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    printer.text('Printer: ${profile.name}', styles: const PosStyles(align: PosAlign.center));
    printer.text('Date: ${DateTime.now().toString().substring(0, 19)}');
    printer.text('Cashier: $cashierName');
    printer.hr();

    if (profile.singleItemPerTicket) {
      for (final i in items) {
        for (int q = 0; q < i.quantity; q++) {
          printer.text('1x ${i.product.name}', styles: const PosStyles(bold: true, height: PosTextSize.size2));
          printer.feed(2);
          printer.cut();
        }
      }
      printer.disconnect();
      return true;
    }

    final rows = <Map<String, dynamic>>[];
    if (profile.groupIdenticalItems) {
      final map = <String, int>{};
      for (final i in items) {
        map[i.product.name] = (map[i.product.name] ?? 0) + i.quantity;
      }
      for (final entry in map.entries) {
        rows.add({'name': entry.key, 'qty': entry.value});
      }
    } else {
      for (final i in items) {
        rows.add({'name': i.product.name, 'qty': i.quantity});
      }
    }

    for (final r in rows) {
      printer.text('${r['qty']}x ${r['name']}', styles: const PosStyles(bold: true, height: PosTextSize.size2));
      printer.feed(1);
    }
    printer.feed(2);
    printer.cut();
    printer.disconnect();
    return true;
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
    final result = await printer.connect(profile.ip, port: profile.port);
    if (result != PosPrintResult.success) return false;

    // ESC/POS cash drawer pulse: ESC p m t1 t2
    // Pin 2: ESC p 0 25 250
    // Pin 5: ESC p 1 25 250
    printer.rawBytes([0x1B, 0x70, 0x00, 0x19, 0xFA]); // pin 2
    printer.disconnect();
    return true;
  } catch (e) {
    print('[PRINTER] Open cash drawer failed: $e');
    return false;
  }

}

  /// Reprint a historical receipt using raw order data from the API.
  /// [receiptData] is the map returned by fetchOrderReceipt() / the receipt
  /// history detail screen. Lines must contain 'product_name', 'qty', 'subtotal'.
  Future<bool> printReceiptFromRawData(Map<String, dynamic> receiptData) async {
    await initialize();
    if (!isConfigured) return false;

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

    if (printers.isEmpty || (printers.length == 1 && printers.first.ip.isEmpty)) {
      return false;
    }

    bool anyOk = false;
    for (final profile in printers) {
      try {
        final cap = await CapabilityProfile.load();
        final printer = NetworkPrinter(profile.paperSize, cap);
        final result = await printer.connect(profile.ip, port: profile.port);
        if (result != PosPrintResult.success) continue;

        final orderRef  = receiptData['order_reference']?.toString() ?? '';
        final cashier   = receiptData['cashier']?.toString() ?? '';
        final table     = receiptData['table']?.toString() ?? '';
        final payment   = receiptData['payment_method']?.toString() ?? '';
        final total     = (receiptData['amount_total'] as num?)?.toDouble() ?? 0.0;
        final lines     = receiptData['lines'] as List? ?? [];
        final currency  = receiptData['currency']?.toString() ?? 'LAK';
        final dateStr   = receiptData['date_order']?.toString() ?? '';

        printer.text('LaDolce', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
        printer.text('Point of Sale', styles: const PosStyles(align: PosAlign.center));
        printer.text('** REPRINT **', styles: const PosStyles(align: PosAlign.center, bold: true));
        printer.hr();
        printer.text('Order: $orderRef');
        if (dateStr.isNotEmpty) printer.text('Date: ${dateStr.substring(0, dateStr.length > 19 ? 19 : dateStr.length)}');
        if (cashier.isNotEmpty) printer.text('Cashier: $cashier');
        if (table.isNotEmpty)   printer.text('Table: $table');
        if (payment.isNotEmpty) printer.text('Payment: $payment');
        printer.hr();

        for (final line in lines) {
          final name     = line['product_name']?.toString() ?? 'Item';
          final qty      = (line['qty'] as num?)?.toInt() ?? 1;
          final subtotal = (line['subtotal'] as num?)?.toDouble() ?? 0.0;
          printer.row([
            PosColumn(text: '${qty}x $name', width: 8, styles: const PosStyles(bold: true)),
            PosColumn(text: '$currency ${subtotal.toStringAsFixed(2)}', width: 4, styles: const PosStyles(align: PosAlign.right)),
          ]);
        }

        printer.hr(ch: '=');
        printer.row([
          PosColumn(text: 'TOTAL:', width: 8, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
          PosColumn(text: '$currency ${total.toStringAsFixed(2)}', width: 4, styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2)),
        ]);
        printer.feed(3);
        printer.cut();
        printer.disconnect();
        anyOk = true;
      } catch (e) {
        print('[PRINTER] printReceiptFromRawData failed on ${profile.name}: $e');
      }
    }
    return anyOk;
  }
}

// Singleton instance
final printerService = PrinterService();
