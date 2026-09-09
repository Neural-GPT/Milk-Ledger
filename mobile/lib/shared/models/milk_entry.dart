class MilkEntry {
  final String id;
  final String customerId;
  final DateTime deliveryDate;
  final double quantityLitres;
  final double pricePerLitre;
  final double totalAmount;

  MilkEntry({
    required this.id,
    required this.customerId,
    required this.deliveryDate,
    required this.quantityLitres,
    required this.pricePerLitre,
    required this.totalAmount,
  });

  factory MilkEntry.fromJson(Map<String, dynamic> json) => MilkEntry(
        id: json['id'],
        customerId: json['customer_id'],
        deliveryDate: DateTime.parse(json['delivery_date']),
        quantityLitres: (json['quantity_litres'] as num).toDouble(),
        pricePerLitre: (json['price_per_litre'] as num).toDouble(),
        totalAmount: (json['total_amount'] as num).toDouble(),
      );
}
