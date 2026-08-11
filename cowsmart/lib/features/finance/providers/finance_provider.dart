import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cowsmart/core/network/api_client.dart';
import '../domain/finance.dart';
import '../../feed/domain/feed.dart';
import '../../cow/domain/culling_record.dart';

enum FinanceFilterMode { month, range }

class FinanceState {
  final bool isLoading;
  final String? errorMessage;
  final List<FinancialTransaction> transactions;
  final DateTime selectedMonth;
  final FinanceFilterMode filterMode;
  final DateTimeRange? customDateRange;

  FinanceState({
    this.isLoading = false,
    this.errorMessage,
    this.transactions = const [],
    DateTime? selectedMonth,
    this.filterMode = FinanceFilterMode.month,
    this.customDateRange,
  }) : selectedMonth =
            selectedMonth ?? DateTime(DateTime.now().year, DateTime.now().month);

  List<FinancialTransaction> get currentMonthTransactions {
    if (filterMode == FinanceFilterMode.range && customDateRange != null) {
      final start = DateTime(
        customDateRange!.start.year,
        customDateRange!.start.month,
        customDateRange!.start.day,
        0,
        0,
        0,
      );
      final end = DateTime(
        customDateRange!.end.year,
        customDateRange!.end.month,
        customDateRange!.end.day,
        23,
        59,
        59,
      );
      return transactions.where((t) {
        return (t.date.isAfter(start) || t.date.isAtSameMomentAs(start)) &&
            (t.date.isBefore(end) || t.date.isAtSameMomentAs(end));
      }).toList();
    }

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

  double get totalIncomeCurrentActualMonth {
    final now = DateTime.now();
    return transactions
        .where(
          (t) =>
              t.date.year == now.year &&
              t.date.month == now.month &&
              t.type == TransactionType.income,
        )
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalExpenseCurrentActualMonth {
    final now = DateTime.now();
    return transactions
        .where(
          (t) =>
              t.date.year == now.year &&
              t.date.month == now.month &&
              t.type == TransactionType.expense,
        )
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  FinanceState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<FinancialTransaction>? transactions,
    DateTime? selectedMonth,
    FinanceFilterMode? filterMode,
    DateTimeRange? customDateRange,
    bool clearCustomRange = false,
  }) {
    return FinanceState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      transactions: transactions ?? this.transactions,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      filterMode: filterMode ?? this.filterMode,
      customDateRange: clearCustomRange
          ? null
          : (customDateRange ?? this.customDateRange),
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

  void changeMonth(DateTime newMonth) {
    state = state.copyWith(
      selectedMonth: newMonth,
      filterMode: FinanceFilterMode.month,
      clearCustomRange: true,
    );
  }

  void setCustomDateRange(DateTimeRange range) {
    state = state.copyWith(
      customDateRange: range,
      filterMode: FinanceFilterMode.range,
    );
  }

  void setFilterMode(FinanceFilterMode mode) {
    state = state.copyWith(filterMode: mode);
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

      // Also fetch feed items / purchases and convert to financial transactions
      final List<FinancialTransaction> feedTransactions = [];
      try {
        final feedRes = await _api.get(
          '/feed_inventories',
          query: {'farm_id': farmId},
        );
        final List<dynamic> feedData = feedRes.data;
        for (var fJson in feedData) {
          final feedItem = FeedItem.fromJson(fJson);
          if (feedItem.cost > 0) {
            feedTransactions.add(
              FinancialTransaction(
                id: 'feed_inv_${feedItem.id}',
                farmId: farmId,
                title: 'ค่าอาหาร: ${feedItem.name}',
                type: TransactionType.expense,
                category: TransactionCategory.feed,
                amount: feedItem.cost,
                date: feedItem.recordedAt,
                notes: feedItem.notes ?? 'บันทึกรายจ่ายจากการซื้ออาหารเข้าคลัง',
              ),
            );
          }
        }
      } catch (e) {
        print('⚠️ ไม่สามารถดึงข้อมูลคลังอาหารมารวมในบัญชีได้: $e');
      }

      // Also fetch culling records (sold cows) and merge with financial transactions
      try {
        final cullRes = await _api.get(
          '/culling_records',
          query: {'farm_id': farmId},
        );
        final List<dynamic> cullData = cullRes.data;
        for (var cJson in cullData) {
          final record = CullingRecord.fromJson(cJson);
          if (record.status == 0 && record.price > 0) {
            final cowName = record.cow != null && record.cow!.name.isNotEmpty
                ? record.cow!.name
                : (record.cow != null ? 'หมายเลข ${record.cow!.tagNumber}' : 'หมายเลข ${record.cowId}');

            final formattedTitle = 'ขายวัว $cowName';

            // Check if manualTransactions already has a transaction for this sale (by ID or same date/amount)
            final existingIndex = manualTransactions.indexWhere((t) {
              if (t.id == record.id || t.id == 'cull_${record.id}') return true;
              final isSameDate = t.date.year == record.cullDate.year &&
                  t.date.month == record.cullDate.month &&
                  t.date.day == record.cullDate.day;
              final isSameAmount = (t.amount - record.price).abs() < 0.01;
              final isIncome = t.type == TransactionType.income;
              return isSameDate && isSameAmount && isIncome;
            });

            if (existingIndex != -1) {
              // Update title to prefer cow's name (e.g. "ขายวัว นำโชค")
              manualTransactions[existingIndex] = FinancialTransaction(
                id: manualTransactions[existingIndex].id,
                farmId: manualTransactions[existingIndex].farmId,
                title: formattedTitle,
                type: manualTransactions[existingIndex].type,
                category: manualTransactions[existingIndex].category,
                amount: manualTransactions[existingIndex].amount,
                date: manualTransactions[existingIndex].date,
                relatedCowId: record.cowId,
                notes: manualTransactions[existingIndex].notes ?? (record.note.isNotEmpty ? record.note : null),
              );
            } else {
              manualTransactions.add(
                FinancialTransaction(
                  id: 'cull_${record.id}',
                  farmId: farmId,
                  title: formattedTitle,
                  type: TransactionType.income,
                  category: TransactionCategory.cowSale,
                  amount: record.price,
                  date: record.cullDate,
                  relatedCowId: record.cowId,
                  notes: record.note.isNotEmpty ? record.note : 'ระบบบันทึกรายรับอัตโนมัติจากการขายวัว',
                ),
              );
            }
          }
        }
      } catch (e) {
        print('⚠️ ไม่สามารถดึงข้อมูลการขายวัวมารวมในบัญชีได้: $e');
      }

      final allTx = [...manualTransactions, ...feedTransactions];
      allTx.sort((a, b) => b.date.compareTo(a.date));

      state = state.copyWith(
        isLoading: false,
        transactions: allTx,
      );
    } catch (e) {
      print('[ERROR] ไม่สามารถดึงข้อมูลธุรกรรมได้: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> addTransaction(FinancialTransaction tx) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final body = {
        'farm_id': tx.farmId,
        'title': tx.title,
        'type': tx.type.name,
        'category': tx.category.label,
        'amount': tx.amount,
        'date': tx.date.toIso8601String().split('T')[0],
        if (tx.notes != null) 'notes': tx.notes,
      };

      print('[POST] กำลังบันทึกธุรกรรมใหม่: $body');
      final response = await _api.post('/financial_records', data: body);
      final newTx = FinancialTransaction.fromJson(response.data);

      final updatedList = [newTx, ...state.transactions];
      updatedList.sort((a, b) => b.date.compareTo(a.date));

      state = state.copyWith(
        isLoading: false,
        transactions: updatedList,
      );
    } catch (e) {
      print('[ERROR] บันทึกธุรกรรมไม่สำเร็จ: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> updateTransaction(FinancialTransaction tx) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final body = {
        'title': tx.title,
        'type': tx.type.name,
        'category': tx.category.label,
        'amount': tx.amount,
        'date': tx.date.toIso8601String().split('T')[0],
        if (tx.notes != null) 'notes': tx.notes,
      };

      print('[PUT] กำลังแก้ไขธุรกรรม ${tx.id}: $body');
      final response = await _api.put('/financial_records/${tx.id}', data: body);
      final updated = FinancialTransaction.fromJson(response.data);

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
