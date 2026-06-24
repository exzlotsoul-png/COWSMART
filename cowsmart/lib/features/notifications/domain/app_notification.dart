class AppNotification {
  final String id;
  final String email;
  final String title;
  final String message;
  final DateTime? notifyDatetime;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.email,
    required this.title,
    required this.message,
    this.notifyDatetime,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      notifyDatetime: json['notify_datetime'] != null
          ? DateTime.tryParse(json['notify_datetime'])
          : null,
      isRead: (json['is_read'] ?? 0) == 1,
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      email: email,
      title: title,
      message: message,
      notifyDatetime: notifyDatetime,
      isRead: isRead ?? this.isRead,
    );
  }
}
