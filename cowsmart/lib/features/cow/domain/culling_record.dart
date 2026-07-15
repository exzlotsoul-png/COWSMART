import 'cow.dart';

class CullingRecord {
  final String id;
  final String cowId;
  final DateTime cullDate;
  final int status; // 0=Sold, 1=Deceased, 2=Removed
  final double price;
  final String note;
  final Cow? cow; // Nested cow object from backend index eager loading

  CullingRecord({
    required this.id,
    required this.cowId,
    required this.cullDate,
    required this.status,
    this.price = 0.0,
    this.note = '',
    this.cow,
  });

  String get statusLabel {
    switch (status) {
      case 0:
        return 'ขาย';
      case 1:
        return 'ตาย';
      case 2:
        return 'คัดออก';
      default:
        return 'ไม่ระบุ';
    }
  }

  factory CullingRecord.fromJson(Map<String, dynamic> json) {
    return CullingRecord(
      id: (json['culling_record_id'] ?? json['id']).toString(),
      cowId: json['cow_id'].toString(),
      cullDate: DateTime.parse(json['cull_date']),
      status: int.tryParse(json['status'].toString()) ?? 0,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      note: json['note']?.toString() ?? '',
      cow: json['cow'] != null ? Cow.fromJson(json['cow']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'culling_record_id': id,
      'cow_id': cowId,
      'cull_date': cullDate.toIso8601String(),
      'status': status,
      'price': price,
      'note': note,
      if (cow != null) 'cow': cow!.toJson(),
    };
  }
}
