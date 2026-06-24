class GrowthRecord {
  final String id;
  final String cowId;
  final DateTime recordDate;
  final double weight;
  final double? girth;

  GrowthRecord({
    required this.id,
    required this.cowId,
    required this.recordDate,
    required this.weight,
    this.girth,
  });

  factory GrowthRecord.fromJson(Map<String, dynamic> json) {
    return GrowthRecord(
      id: (json['growth_records_id'] ?? json['id']).toString(),
      cowId: json['cow_id'].toString(),
      recordDate: DateTime.parse(json['record_date'] ?? json['recordDate']),
      weight: double.parse(json['weight'].toString()),
      girth: json['girth'] != null ? double.parse(json['girth'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'growth_records_id': id,
      'cow_id': cowId,
      'record_date': recordDate.toIso8601String(),
      'weight': weight,
      'girth': girth,
    };
  }
}
