class OpenTicket {
  final int id;
  final String name;
  final int? tableId;
  final String? tableName;
  final double amountTotal;
  final int queueNumber;
  final String paymentType;
  final int? paymentMethodId;
  final String paymentMethodName;
  final bool transferProofUploaded;
  final String transferProofUrl;
  final List<TicketLine> lines;
  /// When the ticket was first opened (from Odoo date_order).
  final DateTime? openedAt;
  final String note;
  final bool isSelfOrder;
  final int? partnerId;
  final String partnerName;
  final String customerPhone;
  final String deliveryPlaceName;
  final String deliveryPlaceAddress;
  final String discountType;
  final double discountValue;
  final double discountAmount;

  OpenTicket({
    required this.id,
    required this.name,
    this.tableId,
    this.tableName,
    required this.amountTotal,
    this.queueNumber = 0,
    this.paymentType = '',
    this.paymentMethodId,
    this.paymentMethodName = '',
    this.transferProofUploaded = false,
    this.transferProofUrl = '',
    required this.lines,
    this.openedAt,
    this.note = '',
    this.isSelfOrder = false,
    this.partnerId,
    this.partnerName = '',
    this.customerPhone = '',
    this.deliveryPlaceName = '',
    this.deliveryPlaceAddress = '',
    this.discountType = '',
    this.discountValue = 0.0,
    this.discountAmount = 0.0,
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
      queueNumber: (json['queue_number'] ?? 0).toInt(),
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
      isSelfOrder: json['is_self_order'] == true,
      partnerId: json['partner_id'],
      partnerName: (json['partner_name'] ?? '').toString(),
      customerPhone: (json['customer_phone'] ?? '').toString(),
      deliveryPlaceName: (json['delivery_place_name'] ?? '').toString(),
      deliveryPlaceAddress: (json['delivery_place_address'] ?? '').toString(),
      discountType: (json['discount_type'] ?? '').toString(),
      discountValue: (json['discount_value'] ?? 0).toDouble(),
      discountAmount: (json['discount_amount'] ?? 0).toDouble(),
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
