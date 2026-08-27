import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/core/network/api_client.dart';

/// โรค
class Disease {
  final String id;
  final String name;
  final String? description;

  Disease({required this.id, required this.name, this.description});

  factory Disease.fromJson(Map<String, dynamic> json) {
    return Disease(
      id: json['disease_id'] ?? json['id'] ?? '',
      name: json['disease_name'] ?? json['name'] ?? '',
      description: json['description'],
    );
  }
}

/// ยา
class Medicine {
  final String id;
  final String name;
  final String? category;
  final String? indications;
  final String? description;

  Medicine({
    required this.id,
    required this.name,
    this.category,
    this.indications,
    this.description,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['medicine_id'] ?? json['id'] ?? '',
      name: json['medicine_name'] ?? json['name'] ?? '',
      category: json['category']?.toString(),
      indications: json['indications']?.toString(),
      description: json['description'],
    );
  }
}

/// วัคซีน
class Vaccine {
  final String id;
  final String name;
  final String? category;
  final String? indications;
  final String? description;

  Vaccine({
    required this.id,
    required this.name,
    this.category,
    this.indications,
    this.description,
  });

  factory Vaccine.fromJson(Map<String, dynamic> json) {
    return Vaccine(
      id: json['vaccine_id'] ?? json['id'] ?? '',
      name: json['vaccine_name'] ?? json['name'] ?? '',
      category: json['category']?.toString(),
      indications: json['indications']?.toString(),
      description: json['description'],
    );
  }
}

/// หน่วยวัด
class UnitModel {
  final String id;
  final String name;
  final String? abbreviation;
  final String? type;

  UnitModel({
    required this.id,
    required this.name,
    this.abbreviation,
    this.type,
  });

  factory UnitModel.fromJson(Map<String, dynamic> json) {
    return UnitModel(
      id: (json['unit_id'] ?? json['id'] ?? '').toString(),
      name: json['name'] ?? '',
      abbreviation: json['abbreviation'],
      type: json['type'],
    );
  }
}

/// Master Data State
class MasterDataState {
  final List<Disease> diseases;
  final List<Medicine> medicines;
  final List<Vaccine> vaccines;
  final List<UnitModel> units;
  final bool isLoading;
  final String? error;

  MasterDataState({
    this.diseases = const [],
    this.medicines = const [],
    this.vaccines = const [],
    this.units = const [],
    this.isLoading = false,
    this.error,
  });

  MasterDataState copyWith({
    List<Disease>? diseases,
    List<Medicine>? medicines,
    List<Vaccine>? vaccines,
    List<UnitModel>? units,
    bool? isLoading,
    String? error,
  }) {
    return MasterDataState(
      diseases: diseases ?? this.diseases,
      medicines: medicines ?? this.medicines,
      vaccines: vaccines ?? this.vaccines,
      units: units ?? this.units,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MasterDataNotifier extends Notifier<MasterDataState> {
  @override
  MasterDataState build() {
    return MasterDataState();
  }

  Future<void> fetchAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ref.read(apiClientProvider);

      final responses = await Future.wait([
        api.get('/diseases'),
        api.get('/medicines'),
        api.get('/vaccines'),
        api.get('/units'),
      ]);

      final diseases = (responses[0].data as List)
          .map((j) => Disease.fromJson(j))
          .toList();
      final medicines = (responses[1].data as List)
          .map((j) => Medicine.fromJson(j))
          .toList();
      final vaccines = (responses[2].data as List)
          .map((j) => Vaccine.fromJson(j))
          .toList();
      final units = (responses[3].data as List)
          .map((j) => UnitModel.fromJson(j))
          .toList();

      state = state.copyWith(
        diseases: diseases,
        medicines: medicines,
        vaccines: vaccines,
        units: units,
        isLoading: false,
      );
      print('[SUCCESS] ดึงข้อมูล master data สำเร็จ');
    } catch (e) {
      print('[ERROR] ดึงข้อมูล master data ไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final masterDataProvider =
    NotifierProvider<MasterDataNotifier, MasterDataState>(() {
      return MasterDataNotifier();
    });
