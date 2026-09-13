import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/core/network/api_client.dart';
import '../domain/cow_type_model.dart';
import '../domain/cow.dart';

class CowTypeNotifier extends Notifier<List<CowTypeModel>> {
  @override
  List<CowTypeModel> build() {
    Future.microtask(() => fetchCowTypes());
    // Fallback initial list from CowType enum so UI never has empty items
    return CowType.values
        .map((e) => CowTypeModel(id: e.id, name: e.label))
        .toList();
  }

  Future<void> fetchCowTypes() async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/cow_types');
      final List<dynamic> data = response.data is List ? response.data : [];
      if (data.isNotEmpty) {
        state = data.map((json) => CowTypeModel.fromJson(json)).toList();
      }
    } catch (e) {
      print('[ERROR] ดึงข้อมูลประเภทวัวไม่สำเร็จ: $e');
    }
  }
}

final cowTypeProvider = NotifierProvider<CowTypeNotifier, List<CowTypeModel>>(
  () => CowTypeNotifier(),
);
