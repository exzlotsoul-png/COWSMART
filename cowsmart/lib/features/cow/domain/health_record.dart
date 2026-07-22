class HealthRecord {
  final String id;
  final String cowId;
  final DateTime recordDate;
  final String checkupTypeId;
  final String? diseaseId;
  final String? medId;
  final String? vacId;
  final List<String> medIds;
  final List<String> vacIds;
  final double? cost;
  final String? adminName;
  final String? note;
  final List<String> images;
  // Display names from joined tables
  final String? diseaseName;
  final String? medicineName;
  final String? vaccineName;

  HealthRecord({
    required this.id,
    required this.cowId,
    required this.recordDate,
    required this.checkupTypeId,
    this.diseaseId,
    this.medId,
    this.vacId,
    this.medIds = const [],
    this.vacIds = const [],
    this.images = const [],
    this.cost,
    this.adminName,
    this.note,
    this.diseaseName,
    this.medicineName,
    this.vaccineName,
  });

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return [];
    }

    return HealthRecord(
      id: (json['health_record_id'] ?? json['id']).toString(),
      cowId: json['cow_id'].toString(),
      recordDate: DateTime.parse(json['record_date'] ?? json['recordDate']),
      checkupTypeId: json['checkup_type_id'].toString(),
      diseaseId: json['disease_id']?.toString(),
      medId: json['med_id']?.toString(),
      vacId: json['vac_id']?.toString(),
      medIds: parseStringList(json['med_ids']),
      vacIds: parseStringList(json['vac_ids']),
      images: parseStringList(json['images']),
      cost: json['cost'] != null ? double.parse(json['cost'].toString()) : null,
      adminName: json['admin_name'],
      note: json['note'],
      diseaseName: json['disease_name'],
      medicineName: json['medicine_name'],
      vaccineName: json['vaccine_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'health_record_id': id,
      'cow_id': cowId,
      'record_date': recordDate.toIso8601String(),
      'checkup_type_id': checkupTypeId,
      'disease_id': diseaseId,
      'med_id': medId ?? (medIds.isNotEmpty ? medIds.first : null),
      'vac_id': vacId ?? (vacIds.isNotEmpty ? vacIds.first : null),
      'med_ids': medIds,
      'vac_ids': vacIds,
      'images': images,
      'cost': cost,
      'admin_name': adminName,
      'note': note,
    };
  }
}
