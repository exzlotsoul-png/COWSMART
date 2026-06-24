class MarketPrice {
  final int id;
  final String animalType;
  final String? category;
  final double pricePerKg;
  final DateTime effectiveDate;
  final String? source;
  final String? note;

  MarketPrice({
    required this.id,
    required this.animalType,
    required this.pricePerKg,
    required this.effectiveDate,
    this.category,
    this.source,
    this.note,
  });

  factory MarketPrice.fromJson(Map<String, dynamic> json) {
    return MarketPrice(
      id: json['id'] ?? 0,
      animalType: json['animal_type'] ?? 'cattle',
      category: json['category'],
      pricePerKg: double.tryParse(json['price_per_kg']?.toString() ?? '0') ?? 0,
      effectiveDate: DateTime.parse(json['effective_date']),
      source: json['source'],
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'animal_type': animalType,
      'category': category,
      'price_per_kg': pricePerKg,
      'effective_date': effectiveDate.toIso8601String().split('T')[0],
      'source': source,
      'note': note,
    };
  }
}
