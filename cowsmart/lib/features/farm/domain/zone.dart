class Zone {
  final String id;
  final String name;
  final String farmId;
  final int cowCount;

  Zone({
    required this.id,
    required this.name,
    required this.farmId,
    this.cowCount = 0,
  });

  factory Zone.fromJson(Map<String, dynamic> json) {
    return Zone(
      id: json['zone_id'].toString(),
      name: json['name'].toString(),
      farmId: json['farm_id'].toString(),
      cowCount: json['cows_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'zone_id': id,
      'name': name,
      'farm_id': farmId,
    };
  }

  Zone copyWith({
    String? id,
    String? name,
    String? farmId,
    int? cowCount,
  }) {
    return Zone(
      id: id ?? this.id,
      name: name ?? this.name,
      farmId: farmId ?? this.farmId,
      cowCount: cowCount ?? this.cowCount,
    );
  }
}
