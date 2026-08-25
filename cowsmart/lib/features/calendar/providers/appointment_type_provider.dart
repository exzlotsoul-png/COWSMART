import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/core/network/api_client.dart';
import '../domain/appointment_type.dart';

class AppointmentTypeNotifier extends Notifier<List<AppointmentType>> {
  @override
  List<AppointmentType> build() {
    Future.microtask(() => fetchAppointmentTypes());
    return [];
  }

  Future<void> fetchAppointmentTypes() async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/appointment_types');
      final dynamic raw = response.data;
      final List<dynamic> data = raw is List ? raw : (raw['data'] ?? []);
      final list = data.map((json) => AppointmentType.fromJson(json)).toList();
      if (list.isNotEmpty) {
        state = list;
      }
    } catch (_) {
      // Ignore or log via logger
    }
  }
}

final appointmentTypeProvider = NotifierProvider<AppointmentTypeNotifier, List<AppointmentType>>(
  () => AppointmentTypeNotifier(),
);
