class CowTypeModel {
  final String id;
  final String name;

  const CowTypeModel({required this.id, required this.name});

  factory CowTypeModel.fromJson(Map<String, dynamic> json) {
    return CowTypeModel(
      id: (json['cow_type_id'] ?? json['id'] ?? '').toString(),
      name: (json['cow_type_name'] ?? json['name'] ?? '').toString(),
    );
  }
}
