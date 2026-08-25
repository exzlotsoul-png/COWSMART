import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../domain/chat_message.dart';

final aiChatRepositoryProvider = Provider<AiChatRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AiChatRepository(apiClient);
});

class AiChatRepository {
  final ApiClient _apiClient;

  AiChatRepository(this._apiClient);

  Future<List<SuggestedTopicCategory>> getSuggestedTopics() async {
    try {
      final response = await _apiClient.get('/ai/suggested-topics');
      if (response.data != null && response.data['data'] != null) {
        final List<dynamic> list = response.data['data'];
        return list.map((c) => SuggestedTopicCategory.fromJson(c)).toList();
      }
      return [];
    } catch (e) {
      return _getLocalFallbackTopics();
    }
  }

  Future<Map<String, dynamic>> consultAi({
    required String message,
    String? cowId,
  }) async {
    final response = await _apiClient.post('/ai/consult', data: {
      'message': message,
      if (cowId != null) 'cow_id': cowId,
    });
    return response.data;
  }

  List<SuggestedTopicCategory> _getLocalFallbackTopics() {
    return [
      SuggestedTopicCategory(
        category: 'อาการทางเดินอาหาร',
        items: [
          SuggestedTopicItem(
            title: 'วัวท้องอืด / ท้องซ้ายบวม',
            prompt: 'วัวมีอาการท้องอืด ท้องด้านซ้ายบวม ไม่ยอมเคี้ยวเอื้อง ต้องปฐมพยาบาลอย่างไร?',
          ),
          SuggestedTopicItem(
            title: 'วัวถ่ายเหลว / ขี้ร่วง',
            prompt: 'วัวถ่ายเหลว ท้องเสีย มีกลิ่นเหม็น ควรกินยาหรือให้น้ำเกลืออย่างไร?',
          ),
        ],
      ),
      SuggestedTopicCategory(
        category: 'โรคติดเชื้อและไข้',
        items: [
          SuggestedTopicItem(
            title: 'ปากและเท้าเปื่อย (FMD)',
            prompt: 'วัวน้ำลายไหลยืด กีบเท้าเปื่อย ยืนเจ็บขา มีตุ่มแผลที่ปาก เป็นโรคอะไรและรักษายังไง?',
          ),
          SuggestedTopicItem(
            title: 'โรคลัมปีสกิน (Lumpy Skin)',
            prompt: 'วัวมีตุ่มนูนแข็งขึ้นตามลำตัวและคอ มีไข้สูง ต้องรักษายังไงและพ่นยาอะไร?',
          ),
          SuggestedTopicItem(
            title: 'ไข้ขา / โรคไข้ 3 วัน',
            prompt: 'วัวลุกไม่ขึ้น ขาแข็ง เดินกะเผลก มีไข้ หายใจเร็ว ปฐมพยาบาลอย่างไร?',
          ),
        ],
      ),
      SuggestedTopicCategory(
        category: 'แม่วัวและการคลอด',
        items: [
          SuggestedTopicItem(
            title: 'อาการวัวใกล้คลอด',
            prompt: 'แม่วัวใกล้คลอดมีอาการเตือนอย่างไรบ้าง และต้องเตรียมตัวช่วยทำคลอดอย่างไร?',
          ),
          SuggestedTopicItem(
            title: 'ดูแลลูกวัวแรกเกิด',
            prompt: 'ลูกวัวเพิ่งคลอด ต้องให้กินนมน้ำเหลืองภายในกี่ชั่วโมง และต้องเช็ดสะดืออย่างไร?',
          ),
        ],
      ),
      SuggestedTopicCategory(
        category: 'วัคซีนและการบำรุง',
        items: [
          SuggestedTopicItem(
            title: 'ตารางฉีดวัคซีนประจำปี',
            prompt: 'ในรอบ 1 ปี วัวต้องฉีดวัคซีนป้องกันโรคอะไรบ้างและช่วงเดือนไหน?',
          ),
        ],
      ),
    ];
  }
}
