class Farm {
  final String id;
  final String ownerEmail;
  final String name;
  final String? address;
  final String? imageUrl;
  final String? imageFullUrl;
  final DateTime? createdAt;

  Farm({
    required this.id,
    required this.ownerEmail,
    required this.name,
    this.address,
    this.imageUrl,
    this.imageFullUrl,
    this.createdAt,
  });

  factory Farm.fromJson(Map<String, dynamic> json) {
    return Farm(
      id: (json['farm_id'] ?? json['id']).toString(),
      ownerEmail: (json['email'] ?? json['owner_email']).toString(),
      name: json['name'].toString(),
      address: json['address'],
      imageUrl: json['image_url'],
      imageFullUrl: json['image_full_url'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'farm_id': id,
      'email': ownerEmail,
      'name': name,
      'address': address,
      'image_url': imageUrl,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
