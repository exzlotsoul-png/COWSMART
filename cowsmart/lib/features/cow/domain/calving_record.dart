class CalvingRecord {
  final String id;
  final String? breedingRecordId;
  final String damId;
  final DateTime? calvingDate;
  final String? calfId;
  final String? calvingResult;

  CalvingRecord({
    required this.id,
    this.breedingRecordId,
    required this.damId,
    this.calvingDate,
    this.calfId,
    this.calvingResult,
  });

  factory CalvingRecord.fromJson(Map<String, dynamic> json) {
    return CalvingRecord(
      id: (json['calving_record_id'] ?? json['id']).toString(),
      breedingRecordId: json['breeding_record_id']?.toString(),
      damId: json['dam_id'].toString(),
      calvingDate: json['calving_datetime'] != null
          ? DateTime.parse(json['calving_datetime'])
          : null,
      calfId: json['calf_id']?.toString(),
      calvingResult: json['calving_result'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'calving_record_id': id,
      'breeding_record_id': breedingRecordId,
      'dam_id': damId,
      'calving_datetime': calvingDate?.toIso8601String(),
      'calving_result': calvingResult,
    };
    // Only include calf_id if it has a value (must exist in cows table)
    if (calfId != null && calfId!.isNotEmpty) {
      data['calf_id'] = calfId;
    }
    return data;
  }
}
