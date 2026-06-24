import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/core/network/api_client.dart';
import '../domain/finance.dart';
import '../../feed/domain/feed.dart';

class FinanceState {
  final bool isLoading;
  final String? errorMessage;
  final List<FinancialTransaction> transactions;
  final DateTime selectedMonth;

  FinanceState({
    this.isLoading = false,
    this.errorMessage,
    this.transactions = const [],
    DateTime? selectedMonth,
  }) : selectedMonth =
           selectedMonth ?? DateTime(DateTime.now().year, DateTime.now().month);

  List<FinancialTransaction> get currentMonthTransactions {
    return transactions
        .where(
          (t) =>
              t.date.year == selectedMonth.year &&
              t.date.month == selectedMonth.month,
        )
        .toList();
  }

  double get totalIncomeThisMonth => currentMonthTransactions
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpenseThisMonth => currentMonthTransactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  FinanceState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<FinancialTransaction>? transactions,
    DateTime? selectedMonth,
  }) {
    return FinanceState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      transactions: transactions ?? this.transactions,
      selectedMonth: selectedMonth ?? this.selectedMonth,
    );
  }
}

class FinanceNotifier extends Notifier<FinanceState> {
  late final ApiClient _api;

  @override
  FinanceState build() {
    _api = ref.watch(apiClientProvider);
    return FinanceState();
  }

  Future<void> fetchTransactions(String farmId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      print('[FETCH] กำลังดึงข้อมูลธุรกรรมและค่าใช้จ่ายของฟาร์ม $farmId...');

      // Fetch financial records
      final response = await _api.get(
        '/financial_records',
        query: {'farm_id': farmId},
      );
      final List<dynamic> data = response.data;
      final List<FinancialTransaction> manualTransactions = data
          .map((json) => FinancialTransaction.fromJson(json))
          .toList();

      // Fetch feed inventory expenses
      final feedResponse = await _api.get(
        '/feed_inventories',
        query: {'farm_id': farmId},
      );
      final List<dynamic> feedData = feedResponse.data;
      final List<FeedItem> feedItems = feedData
          .map((json) => FeedItem.fromJson(json))
          .toList();

      // Convert feed items to expense transactions
      final List<FinancialTransaction> feedExpenses = feedItems
          .where((item) => item.cost > 0)
          .map(
            (item) => FinancialTransaction(
              id: 'FEED_${item.id}',
              farmId: farmId,
              title: 'ค่าอาหาร: ${item.name}',
              amount: item.cost,
              type: TransactionType.expense,
              category: TransactionCategory.feed,
              date: item.recordedAt,
              notes: item.notes,
            ),
          )
          .toList();

      // Combine all transactions
      final allTransactions = [...manualTransactions, ...feedExpenses];

      print(
        '[SUCCESS] ดึงข้อมูลสำเร็จ: ${manualTransactions.length} ธุรกรรม + ${feedExpenses.length} ค่าอาหาร',
      );
      state = state.copyWith(transactions: allTransactions, isLoading: false);
    } catch (e) {
      print('[ERROR] ดึงข้อมูลธุรกรรมไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void changeMonth(DateTime newMonth) {
    state = state.copyWith(
      selectedMonth: DateTime(newMonth.year, newMonth.month),
    );
  }

  Future<void> addTransaction(FinancialTransaction transaction) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      print('[CREATE] กำลังเพิ่มธุรกรรมใหม่: ${transaction.title}...');
      final response = await _api.post(
        '/financial_records',
        data: transaction.toJson(),
      );
      final newTransaction = FinancialTransaction.fromJson(response.data);

      print('[SUCCESS] เพิ่มธุรกรรมสำเร็จ: ${newTransaction.title}');
      state = state.copyWith(
        isLoading: false,
        transactions: [newTransaction, ...state.transactions],
      );
    } catch (e) {
      print('[ERROR] เพิ่มธุรกรรมไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> updateTransaction(FinancialTransaction transaction) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      print('[UPDATE] กำลังแก้ไขธุรกรรม: ${transaction.id}...');
      final response = await _api.put(
        '/financial_records/${transaction.id}',
        data: transaction.toJson(),
      );
      final updated = FinancialTransaction.fromJson(response.data);

      print('[SUCCESS] แก้ไขธุรกรรมสำเร็จ: ${updated.title}');
      state = state.copyWith(
        isLoading: false,
        transactions: state.transactions
            .map((t) => t.id == updated.id ? updated : t)
            .toList(),
      );
    } catch (e) {
      print('[ERROR] แก้ไขธุรกรรมไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      print('[DELETE] กำลังลบธุรกรรม: $transactionId...');
      await _api.delete('/financial_records/$transactionId');

      print('[SUCCESS] ลบธุรกรรมสำเร็จ');
      state = state.copyWith(
        isLoading: false,
        transactions: state.transactions
            .where((t) => t.id != transactionId)
            .toList(),
      );
    } catch (e) {
      print('[ERROR] ลบธุรกรรมไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final financeProvider = NotifierProvider<FinanceNotifier, FinanceState>(() {
  return FinanceNotifier();
});
