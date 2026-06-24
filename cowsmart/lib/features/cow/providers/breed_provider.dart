import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/core/network/api_client.dart';
import '../domain/breed.dart';

class BreedNotifier extends Notifier<List<Breed>> {
  @override
  List<Breed> build() {
    Future.microtask(() => fetchBreeds());
    return [];
  }

  Future<void> fetchBreeds() async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/breeds');
      final List<dynamic> data = response.data;
      state = data.map((json) => Breed.fromJson(json)).toList();
    } catch (e) {
      print('[ERROR] ดึงข้อมูลสายพันธุ์ไม่สำเร็จ: $e');
      state = [];
    }
  }
}

final breedProvider = NotifierProvider<BreedNotifier, List<Breed>>(
  () => BreedNotifier(),
);
