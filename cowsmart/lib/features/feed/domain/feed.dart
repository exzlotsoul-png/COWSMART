class FeedCategory {
  final String id;
  final String name;

  FeedCategory({required this.id, required this.name});

  factory FeedCategory.fromString(String category) {
    switch (category.toLowerCase()) {
      case 'หญ้า':
      case 'grass':
        return FeedCategory(id: 'grass', name: 'หญ้าอาหารหยาบ');
      case 'ข้น':
      case 'concentrate':
        return FeedCategory(id: 'concentrate', name: 'อาหารข้น/อาหารเม็ด');
      case 'เสริม':
      case 'supplement':
        return FeedCategory(id: 'supplement', name: 'อาหารเสริม/แร่ธาตุ');
      default:
        return FeedCategory(id: 'other', name: category);
    }
  }

  String get apiValue {
    switch (id) {
      case 'grass':
        return 'หญ้า';
      case 'concentrate':
        return 'ข้น';
      case 'supplement':
        return 'เสริม';
      default:
        return name;
    }
  }
}

/// บันทึกคลังอาหารอย่างง่าย - ไม่มีระบบสต็อกอัตโนมัติ
class FeedItem {
  final String id;
  final String farmId;
  final String? zoneId;
  final String name;
  final FeedCategory category;
  final double quantity; // ปริมาณที่บันทึก
  final double cost; // ราคารวม
  final DateTime recordedAt;
  final String? notes;

  FeedItem({
    required this.id,
    required this.farmId,
    this.zoneId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.cost,
    required this.recordedAt,
    this.notes,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      id: json['feed_inventory_id'] ?? json['id'] ?? '',
      farmId: json['farm_id'] ?? json['farmId'] ?? '',
      zoneId: json['zone_id'] ?? json['zoneId'],
      name: json['name'] ?? '',
      category: FeedCategory.fromString(json['category'] ?? 'other'),
      quantity:
          double.tryParse(json['stock_quantity']?.toString() ?? '0') ?? 0.0,
      cost: double.tryParse(json['cost_per_kg']?.toString() ?? '0') ?? 0.0,
      recordedAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'feed_inventory_id': id.isEmpty ? null : id,
      'farm_id': farmId,
      'zone_id': zoneId,
      'name': name,
      'category': category.apiValue,
      'stock_quantity': quantity,
      'cost_per_kg': cost,
      'notes': notes,
      'created_at': recordedAt.toIso8601String(),
    };
  }

  FeedItem copyWith({
    String? id,
    String? farmId,
    String? zoneId,
    String? name,
    FeedCategory? category,
    double? quantity,
    double? cost,
    DateTime? recordedAt,
    String? notes,
  }) {
    return FeedItem(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      zoneId: zoneId ?? this.zoneId,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      cost: cost ?? this.cost,
      recordedAt: recordedAt ?? this.recordedAt,
      notes: notes ?? this.notes,
    );
  }
}
