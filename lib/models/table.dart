class PosTable {
  final int id;
  final String name;
  final int capacity;
  final String status;
  final bool hasOpenOrder; // True if this table has a draft order

  PosTable({
    required this.id,
    required this.name,
    required this.capacity,
    required this.status,
    this.hasOpenOrder = false,
  });

  factory PosTable.fromJson(Map<String, dynamic> json) {
    return PosTable(
      id: json['id'],
      name: json['name'] ?? '',
      capacity: json['capacity'] ?? 0,
      status: json['status'] ?? 'available',
      hasOpenOrder: json['has_open_order'] == true,
    );
  }
}
