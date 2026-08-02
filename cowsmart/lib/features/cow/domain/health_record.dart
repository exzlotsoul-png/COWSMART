import 'dart:convert';

class HealthRecordItem {
  final String itemId;
  final String itemName;
  final String itemType; // 'vaccine' or 'medicine'
  final double? amount;
  final int? unitId;
  final String? unitName;
  final String? unitAbbreviation;
  final double? cost;

  HealthRecordItem({
    required this.itemId,
    required this.itemName,
    required this.itemType,
    this.amount,
    this.unitId,
    this.unitName,
    this.unitAbbreviation,
    this.cost,
  });

  factory HealthRecordItem.fromJson(Map<String, dynamic> json) {
    return HealthRecordItem(
      itemId: (json['item_id'] ?? json['itemId'] ?? '').toString(),
      itemName: (json['item_name'] ?? json['itemName'] ?? '').toString(),
      itemType: (json['item_type'] ?? json['itemType'] ?? '').toString(),
      amount: json['amount'] != null ? double.tryParse(json['amount'].toString()) : null,
      unitId: json['unit_id'] != null ? int.tryParse(json['unit_id'].toString()) : null,
      unitName: json['unit_name'],
      unitAbbreviation: json['unit_abbreviation'],
      cost: json['cost'] != null ? double.tryParse(json['cost'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'item_name': itemName,
      'item_type': itemType,
      'amount': amount,
      'unit_id': unitId,
      'unit_name': unitName,
      'unit_abbreviation': unitAbbreviation,
      'cost': cost,
    };
  }
}

class HealthRecord {
  final String id;
  final String cowId;
  final DateTime recordDate;
  final String checkupTypeId;
  final String? status; // 'normal', 'sick', 'injured'
  final String? diseaseId;
  final String? medId;
  final String? vacId;
  final List<String> medIds;
  final List<String> vacIds;
  final double? cost;
  final double? amount;
  final int? unitId;
  final String? adminName;
  final String? note;
  final List<String> images;
  final List<HealthRecordItem> items;

  // Display names from joined tables
  final String? diseaseName;
  final String? medicineName;
  final String? vaccineName;
  final String? unitName;
  final String? unitAbbreviation;

  HealthRecord({
    required this.id,
    required this.cowId,
    required this.recordDate,
    required this.checkupTypeId,
    this.status,
    this.diseaseId,
    this.medId,
    this.vacId,
    this.medIds = const [],
    this.vacIds = const [],
    this.images = const [],
    this.items = const [],
    this.cost,
    this.amount,
    this.unitId,
    this.adminName,
    this.note,
    this.diseaseName,
    this.medicineName,
    this.vaccineName,
    this.unitName,
    this.unitAbbreviation,
  });

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return [];
    }

    List<HealthRecordItem> parseItems(dynamic val) {
      if (val is List) {
        return val.map((e) => HealthRecordItem.fromJson(e as Map<String, dynamic>)).toList();
      }
      if (val is String && val.isNotEmpty) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) {
            return decoded.map((e) => HealthRecordItem.fromJson(e as Map<String, dynamic>)).toList();
          }
        } catch (_) {}
      }
      return [];
    }

    return HealthRecord(
      id: (json['health_record_id'] ?? json['id']).toString(),
      cowId: json['cow_id'].toString(),
      recordDate: DateTime.parse(json['record_date'] ?? json['recordDate']),
      checkupTypeId: json['checkup_type_id'].toString(),
      status: json['status']?.toString(),
      diseaseId: json['disease_id']?.toString(),
      medId: json['med_id']?.toString(),
      vacId: json['vac_id']?.toString(),
      medIds: parseStringList(json['med_ids']),
      vacIds: parseStringList(json['vac_ids']),
      images: parseStringList(json['images']),
      items: parseItems(json['items_json'] ?? json['items']),
      cost: json['cost'] != null ? double.tryParse(json['cost'].toString()) : null,
      amount: json['amount'] != null ? double.tryParse(json['amount'].toString()) : null,
      unitId: json['unit_id'] != null ? int.tryParse(json['unit_id'].toString()) : null,
      adminName: json['admin_name'],
      note: json['note'],
      diseaseName: json['disease_name'],
      medicineName: json['medicine_name'],
      vaccineName: json['vaccine_name'],
      unitName: json['unit_name'],
      unitAbbreviation: json['unit_abbreviation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'health_record_id': id,
      'cow_id': cowId,
      'record_date': recordDate.toIso8601String(),
      'checkup_type_id': checkupTypeId,
      'status': status,
      'disease_id': diseaseId,
      'med_id': medId ?? (medIds.isNotEmpty ? medIds.first : null),
      'vac_id': vacId ?? (vacIds.isNotEmpty ? vacIds.first : null),
      'med_ids': medIds,
      'vac_ids': vacIds,
      'images': images,
      'items_json': items.map((i) => i.toJson()).toList(),
      'cost': cost,
      'amount': amount,
      'unit_id': unitId,
      'admin_name': adminName,
      'note': note,
    };
  }
}
