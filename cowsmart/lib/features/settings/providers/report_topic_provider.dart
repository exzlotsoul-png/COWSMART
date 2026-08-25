import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/core/network/api_client.dart';
import '../domain/report_topic.dart';

class ReportTopicNotifier extends Notifier<List<ReportTopic>> {
  @override
  List<ReportTopic> build() {
    Future.microtask(() => fetchReportTopics());
    return [];
  }

  Future<void> fetchReportTopics() async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get('/report_topics');
      final dynamic raw = response.data;
      final List<dynamic> data = raw is List ? raw : (raw['data'] ?? []);
      final list = data.map((json) => ReportTopic.fromJson(json)).toList();
      if (list.isNotEmpty) {
        state = list;
      }
    } catch (_) {
      // Ignore or fallback to defaults
    }
  }
}

final reportTopicProvider = NotifierProvider<ReportTopicNotifier, List<ReportTopic>>(
  () => ReportTopicNotifier(),
);
