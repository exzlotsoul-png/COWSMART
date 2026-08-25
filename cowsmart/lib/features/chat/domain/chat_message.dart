class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? cowName;
  final String? cowTag;
  final List<SuggestedAction>? actions;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.cowName,
    this.cowTag,
    this.actions,
  });
}

class SuggestedAction {
  final String action;
  final String label;

  SuggestedAction({required this.action, required this.label});

  factory SuggestedAction.fromJson(Map<String, dynamic> json) {
    return SuggestedAction(
      action: json['action'] ?? '',
      label: json['label'] ?? '',
    );
  }
}

class SuggestedTopicCategory {
  final String category;
  final List<SuggestedTopicItem> items;

  SuggestedTopicCategory({required this.category, required this.items});

  factory SuggestedTopicCategory.fromJson(Map<String, dynamic> json) {
    return SuggestedTopicCategory(
      category: json['category'] ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => SuggestedTopicItem.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class SuggestedTopicItem {
  final String title;
  final String prompt;

  SuggestedTopicItem({required this.title, required this.prompt});

  factory SuggestedTopicItem.fromJson(Map<String, dynamic> json) {
    return SuggestedTopicItem(
      title: json['title'] ?? '',
      prompt: json['prompt'] ?? '',
    );
  }
}
