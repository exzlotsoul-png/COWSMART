import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:cowsmart/core/utils/app_toast.dart';
import 'package:cowsmart/core/utils/date_formatter.dart';
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
  String _selectedFilter = 'all'; // 'all', 'income', 'expense'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentFarm = ref.read(farmProvider).currentFarm;
      if (currentFarm != null) {
        ref.read(financeProvider.notifier).fetchTransactions(currentFarm.id);
      }
    });
  }

  void _showAddTransactionModal(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    TransactionType selectedType = TransactionType.expense;
    TransactionCategory selectedCategory = TransactionCategory.feed;
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'บันทึกรายรับ-รายจ่าย',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(modalContext),
                            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Segmented Button Type (Income / Expense)
                      SegmentedButton<TransactionType>(
                        segments: const [
                          ButtonSegment(
                            value: TransactionType.income,
                            label: Text('รายรับ (+)', style: TextStyle(fontWeight: FontWeight.bold)),
                            icon: Icon(Icons.arrow_circle_down_rounded, color: AppColors.success, size: 18),
                          ),
                          ButtonSegment(
                            value: TransactionType.expense,
                            label: Text('รายจ่าย (-)', style: TextStyle(fontWeight: FontWeight.bold)),
                            icon: Icon(Icons.arrow_circle_up_rounded, color: AppColors.error, size: 18),
                          ),
                        ],
                        selected: <TransactionType>{selectedType},
                        onSelectionChanged: (Set<TransactionType> selection) {
                          setModalState(() {
                            selectedType = selection.first;
                            if (selectedType == TransactionType.income) {
                              selectedCategory = TransactionCategory.cowSale;
                            } else {
                              selectedCategory = TransactionCategory.feed;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Title Field
                      TextFormField(
                        controller: titleController,
                        decoration: _buildModalInputDecoration('ชื่อรายการ', Icons.title_rounded, hintText: 'เช่น ค่าอาหารเม็ด, ขายวัว TH-001'),
                        validator: (val) => val == null || val.trim().isEmpty ? 'กรุณากรอกชื่อรายการ' : null,
                      ),
                      const SizedBox(height: 12),

                      // Amount Field
                      TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: _buildModalInputDecoration('จำนวนเงิน (บาท)', Icons.payments_rounded, hintText: '0.00'),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'กรุณากรอกจำนวนเงิน';
                          if (double.tryParse(val) == null || double.parse(val) <= 0) {
                            return 'กรุณากรอกจำนวนเงินให้ถูกต้อง';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Category Dropdown
                      DropdownButtonFormField<TransactionCategory>(
                        initialValue: selectedCategory,
                        isExpanded: true,
                        decoration: _buildModalInputDecoration('หมวดหมู่', Icons.category_rounded),
                        items: TransactionCategory.values.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Text(cat.label, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedCategory = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Date Picker
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: modalContext,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setModalState(() => selectedDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: _buildModalInputDecoration('วันที่รายการ', Icons.calendar_today_rounded),
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(selectedDate),
                            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Notes Field
                      TextFormField(
                        controller: notesController,
                        decoration: _buildModalInputDecoration('บันทึกเพิ่มเติม (ถ้ามี)', Icons.notes_rounded),
                      ),
                      const SizedBox(height: 20),

                      // Save Button
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) {
                              AppFeedback.showError(context, 'กรุณากรอกหัวข้อรายการและจำนวนเงินให้ถูกต้อง');
                              return;
                            }
                            final currentFarm = ref.read(farmProvider).currentFarm;
                            if (currentFarm == null) return;

                            final tx = FinancialTransaction(
                              id: '',
                              farmId: currentFarm.id,
                              title: titleController.text.trim(),
                              amount: double.parse(amountController.text.trim()),
                              type: selectedType,
                              category: selectedCategory,
                              date: selectedDate,
                              notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                            );

                            Navigator.pop(modalContext);
                            await ref.read(financeProvider.notifier).addTransaction(tx);
                            if (context.mounted) {
                              AppFeedback.showSuccess(context, 'บันทึกรายการรายรับ/รายจ่ายเรียบร้อยแล้ว');
                            }
                          },
                          icon: const Icon(Icons.check_circle_rounded, size: 20),
                          label: const Text('บันทึกรายการ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCustomDateRangePicker(BuildContext context) {
    final financeState = ref.read(financeProvider);
    final now = DateTime.now();

    DateTime tempStart = financeState.customDateRange?.start ??
        DateTime(now.year, now.month, 1);
    DateTime tempEnd = financeState.customDateRange?.end ?? now;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final daysCount = tempEnd.difference(tempStart).inDays + 1;

            void applyPreset(DateTime start, DateTime end) {
              setModalState(() {
                tempStart = start;
                tempEnd = end;
              });
            }

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.date_range_rounded, color: AppColors.primary, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'เลือกช่วงเวลาดูบัญชี',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(modalContext),
                          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quick Presets Label
                    const Text(
                      'ตัวเลือกด่วน',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Preset Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPresetChip(
                          label: '7 วันล่าสุด',
                          onTap: () {
                            final today = DateTime.now();
                            applyPreset(today.subtract(const Duration(days: 6)), today);
                          },
                        ),
                        _buildPresetChip(
                          label: '30 วันล่าสุด',
                          onTap: () {
                            final today = DateTime.now();
                            applyPreset(today.subtract(const Duration(days: 29)), today);
                          },
                        ),
                        _buildPresetChip(
                          label: 'เดือนนี้',
                          onTap: () {
                            final today = DateTime.now();
                            applyPreset(DateTime(today.year, today.month, 1), today);
                          },
                        ),
                        _buildPresetChip(
                          label: 'เดือนที่แล้ว',
                          onTap: () {
                            final today = DateTime.now();
                            final firstOfLastMonth = DateTime(today.year, today.month - 1, 1);
                            final lastOfLastMonth = DateTime(today.year, today.month, 0);
                            applyPreset(firstOfLastMonth, lastOfLastMonth);
                          },
                        ),
                        _buildPresetChip(
                          label: 'ปีนี้ (พ.ศ. ${now.year + 543})',
                          onTap: () {
                            final today = DateTime.now();
                            applyPreset(DateTime(today.year, 1, 1), today);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Custom Date Pickers Label
                    const Text(
                      'ระบุช่วงวันที่เอง',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        // Start Date
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempStart,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                                helpText: 'เลือกวันที่เริ่มต้น',
                              );
                              if (picked != null) {
                                setModalState(() {
                                  tempStart = picked;
                                  if (tempEnd.isBefore(tempStart)) {
                                    tempEnd = tempStart;
                                  }
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ตั้งแต่วันที่',
                                    style: TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          AppDateUtils.formatThaiDate(tempStart),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward_rounded, color: AppColors.textHint, size: 18),
                        ),
                        // End Date
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempEnd,
                                firstDate: tempStart,
                                lastDate: DateTime(2100),
                                helpText: 'เลือกวันที่สิ้นสุด',
                              );
                              if (picked != null) {
                                setModalState(() {
                                  tempEnd = picked;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ถึงวันที่',
                                    style: TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.event_rounded, size: 16, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          AppDateUtils.formatThaiDate(tempEnd),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Days Count Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primaryDark),
                          const SizedBox(width: 6),
                          Text(
                            'รวมระยะเวลาเลือกทั้งหมด $daysCount วัน',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Apply Button
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(financeProvider.notifier).setCustomDateRange(
                              DateTimeRange(start: tempStart, end: tempEnd),
                            );
                        Navigator.pop(modalContext);
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text('ตกลง / ดูรายงานช่วงเวลานี้', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip({required String label, required VoidCallback onTap}) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
      backgroundColor: AppColors.surfaceAlt,
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: onTap,
    );
  }

  void _showMonthYearPicker(BuildContext context) {
    final financeState = ref.read(financeProvider);
    int tempYear = financeState.selectedMonth.year;

    final thaiMonths = [
      'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน',
      'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม',
      'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final now = DateTime.now();

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'เลือกเดือนและปี',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalContext),
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Year Selector
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, color: AppColors.primaryDark),
                          onPressed: tempYear > 2020
                              ? () => setModalState(() => tempYear--)
                              : null,
                        ),
                        Text(
                          'ปี พ.ศ. ${tempYear + 543} ($tempYear)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, color: AppColors.primaryDark),
                          onPressed: tempYear < now.year
                              ? () => setModalState(() => tempYear++)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 12 Months Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final monthNum = index + 1;
                      final isSelected = (tempYear == financeState.selectedMonth.year && monthNum == financeState.selectedMonth.month);
                      final isFuture = (tempYear > now.year) || (tempYear == now.year && monthNum > now.month);

                      return InkWell(
                        onTap: isFuture
                            ? null
                            : () {
                                ref.read(financeProvider.notifier).changeMonth(DateTime(tempYear, monthNum));
                                Navigator.pop(modalContext);
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : (isFuture ? Colors.grey[200] : AppColors.surfaceAlt),
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? null
                                : Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            thaiMonths[index],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isFuture ? AppColors.textHint : AppColors.textPrimary),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _buildModalInputDecoration(String label, IconData icon, {String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  IconData _getCategoryIcon(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.feed:
        return Icons.grass_rounded;
      case TransactionCategory.medical:
        return Icons.medical_services_rounded;
      case TransactionCategory.cowPurchase:
        return Icons.shopping_cart_rounded;
      case TransactionCategory.cowSale:
        return Icons.sell_rounded;
      case TransactionCategory.equipment:
        return Icons.handyman_rounded;
      case TransactionCategory.salary:
        return Icons.badge_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final financeState = ref.watch(financeProvider);
    final currentTransactions = financeState.currentMonthTransactions;

    final filteredTransactions = currentTransactions.where((t) {
      if (_selectedFilter == 'income') return t.type == TransactionType.income;
      if (_selectedFilter == 'expense') return t.type == TransactionType.expense;
      return true;
    }).toList();

    final income = financeState.totalIncomeThisMonth;
    final expense = financeState.totalExpenseThisMonth;
    final balance = income - expense;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Gradient Header ──
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                  child: Column(
                    children: [
                      // Top Row: Back button, Title
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'บัญชีรายรับ-รายจ่าย',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'สรุปภาพรวมรายรับ รายจ่าย และคงเหลือสุทธิ',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Filter Mode Switcher (Month vs Custom Range)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () {
                              ref.read(financeProvider.notifier).setFilterMode(FinanceFilterMode.month);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: financeState.filterMode == FinanceFilterMode.month
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'รายเดือน',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: financeState.filterMode == FinanceFilterMode.month
                                      ? AppColors.primaryDark
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              if (financeState.filterMode != FinanceFilterMode.range) {
                                ref.read(financeProvider.notifier).setFilterMode(FinanceFilterMode.range);
                              }
                              if (financeState.customDateRange == null) {
                                _showCustomDateRangePicker(context);
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: financeState.filterMode == FinanceFilterMode.range
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'กำหนดช่วงวัน',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: financeState.filterMode == FinanceFilterMode.range
                                          ? AppColors.primaryDark
                                          : Colors.white,
                                    ),
                                  ),
                                  if (financeState.filterMode == FinanceFilterMode.range) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.edit_calendar_rounded, size: 14, color: AppColors.primaryDark),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Month Navigator Bar OR Custom Range Bar
                      if (financeState.filterMode == FinanceFilterMode.month) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
                                onPressed: () {
                                  final newDate = DateTime(
                                    financeState.selectedMonth.year,
                                    financeState.selectedMonth.month - 1,
                                  );
                                  ref.read(financeProvider.notifier).changeMonth(newDate);
                                },
                              ),
                              InkWell(
                                onTap: () => _showMonthYearPicker(context),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        AppDateUtils.formatThaiMonthYear(financeState.selectedMonth),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 22),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
                                onPressed: () {
                                  final newDate = DateTime(
                                    financeState.selectedMonth.year,
                                    financeState.selectedMonth.month + 1,
                                  );
                                  if (newDate.isBefore(DateTime.now()) ||
                                      DateFormat('MM yyyy').format(newDate) ==
                                          DateFormat('MM yyyy').format(DateTime.now())) {
                                    ref.read(financeProvider.notifier).changeMonth(newDate);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        InkWell(
                          onTap: () => _showCustomDateRangePicker(context),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.date_range_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  financeState.customDateRange != null
                                      ? AppDateUtils.formatThaiDateRange(
                                          financeState.customDateRange!.start,
                                          financeState.customDateRange!.end,
                                        )
                                      : 'กดที่นี่เพื่อเลือกช่วงวันที่ (จากวันที่ - ถึงวันที่)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.edit_calendar_rounded, color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Hero Summary Card ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Net Balance Title
                    Text(
                      financeState.filterMode == FinanceFilterMode.range ? 'คงเหลือสุทธิช่วงเวลานี้' : 'คงเหลือสุทธิเดือนนี้',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '฿${NumberFormat('#,##0').format(balance)}',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: balance >= 0 ? AppColors.success : AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (balance >= 0 ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            balance >= 0 ? 'กำไร' : 'ขาดทุน',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: balance >= 0 ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Income & Expense Stat Chips Row
                    Row(
                      children: [
                        // Income Chip
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 16),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'รายรับรวม',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '฿${NumberFormat('#,##0').format(income)}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.success,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Expense Chip
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 16),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'รายจ่ายรวม',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '฿${NumberFormat('#,##0').format(expense)}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.error,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Filter Chips Bar & Section Header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ประวัติรายการ (${filteredTransactions.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildFilterChip('ทั้งหมด', 'all'),
                      const SizedBox(width: 6),
                      _buildFilterChip('รายรับ', 'income', color: AppColors.success),
                      const SizedBox(width: 6),
                      _buildFilterChip('รายจ่าย', 'expense', color: AppColors.error),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Transaction List Content ──
          if (financeState.isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
            )
          else if (filteredTransactions.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'ไม่มีรายการในเดือนนี้',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'แตะปุ่มด้านล่างเพื่อเริ่มบันทึกรายรับหรือรายจ่ายใหม่',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final tx = filteredTransactions[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _buildTransactionCard(context, tx),
                  );
                },
                childCount: filteredTransactions.length,
              ),
            ),
        ],
      ),

      // ── Floating Action Button to Add Transaction ──
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransactionModal(context),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text('บันทึกรายการ', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey, {Color? color}) {
    final isSelected = _selectedFilter == filterKey;
    final activeColor = color ?? AppColors.primary;

    return InkWell(
      onTap: () => setState(() => _selectedFilter = filterKey),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : activeColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : activeColor,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(BuildContext context, FinancialTransaction tx) {
    final isIncome = tx.type == TransactionType.income;
    final color = isIncome ? AppColors.success : AppColors.error;
    final sign = isIncome ? '+' : '-';
    final categoryIcon = _getCategoryIcon(tx.category);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Category Icon Badge
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(categoryIcon, color: color, size: 22),
            ),
            const SizedBox(width: 14),

            // Details Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        tx.category.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(tx.date),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      tx.notes!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Amount Column
            Text(
              '$sign฿${NumberFormat('#,##0').format(tx.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
