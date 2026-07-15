enum CowStatus {
  normal('ปกติ', 'success'),
  sick('ป่วย', 'error'),
  pregnant('ตั้งท้อง', 'info'),
  recovering('พักฟื้น', 'warning'),
  sold('ขายแล้ว', 'secondary'),
  deceased('ตาย', 'error'),
  removed('คัดออก', 'warning');

  final String label;
  final String colorType;
  const CowStatus(this.label, this.colorType);
}

enum CowType {
  breederMale('พ่อพันธุ์', 'T001'),
  breederFemale('แม่พันธุ์', 'T002'),
  calf('ลูกวัว', 'T004'),
  fattening('วัวขุน', 'T003');

  final String label;
  final String id;
  const CowType(this.label, this.id);

  static CowType fromId(String id) {
    return CowType.values.firstWhere((e) => e.id == id, orElse: () => CowType.fattening);
  }
}

class Cow {
  final String id;
  final String farmId;
  final String zoneId;
  final String name;
  final String tagNumber;
  final DateTime birthDate;
  final String gender; // 'M' or 'F'
  final CowType type;
  final String breed;
  final double latestWeight; // in kg
  final double purchasePrice; // in THB
  final String? fatherId;
  final String? motherId;
  final CowStatus status;
  final String? imageUrl;
  final String? imageFullUrl;

  Cow({
    required this.id,
    required this.farmId,
    required this.zoneId,
    required this.name,
    required this.tagNumber,
    required this.birthDate,
    required this.gender,
    required this.type,
    required this.breed,
    this.latestWeight = 0.0,
    this.purchasePrice = 0.0,
    this.fatherId,
    this.motherId,
    this.status = CowStatus.normal,
    this.imageUrl,
    this.imageFullUrl,
  });

  factory Cow.fromJson(Map<String, dynamic> json) {
    return Cow(
      id: (json['cow_id'] ?? json['id']).toString(),
      farmId: (json['farm_id'] ?? json['farmId']).toString(),
      zoneId: (json['zone_id'] ?? json['zoneId']).toString(),
      name: json['name'].toString(),
      tagNumber: json['tag_number'] ?? json['tagNumber'] ?? '',
      birthDate: DateTime.parse(json['birth_date'] ?? json['birthDate']),
      gender: json['gender'].toString(),
      type: CowType.fromId(json['cow_type_id'] ?? ''),
      breed: (json['breed_id'] ?? json['breed'] ?? 'Unknown').toString(),
      latestWeight: double.tryParse(json['latest_weight']?.toString() ?? '0') ?? 0.0,
      purchasePrice: double.tryParse(json['purchase_price']?.toString() ?? '0') ?? 0.0,
      fatherId: json['sire_id'],
      motherId: json['dam_id'],
      status: CowStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => CowStatus.normal),
      imageUrl: json['image_url'],
      imageFullUrl: json['image_full_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cow_id': id,
      'farm_id': farmId,
      'zone_id': zoneId,
      'name': name,
      'tag_number': tagNumber,
      'birth_date': birthDate.toIso8601String().split('T')[0],
      'gender': gender,
      'cow_type_id': type.id,
      'breed_id': breed,
      'status': status.name,
      'latest_weight': latestWeight,
      'purchase_price': purchasePrice,
      'image_url': imageUrl,
      'sire_id': fatherId,
      'dam_id': motherId,
    };
  }

  int get ageInMonths {
    final now = DateTime.now();
    return (now.year - birthDate.year) * 12 + now.month - birthDate.month;
  }

  double get estimatedValue => latestWeight * 120.0; // Mock current market price 120 THB/kg

  Cow copyWith({
    String? id,
    String? farmId,
    String? zoneId,
    String? name,
    String? tagNumber,
    DateTime? birthDate,
    String? gender,
    CowType? type,
    String? breed,
    double? latestWeight,
    double? purchasePrice,
    String? fatherId,
    String? motherId,
    CowStatus? status,
    String? imageUrl,
  }) {
    return Cow(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      zoneId: zoneId ?? this.zoneId,
      name: name ?? this.name,
      tagNumber: tagNumber ?? this.tagNumber,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      type: type ?? this.type,
      breed: breed ?? this.breed,
      latestWeight: latestWeight ?? this.latestWeight,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      fatherId: fatherId ?? this.fatherId,
      motherId: motherId ?? this.motherId,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
