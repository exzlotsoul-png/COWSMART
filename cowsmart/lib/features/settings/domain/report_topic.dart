class ReportTopic {
  final String id;
  final String name;

  ReportTopic({
    required this.id,
    required this.name,
  });

  factory ReportTopic.fromJson(Map<String, dynamic> json) {
    return ReportTopic(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}
