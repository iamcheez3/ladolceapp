class OpenTicket {
  final int id;
  final String name;
  final int? tableId;
  final String? tableName;
  final double amountTotal;
  final String paymentType;
  final int? paymentMethodId;
  final String paymentMethodName;
  final bool transferProofUploaded;
  final String transferProofUrl;
  final List<TicketLine> lines;
  /// When the ticket was first opened (from Odoo date_order).
  final DateTime? openedAt;
  final String note;

  OpenTicket({
    required this.id,
    required this.name,
    this.tableId,
    this.tableName,
    required this.amountTotal,
    this.paymentType = '',
    this.paymentMethodId,
    this.paymentMethodName = '',
    this.transferProofUploaded = false,
    this.transferProofUrl = '',
    required this.lines,
    this.openedAt,
    this.note = '',
  });

  factory OpenTicket.fromJson(Map<String, dynamic> json) {
    DateTime? openedAt;
    try {
      if (json['opened_at'] != null) {
        // Odoo returns UTC datetimes without 'Z' suffix — parse and convert to local.
        openedAt = DateTime.parse(json['opened_at'].toString()).toLocal();
      }
    } catch (_) {}

    return OpenTicket(
      id: json['id'],
      name: json['name'],
      tableId: json['table_id'],
      tableName: json['table_name'],
      amountTotal: (json['amount_total'] ?? 0).toDouble(),
      paymentType: (json['payment_type'] ?? '').toString(),
      paymentMethodId: json['payment_method_id'],
      paymentMethodName: (json['payment_method_name'] ?? '').toString(),
      transferProofUploaded: json['transfer_proof_uploaded'] == true,
      transferProofUrl: (json['transfer_proof_url'] ?? '').toString(),
      lines: (json['lines'] as List)
          .map((lineJson) => TicketLine.fromJson(lineJson))
          .toList(),
      openedAt: openedAt,
      note: (json['note'] ?? '').toString(),
    );
  }
}

class TicketLine {
  final int productId;
  final String productName;
  final int qty;
  final double priceUnit;
  final List<int> toppingIds;
  final String note;

  TicketLine({
    required this.productId,
    required this.productName,
    required this.qty,
    required this.priceUnit,
    this.toppingIds = const [],
    this.note = '',
  });

  factory TicketLine.fromJson(Map<String, dynamic> json) {
    return TicketLine(
      productId: json['product_id'],
      productName: json['product_name'],
      qty: (json['qty'] ?? 1).toInt(),
      priceUnit: (json['price_unit'] ?? 0).toDouble(),
      toppingIds: (json['topping_ids'] as List<dynamic>? ?? const [])
          .map((id) => int.tryParse(id.toString()) ?? 0)
          .where((id) => id > 0)
          .toList(),
      note: (json['note'] ?? '').toString(),
    );
  }
}
