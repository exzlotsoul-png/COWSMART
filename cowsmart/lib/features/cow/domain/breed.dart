class Breed {
  final String id;
  final String name;
  final String? description;

  Breed({required this.id, required this.name, this.description});

  factory Breed.fromJson(Map<String, dynamic> json) {
    return Breed(
      id: (json['breed_id'] ?? json['id']).toString(),
      name: json['name'].toString(),
      description: json['description'],
    );
  }
}
