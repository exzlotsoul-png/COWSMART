class BreedingRecord {
  final String id;
  final String damId; // Mother
  final String? sireId; // Father
  final DateTime? heatDate;
  final DateTime? matingDate;
  final DateTime? checkDate;
  final String? pregnancyResult;
  final DateTime? expectedCalving;
  // Calving info (step 4)
  final DateTime? calvingDate;
  final String? calvingResult;
  final String? calfId;

  BreedingRecord({
    required this.id,
    required this.damId,
    this.sireId,
    this.heatDate,
    this.matingDate,
    this.checkDate,
    this.pregnancyResult,
    this.expectedCalving,
    this.calvingDate,
    this.calvingResult,
    this.calfId,
  });

  factory BreedingRecord.fromJson(Map<String, dynamic> json) {
    return BreedingRecord(
      id: (json['breeding_record_id'] ?? json['id']).toString(),
      damId: json['dam_id'].toString(),
      sireId: json['sire_id']?.toString(),
      heatDate: json['heat_date'] != null
          ? DateTime.parse(json['heat_date'])
          : null,
      matingDate: json['mating_date'] != null
          ? DateTime.parse(json['mating_date'])
          : null,
      checkDate: json['check_date'] != null
          ? DateTime.parse(json['check_date'])
          : null,
      pregnancyResult: json['pregnancy_result'],
      expectedCalving: json['expected_calving'] != null
          ? DateTime.parse(json['expected_calving'])
          : null,
      calvingDate: json['calving_date'] != null
          ? DateTime.parse(json['calving_date'])
          : null,
      calvingResult: json['calving_result'],
      calfId: json['calf_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'breeding_record_id': id,
      'dam_id': damId,
      'sire_id': sireId,
      'heat_date': heatDate?.toIso8601String(),
      'mating_date': matingDate?.toIso8601String(),
      'check_date': checkDate?.toIso8601String().split('T')[0],
      'pregnancy_result': pregnancyResult,
      'expected_calving': expectedCalving?.toIso8601String().split('T')[0],
      'calving_date': calvingDate?.toIso8601String(),
      'calving_result': calvingResult,
      'calf_id': calfId,
    };
  }
}
