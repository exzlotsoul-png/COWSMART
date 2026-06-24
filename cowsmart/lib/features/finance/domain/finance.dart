enum TransactionType {
  income('รายรับ', 'success'),
  expense('รายจ่าย', 'error');

  final String label;
  final String colorType;
  const TransactionType(this.label, this.colorType);

  factory TransactionType.fromString(String value) {
    if (value.toLowerCase() == 'income' || value == 'รายรับ') {
      return TransactionType.income;
    }
    return TransactionType.expense;
  }

  String get apiValue => name;
}

enum TransactionCategory {
  feed('ค่าอาหาร'),
  medical('ค่ารักษาพยาบาล/วัคซีน'),
  cowPurchase('ซื้อวัว'),
  cowSale('ขายวัว'),
  equipment('อุปกรณ์ฟาร์ม'),
  salary('ค่าจ้างพนักงาน'),
  other('อื่นๆ');

  final String label;
  const TransactionCategory(this.label);

  factory TransactionCategory.fromString(String value) {
    switch (value.toLowerCase()) {
      case 'feed':
      case 'ค่าอาหาร':
        return TransactionCategory.feed;
      case 'medical':
      case 'ค่ารักษาพยาบาล/วัคซีน':
        return TransactionCategory.medical;
      case 'cowpurchase':
      case 'ซื้อวัว':
        return TransactionCategory.cowPurchase;
      case 'cowsale':
      case 'ขายวัว':
        return TransactionCategory.cowSale;
      case 'equipment':
      case 'อุปกรณ์ฟาร์ม':
        return TransactionCategory.equipment;
      case 'salary':
      case 'ค่าจ้างพนักงาน':
        return TransactionCategory.salary;
      default:
        return TransactionCategory.other;
    }
  }

  String get apiValue => label;
}

class FinancialTransaction {
  final String id;
  final String farmId;
  final String title;
  final double amount;
  final TransactionType type;
  final TransactionCategory category;
  final DateTime date;
  final String? relatedCowId;
  final String? notes;

  FinancialTransaction({
    required this.id,
    required this.farmId,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.relatedCowId,
    this.notes,
  });

  factory FinancialTransaction.fromJson(Map<String, dynamic> json) {
    return FinancialTransaction(
      id: json['financial_record_id'] ?? json['id'] ?? '',
      farmId: json['farm_id'] ?? json['farmId'] ?? '',
      title: json['title'] ?? json['category'] ?? 'ไม่ระบุ',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      type: TransactionType.fromString(json['trans_type'] ?? 'expense'),
      category: TransactionCategory.fromString(json['category'] ?? 'other'),
      date: DateTime.parse(
        json['transaction_date'] ??
            json['date'] ??
            DateTime.now().toIso8601String(),
      ),
      relatedCowId: json['related_cow_id'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'financial_record_id': id.isEmpty ? null : id,
      'farm_id': farmId,
      'trans_type': type.apiValue,
      'category': category.apiValue,
      'amount': amount,
      'transaction_date': date.toIso8601String(),
      'notes': notes,
    };
  }

  FinancialTransaction copyWith({
    String? id,
    String? farmId,
    String? title,
    double? amount,
    TransactionType? type,
    TransactionCategory? category,
    DateTime? date,
    String? relatedCowId,
    String? notes,
  }) {
    return FinancialTransaction(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      relatedCowId: relatedCowId ?? this.relatedCowId,
      notes: notes ?? this.notes,
    );
  }
}
