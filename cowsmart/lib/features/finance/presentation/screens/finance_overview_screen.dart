import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../providers/finance_provider.dart';
import '../../domain/finance.dart';
import '../../../farm/providers/farm_provider.dart';

class FinanceOverviewScreen extends ConsumerStatefulWidget {
  const FinanceOverviewScreen({super.key});

  @override
  ConsumerState<FinanceOverviewScreen> createState() =>
      _FinanceOverviewScreenState();
}

class _FinanceOverviewScreenState extends ConsumerState<FinanceOverviewScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch transactions when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentFarm = ref.read(farmProvider).currentFarm;
      if (currentFarm != null) {
        ref.read(financeProvider.notifier).fetchTransactions(currentFarm.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final financeState = ref.watch(financeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('บัญชีรายรับ-รายจ่าย'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Navigate to Add Transaction Dialog/Screen
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildMonthSelector(context, ref, financeState),
          ),
          SliverToBoxAdapter(child: _buildSummaryCards(context, financeState)),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppConstants.defaultPadding,
                24,
                AppConstants.defaultPadding,
                8,
              ),
              child: Text(
                'รายการเดือนนี้',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ),
          financeState.currentMonthTransactions.isEmpty
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'ไม่มีรายการในเดือนนี้',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final tx = financeState.currentMonthTransactions[index];
                    return _buildTransactionCard(context, tx);
                  }, childCount: financeState.currentMonthTransactions.length),
                ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector(
    BuildContext context,
    WidgetRef ref,
    FinanceState state,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 16),
            onPressed: () {
              final newDate = DateTime(
                state.selectedMonth.year,
                state.selectedMonth.month - 1,
              );
              ref.read(financeProvider.notifier).changeMonth(newDate);
            },
          ),
          Text(
            DateFormat('MMMM yyyy').format(state.selectedMonth),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 16),
            onPressed: () {
              final newDate = DateTime(
                state.selectedMonth.year,
                state.selectedMonth.month + 1,
              );
              // Prevent going into future
              if (newDate.isBefore(DateTime.now()) ||
                  DateFormat('MM yyyy').format(newDate) ==
                      DateFormat('MM yyyy').format(DateTime.now())) {
                ref.read(financeProvider.notifier).changeMonth(newDate);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, FinanceState state) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              title: 'รายรับ',
              amount: state.totalIncomeThisMonth,
              color: AppColors.success,
              icon: Icons.arrow_circle_down,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryItem(
              title: 'รายจ่าย',
              amount: state.totalExpenseThisMonth,
              color: AppColors.error,
              icon: Icons.arrow_circle_up,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            NumberFormat('#,##0').format(amount),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const Text(
            'บาท',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, FinancialTransaction tx) {
    final isIncome = tx.type == TransactionType.income;
    final color = isIncome ? AppColors.success : AppColors.error;
    final sign = isIncome ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.defaultPadding,
        vertical: 6,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(
              isIncome ? Icons.attach_money : Icons.money_off,
              color: color,
            ),
          ),
          title: Text(
            tx.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${DateFormat('dd/MM/yyyy').format(tx.date)} • ${tx.category.label}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Text(
            '$sign${NumberFormat('#,##0').format(tx.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
