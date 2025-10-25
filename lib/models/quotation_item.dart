class QuotationItem {
  String category;
  String name;
  int quantity;
  double? thickness;
  double? length;
  String? unit;

  QuotationItem({
    required this.category,
    required this.name,
    required this.quantity,
    this.thickness,
    this.length,
    this.unit,
  });

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'name': name,
      'quantity': quantity,
      'thickness': thickness,
      'length': length,
      'unit': unit,
    };
  }

  factory QuotationItem.fromMap(Map<String, dynamic> map) {
    return QuotationItem(
      category: map['category'] ?? '',
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? 0,
      thickness:
          map['thickness'] != null ? (map['thickness'] as num).toDouble() : null,
      length: map['length'] != null ? (map['length'] as num).toDouble() : null,
      unit: map['unit'],
    );
  }

  String get displayName {
    if (name == 'IBR Sheet') {
      return '${thickness}mm x 686mm x ${length}m IBR Sheet';
    }
    if (name == 'Roll top Ridges' || name == 'Valley gutters') {
      return '$name (${thickness}mm)';
    }
    return name;
  }
}
