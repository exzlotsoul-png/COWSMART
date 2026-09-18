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

  static String normalizeCategory(String? cat) {
    if (cat == null) return '';
    var c = cat.trim();
    c = c.replaceAll('<=', '≤');
    c = c.replaceAllMapped(RegExp(r'\(\s*>\s*'), (m) => '(> ');
    c = c.replaceAllMapped(RegExp(r'\(\s*≤\s*'), (m) => '(≤ ');
    c = c.replaceAllMapped(RegExp(r'(\d+)\s*-\s*(\d+)'), (m) => '${m[1]} - ${m[2]}');
    c = c.replaceAllMapped(RegExp(r'\s*กก\.?\s*\)'), (m) => ' กก.)');
    c = c.replaceAll(RegExp(r'\s+'), ' ');
    return c.trim();
  }

  factory MarketPrice.fromJson(Map<String, dynamic> json) {
    final rawCat = json['category']?.toString();
    return MarketPrice(
      id: json['id'] ?? 0,
      animalType: json['animal_type'] ?? 'cattle',
      category: rawCat != null ? normalizeCategory(rawCat) : null,
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
